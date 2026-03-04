resource "aws_s3_bucket" "input" {
  bucket = "mskluev-pipeline-input-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_notification" "input_notification" {
  bucket      = aws_s3_bucket.input.id
  eventbridge = true
}

resource "aws_s3_bucket" "output" {
  bucket = "mskluev-pipeline-output-${data.aws_caller_identity.current.account_id}"
}
