package main

import (
	"context"
	"encoding/json"
	"fmt"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-lambda-go/lambdacontext"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sns"
	pb "github.com/mskluev/test-pipeline/lambdas/pkg/proto/events/v1"
	"google.golang.org/protobuf/encoding/protojson"
)

var snsClient *sns.Client

func init() {
	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		fmt.Printf("failed to load AWS config: %v\n", err)
	} else {
		snsClient = sns.NewFromConfig(cfg)
	}
}

func HandleRequest(ctx context.Context, event events.SQSEvent) error {
	if lc, ok := lambdacontext.FromContext(ctx); ok {
		fmt.Printf("Lambda Context: %+v\n", lc)
	}

	eventBytes, err := json.MarshalIndent(event, "", "  ")
	if err == nil {
		fmt.Printf("processor received records:\n%s\n", string(eventBytes))
	} else {
		fmt.Printf("processor received records: %#v\n", event)
	}

	topicArn := os.Getenv("SAGEMAKER_TOPIC_ARN")
	if topicArn == "" {
		return fmt.Errorf("SAGEMAKER_TOPIC_ARN environment variable not set")
	}

	for _, record := range event.Records {
		var snsEntity events.SNSEntity
		if err := json.Unmarshal([]byte(record.Body), &snsEntity); err != nil {
			fmt.Printf("Failed to unmarshal SNS entity: %v\n", err)
			continue
		}

		var processingEvent pb.ProcessingEvent
		if err := protojson.Unmarshal([]byte(snsEntity.Message), &processingEvent); err != nil {
			fmt.Printf("Failed to unmarshal ProcessingEvent from payload: %v\n", err)
			continue
		}

		correlationID := "unknown"
		if processingEvent.CorrelationId != "" {
			correlationID = processingEvent.CorrelationId
		}

		fmt.Printf("Successfully unmarshaled ProcessingEvent with correlation_id: %s\n", correlationID)

		// Simulate passing the correlation_id through to the next event
		nextEvent := &pb.SageMakerEvent{
			CorrelationId: correlationID,
		}
		fmt.Printf("Passing correlation_id %s through to SageMaker stage via SageMakerEvent\n", nextEvent.CorrelationId)

		b, err := protojson.Marshal(nextEvent)
		if err != nil {
			fmt.Printf("Failed to marshal SageMakerEvent: %v\n", err)
			continue
		}

		msg := string(b)
		_, err = snsClient.Publish(ctx, &sns.PublishInput{
			Message:  &msg,
			TopicArn: &topicArn,
		})
		if err != nil {
			return fmt.Errorf("failed to publish to SNS: %w", err)
		}
		fmt.Printf("Successfully published SageMakerEvent to %s\n", topicArn)
	}

	return nil
}

func main() {
	lambda.Start(HandleRequest)
}

