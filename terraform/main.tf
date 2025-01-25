# Athena workgroup and output location
resource "aws_athena_workgroup" "legal_requests" {
  name = "legal_requests_${var.environment}"

  configuration {
    enforce_workgroup_configuration = true
    result_configuration {
      output_location = "s3://${aws_s3_bucket.legal_files.bucket}/athena-results/"
    }
  }
}

# Glue database
resource "aws_glue_catalog_database" "connection_tracking" {
  name = "connection_tracking_${var.environment}"
}

# Glue crawler
resource "aws_glue_crawler" "connection_logs" {
  database_name = aws_glue_catalog_database.connection_tracking.name
  name          = "connection-logs-crawler"
  role          = aws_iam_role.glue_role.arn

  s3_target {
    path = "s3://${aws_s3_bucket.legal_files.bucket}/parquet/"
  }

  schema_change_policy {
    delete_behavior = "LOG"
    update_behavior = "UPDATE_IN_DATABASE"
  }
}

# IAM role for Glue
resource "aws_iam_role" "glue_role" {
  name = "legal_glue_role_${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
      }
    ]
  })
}

# Attach AWS managed policy for Glue
resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# S3 access for Glue
resource "aws_iam_role_policy" "glue_s3" {
  name = "legal_glue_s3_${var.environment}"
  role = aws_iam_role.glue_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.legal_files.arn,
          "${aws_s3_bucket.legal_files.arn}/*"
        ]
      }
    ]
  })
}

# Glue Job
resource "aws_glue_job" "process_logs" {
  name              = "process-connection-logs"
  role_arn          = aws_iam_role.glue_role.arn
  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2

  command {
    script_location = "s3://${aws_s3_bucket.legal_files.bucket}/scripts/process_logs.py"
    python_version  = "3"
  }

  default_arguments = {
    "--enable-metrics" = "true"
    "--job-language"   = "python"
    "--TempDir"        = "s3://${aws_s3_bucket.legal_files.bucket}/temporary/"
  }
}

# S3 Event trigger Lambda
resource "aws_lambda_function" "trigger_glue" {
  filename         = "lambda_function.zip"
  function_name    = "trigger_glue_job_${var.environment}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "python3.10"
  timeout         = 30

  environment {
    variables = {
      GLUE_JOB_NAME = aws_glue_job.process_logs.name
    }
  }
}

# Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  name = "trigger_glue_lambda_role_${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Lambda policy for Glue
resource "aws_iam_role_policy" "lambda_glue" {
  name = "lambda_glue_${var.environment}"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["glue:StartJobRun"]
      Resource = [aws_glue_job.process_logs.arn]
    }]
  })
}

# Lambda permission for S3
resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trigger_glue.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.legal_files.arn
}