resource "aws_glue_catalog_database" "datalake_db" {
  name = var.glue_database_name
}

resource "aws_glue_catalog_table" "datalake_table" {
  database_name = aws_glue_catalog_database.datalake_db.name
  name          = "datalake_table"

  storage_descriptor {
    columns {
      name = "column1"
      type = "string"
    }

    location      = "s3://${var.bucket_name}/"
    input_format  = "org.apache.hadoop.mapred.TextInputFormat"
    output_format = "org.apache.hadoop.hive.ql.io.HiveIgnoreKeyTextOutputFormat"
    serde_info {
      name                 = "datalake_serde"
      serialization_library = "org.apache.hadoop.hive.serde2.lazy.LazySimpleSerDe"
      parameters = {
        "field.delim" = ","
      }
    }
  }
}

resource "aws_athena_workgroup" "workgroup" {
  name        = var.athena_workgroup_name
  state       = "ENABLED"
  description = "Primary Athena workgroup"

  configuration {
    result_configuration {
      output_location = "s3://${var.bucket_name}/athena-results/"
    }
  }
}

output "glue_catalog_db" {
  value = aws_glue_catalog_database.datalake_db.name
}

output "athena_workgroup" {
  value = aws_athena_workgroup.workgroup.name
}
