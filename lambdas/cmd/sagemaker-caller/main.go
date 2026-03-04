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
		fmt.Printf("sagemaker-caller received event:\n%s\n", string(eventBytes))
	} else {
		fmt.Printf("sagemaker-caller received event: %#v\n", event)
	}

	correlationID := "unknown"
	for _, record := range event.Records {
		var snsEntity events.SNSEntity
		if err := json.Unmarshal([]byte(record.Body), &snsEntity); err != nil {
			fmt.Printf("Failed to unmarshal SNS entity: %v\n", err)
			continue
		}

		var sageMakerEvent pb.SageMakerEvent
		if err := protojson.Unmarshal([]byte(snsEntity.Message), &sageMakerEvent); err != nil {
			fmt.Printf("Failed to unmarshal SageMakerEvent: %v\n", err)
			continue
		}

		if sageMakerEvent.CorrelationId != "" {
			correlationID = sageMakerEvent.CorrelationId
		}

		fmt.Printf("Successfully unmarshaled SageMakerEvent with correlation_id: %s\n", correlationID)
	}

	fmt.Printf("Executing SageMaker inference for correlation_id: %s\n", correlationID)

	return "Success", nil
}

func main() {
	lambda.Start(HandleRequest)
}
