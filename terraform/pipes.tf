data "aws_iam_policy_document" "pipe_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["pipes.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "pipe_role" {
  name                 = "service-mskluev-pipe-role"
  assume_role_policy   = data.aws_iam_policy_document.pipe_assume_role.json
  permissions_boundary = var.permissions_boundary
}

resource "aws_iam_role_policy" "pipe_policy" {
  name = "service-mskluev-pipe-policy"
  role = aws_iam_role.pipe_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:ReceiveMessage",
          "sqs:DeleteMessage",
          "sqs:GetQueueAttributes"
        ]
        Resource = aws_sqs_queue.process_queue.arn
      },
      {
        Effect = "Allow"
        Action = [
          "lambda:InvokeFunction"
        ]
        Resource = aws_lambda_function.processor.arn
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.sagemaker_topic.arn
      }
    ]
  })
}

resource "aws_pipes_pipe" "processor_pipe" {
  name     = "mskluev-processor-pipe"
  role_arn = aws_iam_role.pipe_role.arn

  source = aws_sqs_queue.process_queue.arn
  source_parameters {
    sqs_queue_parameters {
      batch_size = 1 # Process one at a time for simplicity
    }
  }

  enrichment = aws_lambda_function.processor.arn

  target = aws_sns_topic.sagemaker_topic.arn
}
