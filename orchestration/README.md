# Orquestación - FinBank Data Engineering

## Descripción

La orquestación del proyecto se realizó en Azure Data Factory mediante el pipeline principal PL_FINBANK_MEDALLION.

Este pipeline se encarga de controlar la ejecución de las capas Bronze, Silver y Gold, además del manejo de fallos, reintentos, alertas y monitoreo.

## Flujo del pipeline

El proceso ejecuta primero Bronze, después Silver y finalmente Gold.

Cada etapa depende de que la anterior termine correctamente. Al finalizar el procesamiento se ejecuta el reporte diario.

Si alguna etapa presenta un error, el pipeline identifica el proceso afectado y ejecuta el manejo de fallos correspondiente.

## Programación

El pipeline tiene un trigger configurado para ejecutarse diariamente a las 02:00.

También se puede ejecutar manualmente desde Azure Data Factory para realizar pruebas y validaciones.

## Reintentos

Se configuraron hasta tres reintentos cuando se presenta un fallo.

Los tiempos de espera son:

- Primer intento: 30 segundos.
- Segundo intento: 60 segundos.
- Tercer intento: 120 segundos.

La actividad ESPERA_BACKOFF calcula el tiempo de espera dependiendo del número de intento.

Después de la espera se vuelve a ejecutar la etapa que presentó el problema.

## Manejo de fallos

El pipeline permite identificar si el error ocurrió en Bronze, Silver o Gold.

Cuando se presenta un fallo se ejecuta el mecanismo de reintentos antes de finalizar el proceso.

También se configuró la alerta ALERTA_FALLO para notificar cuando se presenta una ejecución fallida.

El detalle del error puede revisarse posteriormente desde el monitoreo de Azure Data Factory.

## Reporte diario

Cuando el pipeline termina correctamente se ejecuta la actividad REPORTE_DIARIO.

Esta actividad permite informar el resultado de la ejecución y dejar evidencia del estado final del proceso.

## Anomalías de volumen

El pipeline cuenta con la actividad VALIDAR_ANOMALIA_VOLUMEN para controlar cambios importantes en la cantidad de información procesada.

Cuando se identifica una anomalía se puede ejecutar la alerta ALERTA_ANOMALIA_VOLUMEN.

Este control permite diferenciar una variación importante en el volumen de datos de un fallo normal del pipeline.

## Monitoreo

Las ejecuciones se pueden consultar desde la opción Monitor de Azure Data Factory.

Desde allí se puede revisar el estado de cada ejecución, las actividades realizadas, duración y detalle de los errores.

También queda disponible el historial de ejecuciones exitosas y fallidas.

## Evidencias

Las evidencias se encuentran en la carpeta orchestration/evidencias.

En esta carpeta se guardaron las principales pruebas realizadas durante la configuración:

- Ejecución exitosa del pipeline.
- Historial de ejecuciones.
- Reintentos.
- Esperas de 30, 60 y 120 segundos.
- Pruebas de fallos.
- Alerta de fallo.
- Reporte diario.

## Resultado

La orquestación permite ejecutar Bronze, Silver y Gold de forma controlada desde Azure Data Factory.

El proceso cuenta con ejecución programada, dependencias entre las etapas, reintentos, manejo de fallos, monitoreo, alertas y reporte diario.