# FinBank Data Engineering

## 1. Objetivo

Proyecto de ingeniería de datos para FinBank. La solución genera datos sintéticos, los carga en SQL Server y los procesa mediante una arquitectura Medallion:

Generación → SQL Server → Bronze → Silver → Gold

También se incluye infraestructura en Azure con Terraform, orquestación y monitoreo.

## 2. Fuentes de datos

Los datos son generados con Python y cargados en SQL Server.

| Tabla | Descripción |
|---|---|
| TB_CLIENTES_CORE | Clientes |
| TB_PRODUCTOS_CAT | Productos financieros |
| TB_SUCURSALES_RED | Sucursales |
| TB_OBLIGACIONES | Obligaciones financieras |
| TB_MOV_FINANCIEROS | Movimientos |
| TB_COMISIONES_LOG | Comisiones |
| TB_INCENTIVOS | Incentivos |

Los datos de prueba se generan en CSV/JSON.

## 3. Arquitectura Medallion

### Bronze

Recibe los datos de SQL Server manteniendo la información original.

Se implementó:

- Formato Parquet.
- Metadatos de ingesta.
- Identificador de lote.
- Sistema fuente.
- Particionamiento por año, mes y día.
- Control incremental mediante watermark.
- Auditoría de la ingesta.

Si no existen registros nuevos, no se vuelven a procesar.

### Silver

Contiene los datos limpios y validados.

Se realizan:

- Eliminación de duplicados.
- Validación de campos obligatorios.
- Validación de fechas.
- Validación de relaciones.
- Tratamiento de nulos.
- Estandarización de datos.
- Protección de información sensible.
- Registro de datos rechazados.
- Detección de transacciones sospechosas.
- Reporte de calidad.

Los registros que no cumplen las reglas se conservan en tablas de rechazados con el motivo correspondiente.

### Gold

Contiene los datos preparados para análisis y reportes.

Dimensiones:

- `dim_clientes`
- `dim_productos`
- `dim_geografia`
- `dim_canal`

Tablas analíticas:

- `fact_transacciones`
- `fact_cartera`
- `fact_rentabilidad_cliente`
- `kpi_cartera_diaria`
- `reporte_regulatorio`
- `vista_cliente_360`

## 4. Reglas de negocio

La solución incluye:

- Clasificación de cartera según días de mora.
- Cálculo de provisiones.
- Indicadores de cartera.
- Rentabilidad mensual.
- CLTV.
- Identificación de movimientos sospechosos.
- Consolidación de información del cliente.
- Reporte regulatorio.

### Detección de transacciones sospechosas

Se consideran diferentes señales:

- Monto frente al comportamiento histórico.
- Horario.
- Frecuencia diaria.
- Canal utilizado.

Las señales se almacenan en Silver y se trasladan a Gold para su análisis.

## 5. Calidad de datos

Silver genera un reporte por ejecución con:

- Registros de origen.
- Registros válidos.
- Registros rechazados.
- Porcentaje de conformidad.
- Control de nulos por columna.

También se validan duplicados e integridad referencial.

En la ejecución de prueba se obtuvieron:

- 140 registros generados.
- 139 registros válidos en Silver.
- 1 registro rechazado.
- Calidad global: 99.29%.

El registro rechazado corresponde a una obligación cuya fecha de vencimiento era anterior a la fecha de desembolso.

## 6. Pruebas automatizadas

Se implementaron seis pruebas:

1. Duplicados en `dim_clientes`.
2. Duplicados en `fact_transacciones`.
3. Integridad referencial de `fact_transacciones`.
4. Nulos críticos de `fact_cartera`.
5. Consistencia de fraude entre Silver y Gold.
6. Consistencia del cálculo CLTV.

Resultado de la ejecución:

`6 PASS | 0 FAIL`

## 7. Linaje Gold

### monto_usd

Origen:

`silver.movimientos.vr_mov`

Transformación:

`vr_mov / TRM`

Destino:

`gold.fact_transacciones.monto_usd`

La TRM utilizada en el proceso es 4000 COP por USD.

### provision_estimada

Origen:

`silver.obligaciones.sdo_capital`

Transformación:

El porcentaje de provisión se determina según los días de mora y se aplica sobre el saldo de capital.

Destino:

`gold.fact_cartera.provision_estimada`

### cltv_mensual

Origen:

`silver.obligaciones`, `silver.comisiones` e `silver.incentivos`

Transformación:

Se consolidan los ingresos por intereses y las comisiones cobradas por cliente y mes.

`cltv_mensual = ingreso_intereses + comisiones_cobradas`

Destino:

`gold.fact_rentabilidad_cliente.cltv_mensual`

## 8. Objetos de análisis

`fact_rentabilidad_cliente`

Consolida la rentabilidad histórica de los clientes.

`kpi_cartera_diaria`

Presenta indicadores de cartera, saldo y mora.

`reporte_regulatorio`

Consolida información transaccional y de cartera.

`vista_cliente_360`

Integra la información financiera principal de cada cliente.

## 9. Idempotencia y errores

El pipeline puede ejecutarse nuevamente sin generar duplicados.

Bronze controla los registros ya procesados mediante watermark.

Los errores se registran en:

`dbo.PIPELINE_ERROR_LOG`

Se incluye un registro de prueba para comprobar el funcionamiento del mecanismo de errores.

## 10. Infraestructura Azure

La infraestructura se administra mediante Terraform.

Componentes principales:

- Resource Group.
- Azure Data Lake Storage Gen2.
- Bronze.
- Silver.
- Gold.
- Azure Data Factory.
- Key Vault.
- Log Analytics.
- Azure Monitor.
- Action Group.
- Alertas.
- Backend remoto de Terraform.

Los archivos de infraestructura están en:

`/infra`

## 11. Ambientes

Se manejan dos configuraciones:

### DEV

Utilizado para el despliegue y las pruebas.

### PROD

Configurado mediante variables independientes y validado mediante Terraform Plan.

No se realiza `apply` sobre PROD durante las pruebas.

## 12. Seguridad

Se utilizan variables y servicios separados para evitar almacenar información sensible directamente en el código.

Se considera:

- Key Vault.
- Contenedores privados.
- Estado remoto de Terraform.
- Exclusión de archivos sensibles mediante `.gitignore`.
- Protección de documentos personales en Silver.

## 13. Orquestación

Azure Data Factory se utiliza para ejecutar el flujo:

Generación/Carga → Bronze → Silver → Gold → Validaciones

La definición de orquestación se encuentra en:

`/orchestration`

## 14. Estructura principal

```text
FINBANK_DATA_ENGINEERING
│
├── infra
├── pipelines
├── SQL
├── datos_generados
├── GENERAR_DATOS.py
├── CARGAR_DATOS.py
├── config.json
└── README.md