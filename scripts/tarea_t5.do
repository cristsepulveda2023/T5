* ============================================================
* T5 — Do-file automatizado: descriptivos y modelos de CASEN
* Autor: Cristobal Sepulveda      Fecha: 2026-11-19
* Propósito: la A5 sin código repetido. Todo lo que puede cambiar
*            está en el bloque de parámetros; el resto se adapta solo.
* ============================================================
* Correr con Stata parado en la carpeta del proyecto (la que tiene data/).
* Si Stata quedó en scripts/ (al abrir el .do con doble clic), sube una carpeta.
capture confirm file "data/raw/casen_reducido.csv"
if _rc != 0 {
    cd ..
}

version 14.1          // 14.1 y no 14: con version 14, putexcel usa su sintaxis antigua y "putexcel A1 = ..." da error
clear all
set more off
capture mkdir "output"
capture log close
log using "output/tarea_t5.log", replace text


* ============================================================
* 1. PARÁMETROS (lo único que se edita)
* ============================================================
* local: estos valores solo los usa este do-file; al terminar desaparecen
* y no chocan con otros do-files ni con la sesión. Es la opción por defecto.
local datos     "data/raw/casen_reducido.csv"
local depvar    "ingreso"                         // variable dependiente
local xvar      "educ"                            // variable de interés (su coeficiente se interpreta)
local controles "experiencia"                     // controles; sin edad: edad = educ + experiencia + 6 (colinealidad)
local numericas "ingreso educ edad experiencia"   // variables para los descriptivos
local grupos    "sector region genero"            // grupos para el programa de descriptivos
local por_grupo "sector"                          // grupo de las regresiones separadas (paso 9)
local tramo_ini  4                                // tramos de educación: desde,
local tramo_paso 4                                //   ancho del tramo,
local tramo_fin  16                               //   y último tramo
local excel     "output/tarea_t5_por_sector.xlsx"

* global: el umbral de ingreso es una definición que querría compartir con
* otros do-files del proyecto (por ejemplo, uno de gráficos), y un global
* sigue vivo durante toda la sesión de Stata. Por eso este va como global.
global umbral = 500000


* ============================================================
* 2. CARGA Y PREPARACIÓN
* ============================================================
import delimited "`datos'", clear varnames(1) encoding("utf-8")

* Experiencia potencial de Mincer (años desde que dejó de estudiar)
generate experiencia = max(edad - educ - 6, 0)
label variable experiencia "Experiencia potencial (años)"

* genero es texto y no puede entrar a una regresión (i.genero da error):
* se crea una indicadora 0/1 con etiquetas de valores.
generate mujer = (genero == "F") if !missing(genero)
label define mujer_lbl 0 "Hombre" 1 "Mujer"
label values mujer mujer_lbl
label variable mujer "Mujer"
label variable ingreso "Ingreso mensual ($)"
tabulate mujer


* ============================================================
* 3. foreach: descriptivos de cada variable numérica
* ============================================================
* Un solo bloque en vez de un summarize por variable: para agregar o quitar
* una variable basta con editar la macro numericas.
foreach v of local numericas {
    summarize `v', detail
}


* ============================================================
* 4. forvalues: personas por tramo de educación
* ============================================================
* Cuántas personas hay en cada tramo de años de estudio. Sirve para saber
* si algún tramo tiene tan pocas personas que sus promedios no son confiables.
* r(N) es lo que deja guardado count.
forvalues t = `tramo_ini'(`tramo_paso')`tramo_fin' {
    quietly count if `xvar' >= `t' & `xvar' < `t' + `tramo_paso'
    display "`xvar' de `t' a " `t' + `tramo_paso' - 1 " años: " r(N) " personas"
}


* ============================================================
* 5. program con argumentos, llamado desde un loop
* ============================================================
* Argumento 1: la variable de grupo. Argumento 2: las variables a resumir.
* El programa no ve los local del do-file, por eso las variables se le pasan
* como argumento (entre comillas, para que lleguen como un solo argumento).
capture program drop descriptivos_grupo     // evita el error "already defined" al re-ejecutar
program define descriptivos_grupo
    args grupo vars
    display _newline "=== Descriptivos por `grupo' ==="
    tabulate `grupo'
    tabstat `vars', by(`grupo') statistics(mean sd n) format(%12.0fc)
end

