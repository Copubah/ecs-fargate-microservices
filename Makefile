.
PHONY: help init plan apply destroy test clean

help:
	@echo "ECS Microservices Makefile"
	@echo ""
	@echo "Available targets:"
	@echo "  init        - Initialize Terraform"
	@echo "  plan        - Run Terraform plan"
	@echo "  apply       - Apply Terraform changes"
	@echo "  destroy     - Destroy all infrastructure"
	@echo "  test        - Test deployed services"
	@echo "  logs-a      - Tail Service A logs"
	@echo "  logs-b      - Tail Service B logs"
	@echo "  build       - Build Docker images locally"
	@echo "  push        - Push images to ECR"
	@echo "  clean       - Clean local artifacts"

init:
	cd terraform && terraform init

plan:
	cd terraform && terraform plan

apply:
	cd terraform && terraform apply

destroy:
	cd terraform && terraform destroy

test:
	@echo "Testing Service A..."
	@curl -s http://$$(cd terraform && terraform output -raw alb_dns_name)/api/hello | jq
	@echo ""
	@echo "Testing Service B via Service A..."
	@curl -s http://$$(cd terraform && terraform output -raw alb_dns_name)/api/backend | jq

logs-a:
	aws logs tail /ecs/ecs-microservices-service-a --follow

logs-b:
	aws logs tail /ecs/ecs-microservices-service-b --follow

build:
	docker build -t service-a:latest services/service-a
	docker build -t service-b:latest services/service-b

push:
	@echo "Pushing images to ECR..."
	@./scripts/push-images.sh

clean:
	rm -rf terraform/.terraform
	rm -f terraform/terraform.tfstate*
	rm -f terraform/.terraform.lock.hcl
