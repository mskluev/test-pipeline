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
