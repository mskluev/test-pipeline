package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"

	"github.com/aws/aws-lambda-go/events"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-lambda-go/lambdacontext"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/sagemakerruntime"
	pb "github.com/mskluev/test-pipeline/lambdas/pkg/proto/events/v1"
	"google.golang.org/protobuf/encoding/protojson"
)

var (
	smClient     *sagemakerruntime.Client
	endpointName string
)

func init() {
	endpointName = os.Getenv("SAGEMAKER_ENDPOINT_NAME")
	if endpointName == "" {
		log.Fatalf("SAGEMAKER_ENDPOINT_NAME environment variable is not set")
	}

	cfg, err := config.LoadDefaultConfig(context.Background())
	if err != nil {
		log.Fatalf("unable to load SDK config, %v", err)
	}

	smClient = sagemakerruntime.NewFromConfig(cfg)
}

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

		correlationID := sageMakerEvent.CorrelationId
		fmt.Printf("Successfully unmarshaled SageMakerEvent with correlation_id: %s\n", correlationID)

		if sageMakerEvent.PayloadUri == "" {
			fmt.Printf("Error: PayloadUri is empty for correlation_id %s. Skipping inference.\n", correlationID)
			continue
		}

		fmt.Printf("Executing SageMaker async inference for correlation_id: %s using payload URI: %s and endpoint: %s\n", correlationID, sageMakerEvent.PayloadUri, endpointName)

		inputLocation := sageMakerEvent.PayloadUri
		input := &sagemakerruntime.InvokeEndpointAsyncInput{
			EndpointName:  &endpointName,
			InputLocation: &inputLocation,
		}

		output, err := smClient.InvokeEndpointAsync(ctx, input)
		if err != nil {
			fmt.Printf("Failed to invoke SageMaker async endpoint for correlation_id %s: %v\n", correlationID, err)
			return "", fmt.Errorf("failed to invoke endpoint: %w", err)
		}

		if output.OutputLocation != nil {
			fmt.Printf("Successfully triggered async inference. Expected output location: %s\n", *output.OutputLocation)
		} else {
			fmt.Printf("Successfully triggered async inference. Output location unknown.\n")
		}
	}

	return "Success", nil
}

func main() {
	lambda.Start(HandleRequest)
}
