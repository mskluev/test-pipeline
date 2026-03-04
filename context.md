# Project Context & System Design

This document details the *how* of the AWS Data Processing Pipeline, covering the technology stack, project structure, and the architectural flow of the system.

## Technology Stack

**Infrastructure & Deployment**
- **Terraform**: Used as the Infrastructure-as-Code (IaC) tool to declaratively define and provision all AWS resources.
- **Make**: Used to simplify build, generation, and deployment commands.

**Application Logic**
- **Golang**: The programming language used for all Lambda functions. Chosen for its high performance, low memory footprint, and fast cold-start times.
- **AWS Lambda (Custom Runtime)**: Lambdas run on the `provided.al2` (Amazon Linux 2) custom runtime using compiled Go binaries (`bootstrap`).

**Messaging & Serialization**
- **Protocol Buffers (Protobuf)**: Used as the Interface Definition Language (IDL) to define the schemas for messages passed between services.
- **Buf**: A modern tool built for managing, linting, and generating code from Protobuf files.
- **JSON**: While schemas are defined in Protobuf, the actual serialized payload sent over AWS services (SNS/SQS) is typically JSON mapped to those Protobuf definitions for ease of inspection and AWS compatibility.

**AWS Services**
- **S3**: Object storage for initial inputs and final processed outputs.
- **EventBridge**: Captures initial S3 creation events.
- **SNS (Simple Notification Service)**: Publishes messages to decouple the producer from multiple potential consumers.
- **SQS (Simple Queue Service)**: Buffers messages to ensure reliable delivery and throttle load to downstream Lambdas.
- **SageMaker**: The destination for the processed data, utilized via Asynchronous Endpoints.

---

## Monorepo Directory Structure

```text
test-pipeline/
├── lambdas/              # Single Go module containing all function code
│   ├── cmd/              # Entrypoints for the various lambdas
│   │   ├── processor/
│   │   ├── s3-trigger/
│   │   └── sagemaker-caller/
│   ├── pkg/
│   │   └── proto/        # Go code auto-generated from .proto files
│   └── bin/              # Compiled 'bootstrap' binaries (created by runnning `make build`)
├── proto/                # Original Protobuf schema definitions (.proto files) and Buf config
├── terraform/            # Infrastructure-as-Code definitions
│   ├── eventbridge.tf
│   ├── lambdas.tf
│   ├── main.tf
│   ├── s3.tf
│   └── sns_sqs.tf
├── Makefile              # Build automation commands
├── spec.md               # 'What' and 'Why' documentation
└── context.md            # This file
```

---

## System Architecture & Data Flow

All AWS resources are prefixed with `mskluev-`.

1. **Ingestion**: 
   - A user or external system drops a file into the input S3 bucket (`mskluev-pipeline-input-<account_id>`).
2. **Event Trigger**: 
   - An S3 "Object Created" event is matched by an **EventBridge Rule**.
   - EventBridge invokes the `s3-trigger` Lambda function, passing the event details.
3. **Initial Dispatch**: 
   - The `s3-trigger` Lambda reads the event to determine the S3 file location.
   - It constructs a `ProcessingEvent` (defined via Protobuf) and publishes it to the `mskluev-process-topic` **SNS Topic**.
4. **Processing Queue**: 
   - The SNS topic forwards the message to the `mskluev-process-queue` **SQS Queue**.
5. **Data Processing**: 
   - The `processor` Lambda consumes messages from the SQS queue.
   - It performs the necessary data manipulation or validation.
   - Upon success, it constructs a `SageMakerEvent` and publishes it to the `mskluev-sagemaker-topic` **SNS Topic**.
6. **Inference Queue**: 
   - The SageMaker SNS topic forwards the message to the `mskluev-sagemaker-queue` **SQS Queue**.
7. **SageMaker Invocation**: 
   - The `sagemaker-caller` Lambda consumes the event from the SQS queue.
   - It makes an API call to **SageMaker InvokeEndpointAsync** to offload the heavy machine learning inference.
8. **Output**: 
   - SageMaker (configured separately) will ultimately drop the inference results into the output S3 bucket (`mskluev-pipeline-output-<account_id>`).
