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

func HandleRequest(ctx context.Context, event events.EventBridgeEvent) error {
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

	// Parse the S3 Event details
	var s3Detail struct {
		Bucket struct {
			Name string `json:"name"`
		} `json:"bucket"`
		Object struct {
			Key string `json:"key"`
		} `json:"object"`
	}

	if err := json.Unmarshal(event.Detail, &s3Detail); err != nil {
		fmt.Printf("Failed to unmarshal S3 detail: %v\n", err)
	}

	s3Uri := fmt.Sprintf("s3://%s/%s", s3Detail.Bucket.Name, s3Detail.Object.Key)

	// Simulate passing the correlation_id through to the next event
	nextEvent := &pb.ProcessingEvent{
		CorrelationId: correlationID,
		S3Uri:         s3Uri,
	}
	fmt.Printf("Passing correlation_id %s and s3_uri %s through to next stage via ProcessingEvent\n", nextEvent.CorrelationId, nextEvent.S3Uri)

	b, err := protojson.Marshal(nextEvent)
	if err != nil {
		return fmt.Errorf("failed to marshal nextEvent: %w", err)
	}

	topicArn := os.Getenv("PROCESS_TOPIC_ARN")
	if topicArn == "" {
		return fmt.Errorf("PROCESS_TOPIC_ARN environment variable not set")
	}

	msg := string(b)
	_, err = snsClient.Publish(ctx, &sns.PublishInput{
		Message:  &msg,
		TopicArn: &topicArn,
	})
	if err != nil {
		return fmt.Errorf("failed to publish to SNS: %w", err)
	}
	fmt.Printf("Successfully published ProcessingEvent to %s\n", topicArn)

	return nil
}

func main() {
	lambda.Start(HandleRequest)
}

