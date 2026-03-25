# EventBridge rule to match object created in the input S3 bucket
resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name        = "mskluev-s3-input-rule"
  description = "Fires when a new object is created in the input S3 bucket"
  event_pattern = jsonencode({
    source = ["aws.s3"]
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
