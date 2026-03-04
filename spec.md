# Project Specification: AWS Data Processing Pipeline

## What is this project?
This project is an event-driven data processing pipeline deployed on Amazon Web Services (AWS). It is designed to automatically ingest, process, and perform machine learning inference on data as soon as it is uploaded to a storage bucket. The pipeline consists of a series of decoupled serverless functions that pass structured messages to one another to coordinate the processing workflow.

## Why is this project being built?
### 1. Automation & Responsiveness
By leveraging event-driven triggers (EventBridge capturing S3 events), the system reacts immediately to new data without the need for manual intervention or scheduled batch jobs.

### 2. Scalability & Cost Efficiency
The pipeline uses AWS Lambda (serverless compute), meaning it automatically scales out to handle sudden spikes in data volume and scales in to zero when there is no data to process. This ensures we only pay for the exact compute time used.

### 3. Decoupled Resilience
Instead of a single monolithic application, the processing is broken down into discrete steps separated by message queues (SNS & SQS). This architectural choice provides several benefits:
- **Fault Tolerance**: If a downstream service (like SageMaker) is temporarily unavailable or slow, messages are safely held in SQS queues, preventing data loss.
- **Independent Scaling**: Each Lambda function can scale independently based on the depth of its respective queue.
- **Maintainability**: Individual components can be updated or replaced without affecting the entire pipeline.
- **Strong Typing**: Using Protobuf for message definitions ensures that all decoupled services agree on the exact structure of the data being passed between them, preventing runtime serialization errors.

### 4. Machine Learning Integration
The ultimate goal of the pipeline is to prepare data for and invoke an AWS SageMaker endpoint. By orchestrating this via lambdas and queues, we create a robust wrapper around ML model inference that can handle high throughput reliably.
