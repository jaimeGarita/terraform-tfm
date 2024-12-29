# Infraestructura de Datalake

Este directorio contiene la infraestructura de AWS para el datalake, que incluye un bucket S3, un rol IAM para el crawler, un catálogo de datos en Glue y un grupo de trabajo en Athena.

## Recursos

- **S3 Bucket**: `use1-data-datalake-s3`
- **IAM Role (Crawler)**: `crawler-role`
- **Glue Database**: `datalake_db`
- **Athena Workgroup**: `primary`

## Instrucciones de uso

1. Asegúrate de tener configurado AWS CLI y Terraform.
2. Inicializa el proyecto con el siguiente comando:
   ```bash
   terraform init
