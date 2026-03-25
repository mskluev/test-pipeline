# S3 Input SNS Topic
resource "aws_sns_topic" "s3_input_topic" {
  name = "mskluev-s3-input-topic"
}

# SNS Topic Policy to allow EventBridge to write to it
resource "aws_sns_topic_policy" "s3_input_topic_policy" {
  arn = aws_sns_topic.s3_input_topic.arn
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action   = "sns:Publish"
        Resource = aws_sns_topic.s3_input_topic.arn
      }
    ]
  })
}

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

# SNS Topic for processing events
resource "aws_sns_topic" "process_topic" {
  name = "mskluev-process-topic"
}

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

# SNS Topic for SageMaker calls
resource "aws_sns_topic" "sagemaker_topic" {
  name = "mskluev-sagemaker-topic"
}

# SQS Queue for SageMaker calls
resource "aws_sqs_queue" "sagemaker_queue" {
  name                       = "mskluev-sagemaker-queue"
  visibility_timeout_seconds = 600 # 10 mins for SageMaker to respond (async API if polled, but async inv is better)
}

# SQS Queue Policy
resource "aws_sqs_queue_policy" "sagemaker_queue_policy" {
  queue_url = aws_sqs_queue.sagemaker_queue.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "sns.amazonaws.com"
        }
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.sagemaker_queue.arn
        Condition = {
          ArnEquals = {
            "aws:SourceArn" = aws_sns_topic.sagemaker_topic.arn
          }
        }
      }
    ]
  })
}

resource "aws_sns_topic_subscription" "sagemaker_subscription" {
  topic_arn = aws_sns_topic.sagemaker_topic.arn
  protocol  = "sqs"
  endpoint  = aws_sqs_queue.sagemaker_queue.arn
}
