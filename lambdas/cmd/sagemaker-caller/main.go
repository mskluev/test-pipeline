package main

import (
	"context"
	"fmt"
	"github.com/aws/aws-lambda-go/lambda"
)

func HandleRequest(ctx context.Context, event interface{}) (string, error) {
	fmt.Printf("sagemaker-caller received event: %v\n", event)
	return "Success", nil
}

func main() {
	lambda.Start(HandleRequest)
}
