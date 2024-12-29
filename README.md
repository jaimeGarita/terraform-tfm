# Terraform AWS Infrastructure

Este repositorio contiene Terraform scripts para crear infraestructura en AWS del TFM de Mioti "Cloud & Data Engineering"

## Estructura de directorios

- **microservice/**: Contiene la infraestructura para el microservicio.
- **datalake/**: Contiene la infraestructura para el datalake.

## Instrucciones

1. Asegúrate de tener configurado AWS CLI y Terraform en tu máquina.
2. Configurar Credenciales de AWS

Configura tus credenciales de AWS utilizando variables de entorno o un perfil de AWS CLI.

`export AWS_ACCESS_KEY_ID="tu_access_key"`
`export AWS_SECRET_ACCESS_KEY="tu_secret_key"`
`export AWS_SESSION_TOKEN="tu_session_token" # Solo si usas credenciales temporales`

3. posicionarse en el reusurso que se quiere crear
   ```bash
   cd microservice
   ```
   o
   ```bash
   cd datalake
   ```
4. Para inicializar el repositorio, corre el siguiente comando:
   ```bash
   terraform init
   ```
5. Para validar los scripts de Terraform, corre el siguiente comando:
   ```bash
   terraform validate
   ```
6. Para planificar los recursos que se van a crear, corre el siguiente comando:
   ```bash
   terraform plan
   ```
7. Para aplicar los cambios y crear los recursos, corre el siguiente comando:
    ```bash
   terraform apply
    ```