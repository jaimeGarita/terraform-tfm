resource "aws_dms_endpoint" "source-dms-endpoint" {
  endpoint_id   = "${var.region_alias}-${var.environment}-data-${var.service}-dlk-source"
  endpoint_type = "source"
  engine_name   = "aurora-postgresql"
  
  # Configuración básica para conectar con Aurora PostgreSQL
  database_name = var.database_name
  username      = "demouser"           # El mismo usuario que configuramos en el cluster Aurora
  password      = "Demo1234!"          # La misma contraseña que configuramos en el cluster Aurora
  server_name   = var.cluster          # Usamos el identificador del cluster Aurora
  port          = 5432                 # Puerto estándar de PostgreSQL
  ssl_mode      = "none"               # Deshabilitamos SSL para simplificar
}

resource "aws_dms_endpoint" "target-dms-endpoint" {
  endpoint_type = "target"
  endpoint_id   = "${var.region_alias}-${var.environment}-data-${var.service}-dlk-kinesis-target"
  engine_name   = "kinesis"

  kinesis_settings {
    message_format          = "json-unformatted"
    stream_arn              = aws_kinesis_stream.kinesis-endpoint.arn
    service_access_role_arn = aws_iam_role.kinesis-firehose-delivery-iam-role.arn
  }
}

resource "aws_dms_replication_task" "replication-task" {
  migration_type           = "full-load-and-cdc"
  replication_task_id      = "${var.region_alias}-${var.environment}-data-${var.service}-dlk-replication"
  source_endpoint_arn      = aws_dms_endpoint.source-dms-endpoint.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target-dms-endpoint.endpoint_arn
  replication_instance_arn = var.replication_instance_arn

  lifecycle {
    ignore_changes = [replication_task_settings, table_mappings]
  }

  table_mappings = jsonencode({
    "rules" : [
      {
        "rule-type"      = "selection",
        "rule-id"        = "1",
        "rule-name"      = "select-all-tables",
        "object-locator" = { "schema-name" : "%", "table-name" : "%" },
        "rule-action"    = "include",
        "filters"        = [],
      }
    ]
  })
  replication_task_settings = jsonencode(
    {
      "Logging" : {
        "EnableLogging" : true,
        "LogComponents" : [
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "TRANSFORMATION"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "SOURCE_UNLOAD"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "IO"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "TARGET_LOAD"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "PERFORMANCE"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "SOURCE_CAPTURE"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "SORTER"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "REST_SERVER"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "VALIDATOR_EXT"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "TARGET_APPLY"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "TASK_MANAGER"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "TABLES_MANAGER"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "METADATA_MANAGER"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "FILE_FACTORY"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "COMMON"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "ADDONS"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "DATA_STRUCTURE"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "COMMUNICATION"
          },
          {
            "Severity" : "LOGGER_SEVERITY_DEFAULT",
            "Id" : "FILE_TRANSFER"
          }
        ],
      },
      "StreamBufferSettings" : {
        "StreamBufferCount" : 3,
        "CtrlStreamBufferSizeInMB" : 5,
        "StreamBufferSizeInMB" : 8
      },
      "ErrorBehavior" : {
        "FailOnNoTablesCaptured" : true,
        "ApplyErrorUpdatePolicy" : "LOG_ERROR",
        "FailOnTransactionConsistencyBreached" : false,
        "RecoverableErrorThrottlingMax" : 1800,
        "DataErrorEscalationPolicy" : "SUSPEND_TABLE",
        "ApplyErrorEscalationCount" : 0,
        "RecoverableErrorStopRetryAfterThrottlingMax" : true,
        "RecoverableErrorThrottling" : true,
        "ApplyErrorFailOnTruncationDdl" : false,
        "DataTruncationErrorPolicy" : "LOG_ERROR",
        "ApplyErrorInsertPolicy" : "LOG_ERROR",
        "EventErrorPolicy" : "IGNORE",
        "ApplyErrorEscalationPolicy" : "LOG_ERROR",
        "RecoverableErrorCount" : -1,
        "DataErrorEscalationCount" : 0,
        "TableErrorEscalationPolicy" : "STOP_TASK",
        "RecoverableErrorInterval" : 5,
        "ApplyErrorDeletePolicy" : "IGNORE_RECORD",
        "TableErrorEscalationCount" : 0,
        "FullLoadIgnoreConflicts" : true,
        "DataErrorPolicy" : "LOG_ERROR",
        "TableErrorPolicy" : "SUSPEND_TABLE"
      },
      "TTSettings" : {
        "TTS3Settings" : null,
        "TTRecordSettings" : null,
        "EnableTT" : false
      },
      "FullLoadSettings" : {
        "CommitRate" : 50000,
        "StopTaskCachedChangesApplied" : false,
        "StopTaskCachedChangesNotApplied" : false,
        "MaxFullLoadSubTasks" : 8,
        "TransactionConsistencyTimeout" : 600,
        "CreatePkAfterFullLoad" : false,
        "TargetTablePrepMode" : "DROP_AND_CREATE"
      },
      "TargetMetadata" : {
        "ParallelApplyBufferSize" : 0,
        "ParallelApplyQueuesPerThread" : 0,
        "ParallelApplyThreads" : 0,
        "TargetSchema" : "",
        "InlineLobMaxSize" : 0,
        "ParallelLoadQueuesPerThread" : 0,
        "SupportLobs" : true,
        "LobChunkSize" : 0,
        "TaskRecoveryTableEnabled" : false,
        "ParallelLoadThreads" : 10,
        "LobMaxSize" : 64,
        "BatchApplyEnabled" : false,
        "FullLobMode" : false,
        "LimitedSizeLobMode" : true,
        "LoadMaxFileSize" : 0,
        "ParallelLoadBufferSize" : 1000
      },
      "BeforeImageSettings" : null,
      "ControlTablesSettings" : {
        "HistoryTimeslotInMinutes" : 5,
        "StatusTableEnabled" : false,
        "SuspendedTablesTableEnabled" : false,
        "HistoryTableEnabled" : false,
        "ControlSchema" : "",
        "FullLoadExceptionTableEnabled" : false
      },
      "LoopbackPreventionSettings" : null,
      "CharacterSetSettings" : null,
      "FailTaskWhenCleanTaskResourceFailed" : false,
      "ChangeProcessingTuning" : {
        "StatementCacheSize" : 50,
        "CommitTimeout" : 1,
        "BatchApplyPreserveTransaction" : true,
        "BatchApplyTimeoutMin" : 1,
        "BatchSplitSize" : 0,
        "BatchApplyTimeoutMax" : 30,
        "MinTransactionSize" : 1000,
        "MemoryKeepTime" : 60,
        "BatchApplyMemoryLimit" : 500,
        "MemoryLimitTotal" : 1024
      },
      "ChangeProcessingDdlHandlingPolicy" : {
        "HandleSourceTableDropped" : true,
        "HandleSourceTableTruncated" : true,
        "HandleSourceTableAltered" : true
      },
      "PostProcessingRules" : null
    }
  )
}