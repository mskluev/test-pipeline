# SQS Queue for processing events
resource "aws_sqs_queue" "process_queue" {
  name                       = "mskluev-process-queue"
  visibility_timeout_seconds = 60 # Allow time for lambda to process
}

# SQS Queue Policy to allow SNS to write to it
resource "aws_sqs_queue_policy" "process_queue_policy" {
  queue_url = aws_sqs_queue.process_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.process_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.process_topic.arn
          }
        }
      }
    ]
  })
}

# Subscribe SQS to SNS
resource "aws_sns_topic_subscription" "process_subscription" {
  topic_arn = aws_sns_topic.process_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.process_queue.arn
}

# processor Lambda
data "archive_file" "processor_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/bin/processor"
  output_path = "${path.module}/processor.zip"
}

resource "aws_lambda_function" "processor" {
  filename         = data.archive_file.processor_zip.output_path
  source_code_hash = data.archive_file.processor_zip.output_base64sha256
  function_name    = "mskluev-processor"
  role             = aws_iam_role.lambda_role.arn
  handler          = "bootstrap"
  runtime          = "provided.al2"

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      SAGEMAKER_TOPIC_ARN = aws_sns_topic.sagemaker_topic.arn
    }
  }

  tracing_config {
    mode = "Active"
  }
}

resource "aws_lambda_event_source_mapping" "processor_sqs" {
  event_source_arn = aws_sqs_queue.process_queue.arn
  function_name    = aws_lambda_function.processor.arn
}

# SNS Topic for SageMaker calls
resource "aws_sns_topic" "sagemaker_topic" {
  name           = "mskluev-sagemaker-topic"
  tracing_config = "Active"
}
