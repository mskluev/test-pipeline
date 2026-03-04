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

# EventBridge target pointing to the first Lambda
resource "aws_cloudwatch_event_target" "trigger_lambda" {
  rule      = aws_cloudwatch_event_rule.s3_object_created.name
  target_id = "TriggerLambda"
  arn       = aws_lambda_function.s3_trigger.arn
}

# Permission to allow EventBridge to invoke the Lambda
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_trigger.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_object_created.arn
}
