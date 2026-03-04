package main

import (
	"context"
	"encoding/json"
	"fmt"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-lambda-go/lambdacontext"
	pb "github.com/mskluev/test-pipeline/lambdas/pkg/proto/events/v1"
	"google.golang.org/protobuf/encoding/protojson"
)

func HandleRequest(ctx context.Context, event events.SQSEvent) (string, error) {
	if lc, ok := lambdacontext.FromContext(ctx); ok {
		fmt.Printf("Lambda Context: %+v\n", lc)
	}

	eventBytes, err := json.MarshalIndent(event, "", "  ")
	if err == nil {
		fmt.Printf("processor received event:\n%s\n", string(eventBytes))
	} else {
		fmt.Printf("processor received event: %#v\n", event)
	}

	correlationID := "unknown"
	for _, record := range event.Records {
		var snsEntity events.SNSEntity
		if err := json.Unmarshal([]byte(record.Body), &snsEntity); err != nil {
			fmt.Printf("Failed to unmarshal SNS entity: %v\n", err)
			continue
		}

		var processingEvent pb.ProcessingEvent
		if err := protojson.Unmarshal([]byte(snsEntity.Message), &processingEvent); err != nil {
			fmt.Printf("Failed to unmarshal ProcessingEvent: %v\n", err)
			continue
		}

		if processingEvent.CorrelationId != "" {
			correlationID = processingEvent.CorrelationId
		}

		fmt.Printf("Successfully unmarshaled ProcessingEvent with correlation_id: %s\n", correlationID)
	}

	// Simulate passing the correlation_id through to the next event
	nextEvent := &pb.SageMakerEvent{
		CorrelationId: correlationID,
	}
	fmt.Printf("Passing correlation_id %s through to SageMaker stage via SageMakerEvent\n", nextEvent.CorrelationId)

	return "Success", nil
}

func main() {
	lambda.Start(HandleRequest)
}
