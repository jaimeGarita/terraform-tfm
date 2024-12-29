resource "aws_iam_role" "role" {
  name               = var.role_name
  assume_role_policy = var.assume_role_policy
}

output "role_name" {
  value = aws_iam_role.role.name
}
