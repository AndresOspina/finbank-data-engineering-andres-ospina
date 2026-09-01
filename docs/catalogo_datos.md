# Catálogo de datos - FinBank

Este documento describe los principales datos utilizados en las capas Silver y Gold, su origen y el manejo de información sensible.

## Datos sensibles

En la información de clientes se identificaron como datos PII el nombre, apellido y número de documento.

Desde la capa Silver estos datos se manejan de forma enmascarada para evitar exponer la información original.

Campos identificados:

- nomb_cli: nombre del cliente. PII.
- apell_cli: apellido del cliente. PII.
- num_doc: número de documento. PII.
- num_doc_enmascarado: versión protegida del documento.

La evidencia del enmascaramiento se encuentra en:

docs/evidencias/fase3_silver_enmascaramiento.png

El perfil Analista no tiene acceso a Bronze ni Silver. Su acceso está limitado a lectura en Gold.

## Silver

### clientes

Origen: TB_CLIENTES_CORE

Principales campos:

- id_cli: identificador del cliente.
- nomb_cli: nombre del cliente. PII.
- apell_cli: apellido del cliente. PII.
- num_doc: documento del cliente. PII.
- num_doc_enmascarado: documento protegido generado en Silver.

### movimientos

Origen: TB_MOV_FINANCIEROS

Principales campos:

- id_movimiento: identificador del movimiento.
- id_cliente: cliente relacionado.
- valor: valor de la transacción.
- fecha: fecha del movimiento.
- tipo_movimiento: tipo de operación realizada.

Los valores financieros se consideran información confidencial.

### obligaciones

Origen: TB_OBLIGACIONES

Principales campos:

- id_obligacion: identificador de la obligación.
- id_cliente: cliente asociado.
- saldo: saldo pendiente.
- dias_mora: cantidad de días en mora.
- estado: estado de la obligación.

El saldo y la información de mora se consideran datos confidenciales.

## Gold

### dim_clientes

Origen: información procesada de clientes en Silver.

Contiene la información necesaria para identificar y segmentar clientes sin exponer directamente los datos personales originales.

Principales campos:

- id_cliente
- cliente
- segmento

### fact_cartera

Origen: obligaciones procesadas en Silver.

Contiene información utilizada para analizar cartera y riesgo.

Principales campos:

- id_cliente
- saldo
- dias_mora
- nivel_riesgo

### fact_movimientos

Origen: movimientos procesados en Silver.

Contiene los movimientos financieros utilizados para análisis y reglas de negocio.

Principales campos:

- id_cliente
- valor
- fecha
- indicador_sospechoso

### kpi_cartera_diaria

Origen: información procesada en Gold.

Contiene los indicadores diarios utilizados para seguimiento de cartera.

Principales campos:

- fecha
- obligaciones_activas
- saldo_total
- tasa_mora

## Accesos

Ingeniero de Datos:
lectura y escritura en Bronze, Silver y Gold.

Analista:
solo lectura en Gold.

Administrador:
control total sobre los recursos del proyecto.