foreach g of local grupos {
    descriptivos_grupo `g' "`depvar' `xvar'"
}


* ============================================================
* 6. tempvar: una variable intermedia que no queda en la base
* ============================================================
* tempvar crea un nombre único (tipo __000001) que Stata borra solo al
* terminar el do-file, aunque se corte por un error. Con una variable normal
* y drop, si el do-file falla antes del drop la variable queda en la base, y
* la siguiente corrida choca con "variable already defined"; además el nombre
* podría pisar una variable que ya existía.
tempvar dep_miles
generate `dep_miles' = `depvar' / 1000
label variable `dep_miles' "`depvar' en miles de pesos"
summarize `dep_miles'


* ============================================================
* 7. Missing al filtrar por el umbral
* ============================================================
count if `depvar' > $umbral
count if `depvar' > $umbral & !missing(`depvar')
* Sin "& !missing(...)", Stata cuenta a las personas sin ingreso como si
* ganaran más que el umbral, porque para Stata el missing (.) es mayor que
* cualquier número. El primer count sale inflado por los 5 missing.
quietly count if `depvar' > $umbral & !missing(`depvar')
local n_sobre = r(N)
quietly count if !missing(`depvar')
display "Personas con `depvar' sobre $" %9.0fc $umbral ": " `n_sobre' " de " r(N) ///
    " (" %4.1f 100 * `n_sobre' / r(N) " %)"


* ============================================================
* 8. Dos modelos guardados y comparados
* ============================================================
quietly regress `depvar' `xvar' `controles'
estimates store m1
quietly regress `depvar' `xvar' `controles' i.mujer
estimates store m2
estimates table m1 m2, b(%9.0f) se stats(N r2) stfmt(%5.3f)

* Coeficientes leídos desde los modelos guardados, no copiados a mano
quietly estimates restore m1
local b1 = _b[`xvar']
quietly estimates restore m2
local b2 = _b[`xvar']
display "m1: un año más de `xvar' se asocia a $" %9.0fc `b1' " más de `depvar' al mes"
display "m2: un año más de `xvar' se asocia a $" %9.0fc `b2' " más de `depvar' al mes (controlando por sexo)"
display "m2: diferencia mujer - hombre: $" %9.0fc _b[1.mujer]


* ============================================================
* 9. Una regresión por grupo, guardada en una matriz y exportada
* ============================================================
levelsof `por_grupo', local(niveles)
local k : word count `niveles'
matrix R = J(`k', 3, .)                     // una fila por grupo: coeficiente, error estándar, n
matrix colnames R = b_`xvar' ee_`xvar' n

local i = 0
foreach s of local niveles {
    local ++i
    quietly regress `depvar' `xvar' if `por_grupo' == "`s'"
    matrix R[`i', 1] = _b[`xvar']
    matrix R[`i', 2] = _se[`xvar']
    matrix R[`i', 3] = e(N)
}
matrix list R, format(%12.1f)

* Exportar: nombres de los grupos en la columna A y la matriz desde la B
putexcel set "`excel'", replace sheet("por_`por_grupo'")
putexcel A1 = "`por_grupo'" B1 = "coef_`xvar'" C1 = "ee_`xvar'" D1 = "n"
local i = 0
foreach s of local niveles {
    local ++i
    local fila = `i' + 1
    putexcel A`fila' = "`s'"
}
putexcel B2 = matrix(R)
display "Tabla exportada a `excel'"


* ============================================================
* 10. Cierre
* ============================================================
log close

* Interpretación (60 personas; 55 con ingreso informado):
*   En m1, un año más de educación se asocia a unos $42.019 más de ingreso
*   mensual, con igual experiencia potencial (error estándar ~$6.393, muy preciso).
*   En m2, al agregar el sexo, el coeficiente casi no cambia ($42.246): la
*   asociación educación-ingreso no se explica por diferencias entre hombres y
*   mujeres. Las mujeres ganan en promedio $55.686 menos, pero con un error
*   estándar de $43.302 esa diferencia no se distingue de cero en esta muestra.
*   Por sector, el coeficiente va de $23.783 (Construcción) a $42.713 (Industria),
*   pero cada regresión usa entre 5 y 15 personas, así que son muy imprecisas.
*   Limitación: son 60 personas y no observamos habilidad ni calidad de la
*   educación, así que es una asociación y no un efecto causal.
