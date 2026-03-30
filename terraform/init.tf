resource "aws_s3_bucket" "input" {
  bucket = "mskluev-pipeline-input-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_notification" "input_notification" {
  bucket      = aws_s3_bucket.input.id
  eventbridge = true
}

# EventBridge rule to match object created in the input S3 bucket
resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name        = "mskluev-s3-input-rule"
  description = "Fires when a new object is created in the input S3 bucket"
  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [aws_s3_bucket.input.id]
      }
    }
  })
}

# EventBridge target pointing to the new SNS topic
resource "aws_cloudwatch_event_target" "trigger_sns" {
  rule      = aws_cloudwatch_event_rule.s3_object_created.name
  target_id = "TriggerSNS"
  arn       = aws_sns_topic.s3_input_topic.arn
}

# S3 Input SNS Topic
resource "aws_sns_topic" "s3_input_topic" {
  name           = "mskluev-s3-input-topic"
  tracing_config = "Active"
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
