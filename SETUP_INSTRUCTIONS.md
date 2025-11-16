# Initial Setup Instructions

The GitHub Actions workflow is currently disabled because the AWS infrastructure needs to be deployed first. Follow these steps in order:

## Step 1: Deploy Infrastructure Locally

### 1.1 Configure AWS CLI
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Enter your default region (e.g., us-east-1)
```

### 1.2 Create Terraform Backend
```bash
./scripts/setup-backend.sh YOUR-UNIQUE-BUCKET-NAME us-east-1
```

### 1.3 Configure Terraform Variables
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit terraform.tfvars with your values:
```hcl
aws_region   = "us-east-1"
project_name = "ecs-microservices"
environment  = "production"
alarm_email  = "your-email@example.com"
github_repo  = "Copubah/ecs-fargate-microservices"
```

Update backend.tf with your bucket name:
```hcl
bucket = "YOUR-UNIQUE-BUCKET-NAME"
```

### 1.4 Deploy Infrastructure
```bash
terraform init
terraform plan
terraform apply
```

This will create:
- VPC with public/private subnets
- ALB with WAF
- ECS Fargate cluster
- ECR repositories
- IAM roles (including GitHub Actions OIDC role)
- CloudWatch monitoring

### 1.5 Build and Push Initial Images
```bash
cd ..
./scripts/push-images.sh
```

### 1.6 Update ECS Services
```bash
cd terraform
terraform apply
```

## Step 2: Configure GitHub Secrets

After infrastructure is deployed, add these secrets to your GitHub repository:

Go to: https://github.com/Copubah/ecs-fargate-microservices/settings/secrets/actions

Add:
- Name: AWS_ACCOUNT_ID
  Value: Your AWS account ID (get with: aws sts get-caller-identity --query Account --output text)

- Name: AWS_REGION
  Value: us-east-1 (or your region)

## Step 3: Enable GitHub Actions Workflow

After secrets are configured:

```bash
# Rename the workflow file to enable it
mv .github/workflows/deploy.yml.disabled .github/workflows/deploy.yml

# Commit and push
git add .github/workflows/deploy.yml
git rm .github/workflows/deploy.yml.disabled
git commit -m "Enable GitHub Actions workflow after infrastructure deployment"
git push origin main
```

## Step 4: Verify Deployment

Test your services:
```bash
./scripts/test-services.sh
```

Or manually:
```bash
ALB_DNS=$(cd terraform && terraform output -raw alb_dns_name)
curl http://$ALB_DNS/api/hello
curl http://$ALB_DNS/api/backend
```

## Troubleshooting

### Issue: "Could not assume role with OIDC"
This means the infrastructure hasn't been deployed yet. Complete Step 1 first.

### Issue: "Bucket already exists"
Choose a different, globally unique bucket name in Step 1.2.

### Issue: "Tasks not starting"
Check CloudWatch logs:
```bash
aws logs tail /ecs/ecs-microservices-service-a --follow
```

### Issue: "Cannot access ALB"
Wait 2-3 minutes for health checks to pass, then try again.

## Summary

The correct order is:
1. Deploy infrastructure with Terraform (locally)
2. Push Docker images to ECR
3. Configure GitHub secrets
4. Enable GitHub Actions workflow
5. Future pushes will trigger automated deployments

This ensures the IAM role and infrastructure exist before GitHub Actions tries to use them.
