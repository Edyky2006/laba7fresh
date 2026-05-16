provider "aws" {
  region                      = "us-east-1"
  access_key                  = "test"
  secret_key                  = "test"
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  s3_use_path_style           = true 

  endpoints {
    s3        = "http://localhost:4566"
    s3control = "http://localhost:4566" 
    lambda    = "http://localhost:4566"
    iam       = "http://localhost:4566"
    sqs       = "http://localhost:4566"
  }
}

resource "aws_s3_bucket" "start" { bucket = "s3-start" }
resource "aws_s3_bucket" "finish" { bucket = "s3-finish" }

resource "aws_s3_bucket_lifecycle_configuration" "lc" {
  bucket = aws_s3_bucket.start.id
  rule {
    id     = "tmp"
    status = "Enabled"
    expiration { days = 1 }
  }
}

resource "aws_sqs_queue" "copy_queue" {
  name = "copy-updates-queue"
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "cop_function.py"
  output_path = "lambda.zip"
}

resource "aws_lambda_function" "copy_lambda" {
  filename      = "lambda.zip"
  function_name = "copy-service"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "cop_function.lambda_handler"
  runtime       = "python3.9"
}


resource "aws_s3_bucket_notification" "notify" {
  bucket = aws_s3_bucket.start.id
  lambda_function {
    lambda_function_arn = aws_lambda_function.copy_lambda.arn
    events              = ["s3:ObjectCreated:*"]
  }
}


resource "aws_lambda_permission" "allow" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.copy_lambda.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.start.arn
}


resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "lambda.amazonaws.com" } }]
  })
}