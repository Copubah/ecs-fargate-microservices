#!/bin/bash
set -e

# Get ECR URLs from Terraform output
cd terraform
SERVICE_A_REPO=$(terraform output -raw ecr_repository_urls | jq -r '.["service-a"]')
SERVICE_B_REPO=$(terraform output -raw ecr_repository_urls | jq -r '.["service-b"]')
AWS_REGION=$(terraform output -raw vpc_id | cut -d':' -f4)
cd ..

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin ${SERVICE_A_REPO%%/*}

# Build and push Service A
echo "Building and pushing Service A..."
docker build -t service-a:latest services/service-a
docker tag service-a:latest $SERVICE_A_REPO:latest
docker push $SERVICE_A_REPO:latest

# Build and push Service B
echo "Building and pushing Service B..."
docker build -t service-b:latest services/service-b
docker tag service-b:latest $SERVICE_B_REPO:latest
docker push $SERVICE_B_REPO:latest

echo "Images pushed successfully!"
