variable "role_name" {
  description = "El nombre del rol IAM"
  type        = string
}

variable "assume_role_policy" {
  description = "Política de confianza para asumir el rol"
  type        = string
}
