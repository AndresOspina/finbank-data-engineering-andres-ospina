# CHANGELOG - FinBank Data Engineering

Este archivo registra los principales cambios realizados durante el desarrollo del proyecto.

## 2026-08-31 - Seguridad y gobierno de datos

**Autor:** Andres Ospina

- Configuración y validación de permisos mediante RBAC.
- Validación del acceso del perfil Analista a la capa Gold.
- Validación de restricción del perfil Analista sobre Bronze y Silver.
- Validación de roles para Ingeniería de Datos y Administración.
- Documentación del catálogo de datos.
- Documentación del linaje de campos Gold.
- Organización de las evidencias de seguridad y gobierno.
- Revisión de la documentación general del proyecto.

## 2026-08-30 - Orquestación y monitoreo

**Autor:** Andres Ospina

- Implementación del pipeline `PL_FINBANK_MEDALLION` en Azure Data Factory.
- Configuración del flujo Bronze → Silver → Gold.
- Configuración de dependencias entre las etapas.
- Configuración de ejecución programada.
- Implementación del manejo de fallos.
- Implementación de reintentos controlados.
- Configuración de esperas de 30, 60 y 120 segundos.
- Configuración de alertas y reporte diario.
- Implementación de validación de anomalías de volumen.
- Validación de ejecuciones exitosas y escenarios de fallo.

## 2026-08-29 - Infraestructura Azure

**Autor:** Andres Ospina

- Implementación de infraestructura mediante Terraform.
- Creación de recursos para el ambiente DEV.
- Implementación de Azure Data Lake Storage Gen2.
- Creación de las zonas Bronze, Silver y Gold.
- Implementación de Azure Data Factory y Azure Key Vault.
- Configuración de Log Analytics, Action Group y monitoreo.
- Configuración del backend remoto de Terraform.
- Separación de configuraciones para DEV y PROD.
- Validación de PROD mediante `terraform plan`.
- Organización del repositorio por componentes.

## 2026-08-28 - Pipeline Medallion

**Autor:** Andres Ospina

- Implementación de las capas Bronze, Silver y Gold.
- Implementación de limpieza y reglas de calidad en Silver.
- Manejo de registros rechazados.
- Protección de información sensible.
- Implementación de estructuras analíticas en Gold.
- Implementación de indicadores de cartera y Cliente 360.
- Implementación de detección de transacciones sospechosas.
- Implementación de validaciones automáticas de calidad.
- Implementación del pipeline local para ejecutar el proceso completo.
- Validación de idempotencia y procesamiento incremental.

## 2026-08-27 - Generación y carga de datos

**Autor:** Andres Ospina

- Creación de la base de datos `FINBANK`.
- Creación de las tablas utilizadas como fuente.
- Implementación de la generación de datos sintéticos.
- Generación de archivos CSV y JSON.
- Implementación de la carga hacia SQL Server.
- Creación de datos controlados para probar reglas de calidad.
- Validación inicial de relaciones y registros cargados.