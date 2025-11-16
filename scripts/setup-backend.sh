#!/bin/bash
set -e

# Configuration
BUCKET_NAME=${1:-"your-terraform-state-bucket"}
TABLE_NAME="terraform-state-lock"
AWS_REGION=${2:-"us-east-1"}

echo "Setting up Terraform backend..."
echo "Bucket: $BUCKET_NAME"
echo "Region: $AWS_REGION"

# Create S3 bucket
echo "Creating S3 bucket..."
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $AWS_REGION \
  --create-bucket-configuration LocationConstraint=$AWS_REGION 2>/dev/null || \
  aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region us-east-1 2>/dev/null || \
  echo "Bucket already exists"

# Enable versioning
echo "Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Enable encryption
echo "Enabling encryption..."
aws s3api put-bucket-encryption \
  --bucket $BUCKET_NAME \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

# Block public access
echo "Blocking public access..."
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Create DynamoDB table
echo "Creating DynamoDB table..."
aws dynamodb create-table \
  --table-name $TABLE_NAME \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region $AWS_REGION 2>/dev/null || \
  echo "Table already exists"

echo ""
echo "Backend setup complete!"
echo ""
echo "Update terraform/backend.tf with:"
echo "  bucket = \"$BUCKET_NAME\""
echo "  region = \"$AWS_REGION\""
