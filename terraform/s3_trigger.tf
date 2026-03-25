# S3 Input SQS Queue
resource "aws_sqs_queue" "s3_input_queue" {
  name                       = "mskluev-s3-input-queue"
  visibility_timeout_seconds = 60
}

# SQS Queue Policy to allow SNS to write to it
resource "aws_sqs_queue_policy" "s3_input_queue_policy" {
  queue_url = aws_sqs_queue.s3_input_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.s3_input_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.s3_input_topic.arn
          }
        }
      }
    ]
  })
}

# Subscribe SQS to SNS
resource "aws_sns_topic_subscription" "s3_input_subscription" {
  topic_arn = aws_sns_topic.s3_input_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.s3_input_queue.arn
}

# s3-trigger Lambda
data "archive_file" "s3_trigger_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/bin/s3-trigger" # Points to the compiled binary
  output_path = "${path.module}/s3_trigger.zip"
}

resource "aws_lambda_function" "s3_trigger" {
  filename         = data.archive_file.s3_trigger_zip.output_path
  source_code_hash = data.archive_file.s3_trigger_zip.output_base64sha256
  function_name    = "mskluev-s3-trigger"
  role             = aws_iam_role.lambda_role.arn
  handler          = "bootstrap"
  runtime          = "provided.al2" # Standard runtime for Go 1.21+

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      PROCESS_TOPIC_ARN = aws_sns_topic.process_topic.arn
    }
  }
}

resource "aws_lambda_event_source_mapping" "s3_trigger_sqs" {
  event_source_arn = aws_sqs_queue.s3_input_queue.arn
  function_name    = aws_lambda_function.s3_trigger.arn
}

# SNS Topic for processing events
resource "aws_sns_topic" "process_topic" {
  name = "mskluev-process-topic"
}
