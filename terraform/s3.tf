# S3 bucket for uploads
resource "aws_s3_bucket" "legal_files" {
  bucket = "legal-requests-${var.environment}"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "legal_files" {
  bucket = aws_s3_bucket.legal_files.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Bucket folders
resource "aws_s3_object" "folders" {
  for_each = toset(["compressed/", "raw/", "parquet/", "athena-results/", "scripts/", "temporary/"])
  bucket   = aws_s3_bucket.legal_files.id
  key      = each.key
  content_type = "application/x-directory"
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
}

# Upload Python scripts to S3
resource "aws_s3_object" "glue_script" {
  bucket = aws_s3_bucket.legal_files.id
  key    = "scripts/process_logs.py"
  source = "../src/glue/process_logs.py"
  etag   = filemd5("../src/glue/process_logs.py")
}

# Lambda zip file creation
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "../src/lambda/trigger_glue.py"
  output_path = "lambda_function.zip"
}