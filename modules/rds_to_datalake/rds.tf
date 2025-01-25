resource "aws_db_instance" "rds_instance" {
  identifier        = "${var.service}-${var.environment}-db"
  engine            = "postgres"  # Ajusta según tu necesidad
  instance_class    = "db.t3.medium"  # Ajusta según tu necesidad
  
  allocated_storage = 20
  storage_type      = "gp2"
  
  db_name          = var.database_name
  username         = "admin"  # Considera usar secrets manager
  password         = "dummy"  # Deberías obtener esto de secrets manager
  
  vpc_security_group_ids = [aws_security_group.rds_sg.id]
  
  tags = merge(
    var.tags,
    {
      Name = "${var.service}-${var.environment}-db"
    }
  )
}

resource "aws_security_group" "rds_sg" {
  name        = "${var.service}-${var.environment}-rds-sg"
  description = "Security group for RDS instance"
  vpc_id      = var.vpc_id  # Necesitarás agregar esta variable

  tags = var.tags
}
