.PHONY: all build clean generate tf-init tf-plan tf-deploy tf-destroy

LAMBDAS := s3-trigger processor sagemaker-caller

all: generate build

generate:
	@echo "Generating protobufs..."
	cd proto && buf generate

build: $(LAMBDAS)

$(LAMBDAS):
	@echo "Building $@..."
	cd lambdas && GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -tags lambda.norpc -o bin/$@/bootstrap cmd/$@/main.go

clean:
	@echo "Cleaning up..."
	rm -rf lambdas/bin
	rm -f terraform/*.zip

tf-init:
	@echo "Initializing Terraform..."
	cd terraform && terraform init

tf-plan: build tf-init
	@echo "Running Terraform Plan..."
	cd terraform && terraform plan

tf-deploy: build tf-init
	@echo "Deploying Infrastructure..."
	cd terraform && terraform apply -auto-approve

tf-destroy:
	@echo "Destroying Infrastructure..."
	cd terraform && terraform destroy -auto-approve
