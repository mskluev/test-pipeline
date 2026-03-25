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
    subnet_ids         = var.subnet_ids
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


# 1. SageMaker Role
# Usually we'd make a role first, but eVo-isms make that a pain.
# So we'll use a pre-existing one and include the ARN as a variable in `variables.tf`
# see `var.sagemaker_iam_role`


# 2. SageMaker Model
# This resource links your S3 model artifacts to the Triton Docker container.
resource "aws_sagemaker_model" "triton_model" {
  name               = "mskluev-sagemaker-model"
  execution_role_arn = var.sagemaker_iam_role

  primary_container {
    image          = var.triton_image_uri
    model_data_url = var.model_s3_path
  }

  # eVo requirements
  vpc_config {
    security_group_ids = var.security_group_ids
    subnets            = var.subnet_ids
  }
  enable_network_isolation = true

}

# 3. SageMaker Endpoint Configuration
# This defines the compute resources (instance type, count) for the endpoint.
resource "aws_sagemaker_endpoint_configuration" "triton_ep_config" {
  name = "mskluev-sagemaker-model-config"

  production_variants {
    variant_name           = "AllTraffic"
    model_name             = aws_sagemaker_model.triton_model.name
    initial_instance_count = 1
    instance_type          = var.sm_instance_type
    initial_variant_weight = 1.0
  }

  async_inference_config {
    output_config {
      s3_output_path = "s3://${aws_s3_bucket.output.bucket}/sagemaker-async-output/"
    }
    client_config {
      max_concurrent_invocations_per_instance = 4
    }
  }
}

# 4. SageMaker Endpoint
# This provisions the endpoint and makes it invokable.
resource "aws_sagemaker_endpoint" "triton_endpoint" {
  name                 = "mskluev-sagemaker-endpoint"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.triton_ep_config.name
}
