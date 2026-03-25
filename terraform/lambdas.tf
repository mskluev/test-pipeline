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
        Effect = "Allow"
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
    subnet_ids = var.subnet_ids
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
    subnet_ids = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = {
      SAGEMAKER_TOPIC_ARN = aws_sns_topic.sagemaker_topic.arn
    }
  }
}

resource "aws_lambda_event_source_mapping" "processor_sqs" {
  event_source_arn = aws_sqs_queue.process_queue.arn
  function_name    = aws_lambda_function.processor.arn
}

# sagemaker-caller Lambda
data "archive_file" "sagemaker_caller_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../lambdas/bin/sagemaker-caller"
  output_path = "${path.module}/sagemaker_caller.zip"
}

resource "aws_lambda_function" "sagemaker_caller" {
  filename         = data.archive_file.sagemaker_caller_zip.output_path
  source_code_hash = data.archive_file.sagemaker_caller_zip.output_base64sha256
  function_name    = "mskluev-sagemaker-caller"
  role             = aws_iam_role.lambda_role.arn
  handler          = "bootstrap"
  runtime          = "provided.al2"

  vpc_config {
    subnet_ids = var.subnet_ids
    security_group_ids = var.security_group_ids
  }

  environment {
    variables = merge(
    {
      SAGEMAKER_ENDPOINT_NAME = aws_sagemaker_endpoint.triton_endpoint.name
    },
    # Only set if `aws_endpoint_url_sagemaker_runtime` is defined
    var.aws_endpoint_url_sagemaker_runtime != null && var.aws_endpoint_url_sagemaker_runtime != "" ? {
      AWS_ENDPOINT_URL_SAGEMAKER_RUNTIME = var.aws_endpoint_url_sagemaker_runtime
    } : {}
  )
  }
}


resource "aws_lambda_event_source_mapping" "sagemaker_sqs" {
  event_source_arn = aws_sqs_queue.sagemaker_queue.arn
  function_name    = aws_lambda_function.sagemaker_caller.arn
}
