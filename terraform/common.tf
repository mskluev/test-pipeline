resource "aws_s3_bucket" "output" {
  bucket = "mskluev-pipeline-output-${data.aws_caller_identity.current.account_id}"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_role" {
  name                 = "service-mskluev-lambda-role"
  assume_role_policy   = data.aws_iam_policy_document.lambda_assume_role.json
  permissions_boundary = var.permissions_boundary
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Common policy for lambdas (S3, SNS, SQS permissions)
resource "aws_iam_role_policy" "lambda_policy" {
  name = "service-mskluev-lambda-permissions"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.input.arn,
          "${aws_s3_bucket.input.arn}/*",
          aws_s3_bucket.output.arn,
          "${aws_s3_bucket.output.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["sns:Publish"]
        Resource = [
          aws_sns_topic.process_topic.arn,
          aws_sns_topic.sagemaker_topic.arn
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = [
          aws_sqs_queue.process_queue.arn,
          aws_sqs_queue.sagemaker_queue.arn,
          aws_sqs_queue.s3_input_queue.arn
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["sagemaker:InvokeEndpointAsync"]
        Resource = ["*"] # Best practice: restrict to specific endpoint ARN
      },
      # When a Lambda is VPC-enabled, it doesn't just "float" in your network. 
      # AWS has to create a networking bridge between the Lambda service and your private subnets. 
      # To do this, the Lambda's execution role must be allowed to manage those network interfaces.
      {
        Effect   = "Allow"
        Resource = "*"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
      }

    ]
  })
}
