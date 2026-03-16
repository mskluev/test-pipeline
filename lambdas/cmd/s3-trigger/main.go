package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-lambda-go/lambdacontext"
	pb "github.com/mskluev/test-pipeline/lambdas/pkg/proto/events/v1"
	"google.golang.org/protobuf/encoding/protojson"
)

func HandleRequest(ctx context.Context, event interface{}) (json.RawMessage, error) {
	if lc, ok := lambdacontext.FromContext(ctx); ok {
		fmt.Printf("Lambda Context: %+v\n", lc)
	}

	eventBytes, err := json.MarshalIndent(event, "", "  ")
	if err == nil {
		fmt.Printf("s3-trigger received event:\n%s\n", string(eventBytes))
	} else {
		fmt.Printf("s3-trigger received event: %#v\n", event)
	}

	// Initialize correlation_id (e.g., from AWS Request ID)
	correlationID := "generated-uuid-placeholder"
	if lc, ok := lambdacontext.FromContext(ctx); ok {
		correlationID = lc.AwsRequestID
	}

	// Simulate passing the correlation_id through to the next event
	nextEvent := &pb.ProcessingEvent{
		CorrelationId: correlationID,
	}
	fmt.Printf("Passing correlation_id %s through to next stage via ProcessingEvent\n", nextEvent.CorrelationId)

	b, err := protojson.Marshal(nextEvent)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal nextEvent: %w", err)
	}

	return json.RawMessage(b), nil
}

func main() {
	lambda.Start(HandleRequest)
}
