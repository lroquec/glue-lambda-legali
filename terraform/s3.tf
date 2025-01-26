# S3 bucket for uploads
resource "aws_s3_bucket" "legal_files" {
  bucket              = "legal-requests-${var.environment}"
  force_destroy       = true
  object_lock_enabled = false
}

resource "aws_s3_bucket_versioning" "legal_files" {
  bucket = aws_s3_bucket.legal_files.id
  versioning_configuration {
    status = "Suspended" # Change to Suspended temporarily
  }
}

# Bucket folders
resource "aws_s3_object" "folders" {
  for_each      = toset(["compressed/", "raw/", "parquet/", "athena-results/", "scripts/", "temporary/"])
  bucket        = aws_s3_bucket.legal_files.id
  key           = each.key
  content       = ""
  force_destroy = true

  lifecycle {
    ignore_changes = [tags]
  }

  depends_on = [
    aws_s3_bucket.legal_files,
    aws_s3_bucket_versioning.legal_files
  ]
}

# S3 trigger for Lambda
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.legal_files.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.trigger_glue.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "compressed/"
    filter_suffix       = ".tar.gz"
  }
  depends_on = [aws_lambda_permission.allow_bucket]
}

# Upload Python scripts to S3
resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.legal_files.id
  key    = "scripts/process_logs.py"
  source = "../src/glue/process_logs.py"
  etag   = filemd5("../src/glue/process_logs.py")
}

# S3 bucket encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "legal_files" {
  bucket = aws_s3_bucket.legal_files.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Block public access
resource "aws_s3_bucket_public_access_block" "legal_files" {
  bucket = aws_s3_bucket.legal_files.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enforce SSL
resource "aws_s3_bucket_policy" "legal_files" {
  bucket = aws_s3_bucket.legal_files.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "ForceSSLOnly"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.legal_files.arn,
          "${aws_s3_bucket.legal_files.arn}/*"
        ]
        Condition = {
          Bool = {
            "aws:SecureTransport" : "false"
          }
        }
      }
    ]
  })
}