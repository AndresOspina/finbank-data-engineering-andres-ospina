# FinBank Data Engineering

## Descripción

Para esta prueba se seleccionó el escenario de Banca y Servicios Financieros, desarrollando la solución para FinBank.

Se utilizó Microsoft Azure como plataforma cloud porque permite integrar almacenamiento, procesamiento, orquestación, seguridad y monitoreo dentro del mismo entorno. Además, facilita la implementación de la arquitectura Medallion utilizada en el proyecto.

El proyecto contiene una solución de ingeniería de datos que parte de la generación de datos de prueba y continúa con su carga y transformación utilizando las capas Bronze, Silver y Gold.

También se trabajó infraestructura como código con Terraform, orquestación en Azure Data Factory, controles de calidad, seguridad, monitoreo y documentación.

## Tecnologías utilizadas

Las principales tecnologías utilizadas fueron:

- Python
- SQL Server
- SQL
- Parquet
- Terraform
- Azure Data Factory
- Azure Data Lake Storage Gen2
- Azure Key Vault
- Azure Monitor
- Log Analytics

## Estructura del proyecto

```text
FINBANK_DATA_ENGINEERING/
│
├── data-generation/
│
├── pipelines/
│   ├── PIPELINE.py
│   ├── SQL/
│   └── output/
│
├── infra/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── backend.tf
│   ├── terraform.tfvars
│   ├── prod.tfvars
│   └── README.md
│
├── orchestration/
│   ├── evidencias/
│   └── README.md
│
├── docs/
│   ├── evidencias/
│   ├── catalogo_datos.md
│   └── linaje_gold.md
│
├── .gitignore
├── CHANGELOG.md
└── README.md
```

El proyecto se organizó por componentes para mantener separadas la generación de datos, las transformaciones, la infraestructura, la orquestación y la documentación.

## Generación de datos

Los datos utilizados son sintéticos y se generan mediante Python.

Se trabajó con información de clientes, productos, sucursales, obligaciones, movimientos financieros, comisiones e incentivos.

Los scripts y archivos utilizados para esta parte se encuentran en `data-generation/`.

## Procesamiento de datos

El procesamiento sigue una arquitectura Medallion.

### Bronze

Es la primera capa del proceso. Recibe la información de origen y conserva campos de auditoría como fecha de ingesta, sistema fuente e identificador de lote.

También se implementaron controles para realizar cargas incrementales y evitar procesar nuevamente información que ya había sido cargada.

### Silver

En Silver se realiza la limpieza y validación de los datos.

En esta etapa se controlan principalmente duplicados, valores nulos, fechas inconsistentes, integridad de la información y otras reglas de calidad.

También se trabajó el manejo de registros rechazados y la protección de información sensible.

### Gold

Gold contiene la información preparada para las consultas de negocio.

En esta capa se construyeron resultados para analizar mora, cartera, transacciones sospechosas, indicadores diarios y una vista consolidada de los clientes.

## Ejecución del pipeline

El proceso local se ejecuta desde:

```text
pipelines/PIPELINE.py
```

Desde la raíz del proyecto:

```powershell
python pipelines/PIPELINE.py
```

El pipeline ejecuta las diferentes etapas en orden y posteriormente realiza las validaciones de calidad.

Para ejecutarlo se debe tener Python, SQL Server y las dependencias del proyecto correctamente configuradas.

## Idempotencia y calidad

El pipeline fue preparado para que una segunda ejecución sobre los mismos datos no genere registros duplicados.

Para esto se utilizan controles de carga, procesamiento incremental y watermark.

También se realizan validaciones sobre duplicados, nulos, integridad referencial, fechas y consistencia de los datos.

Las validaciones principales se encuentran en:

```text
pipelines/SQL/validaciones.sql
```

## Infraestructura

La infraestructura de Azure se encuentra definida como código mediante Terraform dentro de `infra/`.

Se utilizaron recursos como:

- Azure Data Lake Storage Gen2
- Azure Data Factory
- Azure Key Vault
- Log Analytics
- Action Groups
- Recursos de monitoreo

Se trabajó con un ambiente DEV y se dejó preparada la configuración de PROD para poder revisar su plan antes de realizar un despliegue.

Para validar la infraestructura:

```powershell
cd infra
terraform init
terraform validate
terraform plan
```

Después de revisar el plan se puede ejecutar:

```powershell
terraform apply
```

El estado de Terraform se configuró con backend remoto.

Los archivos locales de estado, planes, variables sensibles y otros archivos que no deben llegar al repositorio se encuentran excluidos mediante `.gitignore`.

Las instrucciones adicionales están disponibles en `infra/README.md`.

## Orquestación

La orquestación se realizó en Azure Data Factory con el pipeline:

```text
PL_FINBANK_MEDALLION
```

El proceso ejecuta Bronze, Silver y Gold respetando las dependencias entre cada etapa.

También se configuraron controles para el manejo de fallos, reintentos, monitoreo y alertas.

Los reintentos utilizan tiempos de espera de 30, 60 y 120 segundos.

Además, se cuenta con ejecución programada, validación de anomalías de volumen y reporte de ejecución.

Las evidencias y detalles de esta parte se encuentran en `orchestration/`.

## Seguridad

Se trabajaron permisos separados según el tipo de usuario.

El perfil de análisis tiene acceso de lectura sobre Gold, mientras que Bronze y Silver permanecen restringidos.

Los secretos utilizados por la infraestructura se administran mediante Azure Key Vault para evitar dejar credenciales directamente dentro del código.

También se aplicaron controles sobre datos sensibles antes de que la información llegue a Gold.

## Monitoreo

Las ejecuciones pueden revisarse desde Azure Data Factory para identificar el estado de cada actividad y detectar posibles fallos.

Como parte del monitoreo también se utilizaron Azure Monitor, Log Analytics y Action Groups.

Las evidencias de ejecución, reintentos, alertas y reportes se encuentran dentro de las carpetas de evidencias del proyecto.

## Documentación

La documentación adicional está disponible en `docs/`.

El catálogo de datos se encuentra en:

```text
docs/catalogo_datos.md
```

El linaje de campos Gold se encuentra en:

```text
docs/linaje_gold.md
```

Las capturas y pruebas realizadas durante el desarrollo están almacenadas en:

```text
docs/evidencias/
orchestration/evidencias/
```

Los cambios realizados durante el proyecto están registrados en `CHANGELOG.md`.

## Decisiones tomadas

Se utilizó arquitectura Medallion para separar claramente los datos originales, los datos limpios y la información preparada para negocio.

Terraform se utilizó para mantener la infraestructura como código y facilitar su reproducción.

Azure Data Factory se utilizó para controlar la ejecución de las capas, las dependencias, los reintentos y el monitoreo.

Parquet se utilizó como formato de almacenamiento para las capas de datos por ser adecuado para procesamiento analítico.

SQL Server se utilizó como base de datos para trabajar las fuentes, transformaciones y validaciones del ejercicio.

## Resultado

El proyecto deja integrado el proceso de generación de datos, transformación Bronze-Silver-Gold, controles de calidad, infraestructura en Azure, orquestación, seguridad y monitoreo.

Cada componente quedó separado dentro del repositorio para facilitar su ejecución, revisión y mantenimiento.