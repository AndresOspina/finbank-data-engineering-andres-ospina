# Infraestructura - FinBank

## Descripción

La infraestructura del proyecto se implementó en Microsoft Azure utilizando Terraform.

Se trabajó con un ambiente DEV para realizar las pruebas y se dejó preparada la configuración de PROD de forma independiente, sin realizar el despliegue de producción.

## Recursos utilizados

Los principales recursos creados en Azure fueron:

- Resource Group para agrupar los recursos del proyecto.
- Azure Data Lake Storage Gen2 para el almacenamiento de datos.
- Contenedores Bronze, Silver y Gold.
- Azure Data Factory para la orquestación.
- Azure Key Vault para la gestión de secretos.
- Log Analytics para monitoreo.
- Action Group para las notificaciones.
- Alerta de monitoreo sobre el Storage Account.

Los recursos del ambiente DEV fueron creados principalmente en la región East US.

## Archivos de Terraform

La configuración de Terraform se encuentra organizada de la siguiente manera:

- main.tf contiene los recursos de Azure.
- variables.tf contiene las variables utilizadas.
- outputs.tf contiene las salidas de Terraform.
- backend.tf contiene la configuración del estado remoto.
- terraform.tfvars contiene la configuración de DEV.
- prod.tfvars contiene la configuración de PROD.

## Despliegue de DEV

Primero se debe iniciar sesión en Azure:

    az login

Después, desde la carpeta infra, se inicializa y valida Terraform:

    terraform init
    terraform validate
    terraform plan

Una vez revisado el plan se puede realizar el despliegue:

    terraform apply

## Ambiente PROD

PROD tiene una configuración independiente y utiliza un workspace separado.

Para revisar este ambiente se utilizan los siguientes comandos:

    terraform workspace select prod
    terraform plan -var-file="prod.tfvars"

Durante el desarrollo del proyecto PROD solamente fue validado mediante terraform plan.

No se realizó terraform apply sobre este ambiente para evitar crear recursos productivos innecesarios durante la prueba.

## Estado de Terraform

El estado de Terraform se configuró para almacenarse de forma remota en Azure Storage.

Se utiliza el Storage Account stfinbankdev2896 y el contenedor tfstate.

El backend remoto permite mantener el estado fuera del repositorio y administrar de forma separada los ambientes.

Los archivos de estado locales y otros archivos generados por Terraform están excluidos de Git mediante .gitignore.

## Seguridad

Los contenedores de datos se configuraron como privados.

Azure Key Vault se utiliza para la administración de secretos y se evita almacenar contraseñas o tokens directamente dentro del código.

También se excluyen del repositorio los archivos de estado, variables locales y otros archivos que puedan contener información sensible.

## Monitoreo

Como parte de la infraestructura se configuraron Log Analytics y un Action Group.

También se creó una alerta para monitorear la actividad del Storage Account.

Estos recursos complementan el monitoreo realizado desde Azure Data Factory.

## Evidencias

Las evidencias de la infraestructura se encuentran en la carpeta docs/evidencias.

Allí se encuentran las validaciones de Terraform, los recursos creados en Azure, almacenamiento, backend remoto, configuración de DEV y PROD y monitoreo.

## Resultado

La infraestructura quedó definida mediante Terraform y separada por ambientes.

DEV fue desplegado y utilizado durante las pruebas, mientras que PROD quedó preparado para validar su configuración sin realizar un despliegue real.