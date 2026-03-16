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

type LambdaDestinationEnvelope struct {
	Version         string          `json:"version"`
	Timestamp       string          `json:"timestamp"`
	ResponsePayload json.RawMessage `json:"responsePayload"`
}

func HandleRequest(ctx context.Context, records []events.SQSMessage) ([]json.RawMessage, error) {
	if lc, ok := lambdacontext.FromContext(ctx); ok {
		fmt.Printf("Lambda Context: %+v\n", lc)
	}

	eventBytes, err := json.MarshalIndent(records, "", "  ")
	if err == nil {
		fmt.Printf("processor received records:\n%s\n", string(eventBytes))
	} else {
		fmt.Printf("processor received records: %#v\n", records)
	}

	var results []json.RawMessage

	for _, record := range records {
		var snsEntity events.SNSEntity
		if err := json.Unmarshal([]byte(record.Body), &snsEntity); err != nil {
			fmt.Printf("Failed to unmarshal SNS entity: %v\n", err)
			continue
		}

		var envelope LambdaDestinationEnvelope
		if err := json.Unmarshal([]byte(snsEntity.Message), &envelope); err != nil {
			fmt.Printf("Failed to unmarshal Lambda Destination envelope: %v\n", err)
			continue
		}

		var processingEvent pb.ProcessingEvent
		if err := protojson.Unmarshal(envelope.ResponsePayload, &processingEvent); err != nil {
			fmt.Printf("Failed to unmarshal ProcessingEvent from payload: %v\n", err)
			// Fallback: perhaps it wasn't wrapped in a destination env?
			if errFallback := protojson.Unmarshal([]byte(snsEntity.Message), &processingEvent); errFallback != nil {
				continue
			}
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
		if err == nil {
			results = append(results, json.RawMessage(b))
		}
	}

	return results, nil
}

func main() {
	lambda.Start(HandleRequest)
}
