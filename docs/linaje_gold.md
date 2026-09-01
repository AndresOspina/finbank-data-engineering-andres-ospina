# Linaje de datos Gold - FinBank

En esta sección se documenta el origen y las transformaciones de algunos campos calculados en Gold.

## Nivel de riesgo

Origen:
TB_OBLIGACIONES → Silver → fact_cartera

Transformación:
Se toman los días de mora y el saldo de las obligaciones. Con esta información se aplican las reglas de clasificación de riesgo definidas en el pipeline.

Resultado:
nivel_riesgo

Propósito:
Permite identificar el nivel de riesgo de los clientes y apoyar el análisis de cartera.

## Indicador de transacción sospechosa

Origen:
TB_MOV_FINANCIEROS → Silver → fact_movimientos

Transformación:
Los movimientos son limpiados en Silver y posteriormente se comparan con el comportamiento histórico del cliente para identificar movimientos fuera de su comportamiento habitual.

Resultado:
indicador_sospechoso

Propósito:
Ayuda a identificar movimientos que requieren revisión.

## Tasa de mora

Origen:
TB_OBLIGACIONES → Silver → fact_cartera → kpi_cartera_diaria

Transformación:
Se toman las obligaciones procesadas y se identifica cuáles presentan mora. Con esta información se calcula el indicador de mora de la cartera.

Resultado:
tasa_mora

Propósito:
Permite hacer seguimiento diario al comportamiento de la cartera.