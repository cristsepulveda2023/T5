# T5 — Do-file automatizado en Stata

**Fundamentos de Programación para Análisis Económico · UdeC-EAN**
Módulo IV · Semana 13 · Tarea calificada T5
Autor: Cristóbal Sepúlveda

## Objetivo

Convertir el do-file «escrito a mano» de la A5 en uno automatizado: sin código
repetido, parametrizado con macros, con un programa reutilizable y con los
resultados guardados y exportados.

## Estructura del repositorio

```
├── data/raw/casen_reducido.csv       # datos de entrada (60 personas)
├── scripts/tarea_t5.do               # el do-file de la tarea
└── output/
    ├── tarea_t5.log                  # bitácora que genera el do-file
    └── tarea_t5_por_sector.xlsx      # regresión por sector exportada con putexcel
```

## Cómo correrlo

1. Abrir Stata (versión 14.1 o superior).
2. Abrir `scripts/tarea_t5.do` y ejecutarlo completo con **Ctrl + D**.

Si Stata queda parado en `scripts/`, el do-file sube solo a la carpeta del proyecto.

## Qué automaticé

- **Parámetros en un solo lugar:** datos, variable dependiente (`depvar`), variable
  de interés (`xvar`), controles, variables numéricas, grupos, tramos de educación,
  umbral de ingreso y archivo de salida están en macros al inicio. El cuerpo no
  tiene valores escritos a mano.
- **`local` vs `global`:** los parámetros son `local` porque solo los usa este
  do-file; el umbral es `global` porque es una definición que se compartiría con
  otros do-files del proyecto.
- **`foreach`** recorre las variables numéricas (reemplaza un `summarize` por variable).
- **`forvalues`** cuenta personas por tramo de educación usando `r(N)`.
- **`program descriptivos_grupo`** recibe el grupo y las variables como argumentos,
  y se llama desde un loop para cada grupo (sector, región y género).
- **`tempvar`** para una variable intermedia que no queda en la base.
- **Missing:** el filtro por el umbral excluye explícitamente los faltantes
  (`& !missing()`); sin eso, Stata cuenta a los 5 sin ingreso como «sobre el umbral».
- **Dos modelos** guardados con `estimates store` y comparados con
  `estimates table`; los coeficientes se muestran con `_b[]` y `display`.
- **Regresión por sector** con `levelsof` + `foreach`, guardada en una matriz `J()`
  y exportada a Excel con `putexcel`.

**Prueba de parametrización:** cambié a la vez `controles` (vacío), el umbral
(400.000) y el grupo de las regresiones separadas (`region`). El do-file corrió
completo sin errores y todos los resultados se adaptaron.

## Principales resultados

- Un año más de educación se asocia a **$42.019** más de ingreso mensual, con igual
  experiencia (m1). Al agregar el sexo, el coeficiente casi no cambia: **$42.246** (m2).
- La diferencia entre mujeres y hombres (−$55.686) no se distingue de cero en esta muestra.
- Por sector, el coeficiente va de $23.783 (Construcción) a $42.713 (Industria), pero
  cada regresión usa solo entre 5 y 15 personas, así que son estimaciones imprecisas.
- Son asociaciones en una muestra pequeña, no efectos causales.

## Qué editar para reutilizarlo con otros datos

Solo el bloque **1. PARÁMETROS**: la ruta en `datos`; los nombres en `depvar`,
`xvar`, `controles`, `numericas` y `grupos`; el grupo de las regresiones separadas
en `por_grupo`; los tramos y el `global umbral`. Lo único específico de esta base es
la creación de `experiencia` y `mujer` (paso 2), que habría que adaptar a las
variables de la nueva base.
Declaración de autoría y uso de IA

## Herramienta utilizada: Claude (Claude Code).

Para qué la usé: Utilicé Claude principalmente como herramienta de apoyo, guía y consultoría durante 
el desarrollo del trabajo. Me ayudó a resolver dudas sobre la estructura del código, identificar y 
corregir errores, comprender algunas funciones de Stata y revisar aspectos relacionados con la 
parametrización y la interpretación de los resultados.

Qué hice yo: Desarrollé y escribí personalmente gran parte del código del do-file, basándome en los 
conocimientos adquiridos durante el curso y utilizando Claude como apoyo cuando surgían dudas o 
dificultades. También participé activamente en la construcción de las soluciones, la revisión del 
funcionamiento del código y la interpretación de los resultados obtenidos.
