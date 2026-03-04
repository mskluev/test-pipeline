package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-lambda-go/lambdacontext"
)

func HandleRequest(ctx context.Context, event interface{}) (string, error) {
	if lc, ok := lambdacontext.FromContext(ctx); ok {
		fmt.Printf("Lambda Context: %+v\n", lc)
	}

	eventBytes, err := json.MarshalIndent(event, "", "  ")
	if err == nil {
		fmt.Printf("sagemaker-caller received event:\n%s\n", string(eventBytes))
	} else {
		fmt.Printf("sagemaker-caller received event: %#v\n", event)
	}

	return "Success", nil
}

func main() {
	lambda.Start(HandleRequest)
}
