# ECS Fargate Microservices Architecture

Complete production-ready microservices platform on AWS using ECS Fargate, Terraform, and GitHub Actions.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Deployment Guide](#deployment-guide)
6. [Configuration](#configuration)
7. [Services](#services)
8. [CI/CD Pipeline](#cicd-pipeline)
9. [Monitoring](#monitoring)
10. [Security](#security)
11. [Cost Estimation](#cost-estimation)
12. [Troubleshooting](#troubleshooting)
13. [Command Reference](#command-reference)

## Important Notes

- GitHub Actions workflow is disabled by default (deploy.yml.disabled)
- You must deploy infrastructure locally first before enabling CI/CD
- See SETUP_INSTRUCTIONS.md for detailed first-time deployment steps
- After initial setup, GitHub Actions will handle automated deployments

## Overview

This project implements a production-ready microservices architecture on AWS with:

- Two microservices running on ECS Fargate
- Application Load Balancer for traffic routing
- Private subnets for security
- Auto-scaling based on CPU and memory
- Complete monitoring and alerting
- Automated CI/CD pipeline
- Infrastructure as Code with Terraform

### Key Features

- Multi-AZ high availability (2 availability zones)
- Auto-scaling (1-10 tasks per service)
- Load balancing with health checks
- Container orchestration with ECS Fargate
- Container registry with vulnerability scanning
- Infrastructure as Code (Terraform)
- CI/CD with GitHub Actions (OIDC authentication)
- CloudWatch monitoring and alerting
- AWS WAF for security
- Service discovery with AWS Cloud Map
- Encrypted logs and data at rest

### Project Statistics

- Total Files: 48
- Terraform Modules: 6
- AWS Resources: 40+
- Microservices: 2
- CloudWatch Alarms: 8
- Lines of Code: ~1,800


## Architecture

### High-Level Architecture

```
Internet
   |
   v
AWS WAF (Rate limiting, DDoS protection)
   |
   v
Application Load Balancer (Public Subnets)
   |
   +------------------+------------------+
   |                                     |
   v                                     v
ECS Service A                      ECS Service B
(API Gateway)                      (Backend)
Private Subnet                     Private Subnet
   |                                     |
   +------------------+------------------+
                      |
                      v
              NAT Gateway (Public Subnet)
                      |
                      v
              Internet Gateway
                      |
                      v
         AWS Services (ECR, CloudWatch, Secrets Manager)
```

### Network Architecture

VPC: 10.0.0.0/16

Availability Zone A:
- Public Subnet: 10.0.1.0/24 (ALB, NAT Gateway)
- Private Subnet: 10.0.11.0/24 (ECS Tasks)

Availability Zone B:
- Public Subnet: 10.0.2.0/24 (ALB, NAT Gateway)
- Private Subnet: 10.0.12.0/24 (ECS Tasks)

### Components

- VPC: Multi-AZ VPC with public and private subnets
- ALB: Application Load Balancer with WAF protection
- ECS: Fargate cluster with Container Insights
- ECR: Container registry with image scanning
- CloudWatch: Monitoring, logging, and alerting
- IAM: Roles and policies with least privilege
- NAT Gateway: Outbound internet access for private subnets
- Service Discovery: AWS Cloud Map for service-to-service communication

### Request Flow

1. User sends HTTP request to ALB
2. AWS WAF checks rate limits and security rules
3. ALB routes to appropriate target group
4. ECS task processes request
5. Service A can call Service B via service discovery
6. Response returns through ALB to user

### Service Communication

Service A (port 8000) can communicate with Service B (port 8001) using:
- Internal DNS: service-b.local:8001
- AWS Cloud Map service discovery
- Private network within VPC


## Prerequisites

Before you begin, ensure you have:

- AWS Account with administrative access
- AWS CLI installed and configured
- Terraform >= 1.5.0 installed
- Docker installed
- Git installed
- GitHub account (for CI/CD)

Verify installations:

```bash
aws --version
terraform --version
docker --version
git --version
```

Configure AWS CLI:

```bash
aws configure
```

## Quick Start

IMPORTANT: For first-time deployment, you must deploy infrastructure locally before enabling GitHub Actions. See SETUP_INSTRUCTIONS.md for detailed guidance.

### Initial Deployment (First Time Only)

#### Step 1: Setup Backend (2 minutes)

Create S3 bucket and DynamoDB table for Terraform state:

```bash
./scripts/setup-backend.sh my-terraform-state-bucket us-east-1
```

Or manually:

```bash
aws s3api create-bucket \
  --bucket your-terraform-state-bucket \
  --region us-east-1

aws dynamodb create-table \
  --table-name terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

#### Step 2: Configure Variables (2 minutes)

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit terraform.tfvars with your values:

```hcl
aws_region   = "us-east-1"
project_name = "ecs-microservices"
environment  = "production"

vpc_cidr             = "10.0.0.0/16"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["10.0.1.0/24", "10.0.2.0/24"]
private_subnet_cidrs = ["10.0.11.0/24", "10.0.12.0/24"]

service_a_cpu    = 256
service_a_memory = 512
service_b_cpu    = 256
service_b_memory = 512

enable_waf  = true
alarm_email = "your-email@example.com"
github_repo = "Copubah/ecs-fargate-microservices"
```

Also update backend.tf with your bucket name:

```hcl
bucket = "my-terraform-state-bucket"
```

#### Step 3: Deploy Infrastructure (8 minutes)

```bash
terraform init
terraform plan
terraform apply
```

Save outputs:

```bash
terraform output > ../outputs.txt
cd ..
```

#### Step 4: Build and Push Images (3 minutes)

```bash
./scripts/push-images.sh
```

Or manually:

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# Build and push Service A
docker build -t service-a:latest services/service-a
docker tag service-a:latest ECR_URL/service-a:latest
docker push ECR_URL/service-a:latest

# Build and push Service B
docker build -t service-b:latest services/service-b
docker tag service-b:latest ECR_URL/service-b:latest
docker push ECR_URL/service-b:latest
```

#### Step 5: Test Deployment (1 minute)

```bash
./scripts/test-services.sh
```

Or manually:

```bash
ALB_DNS=$(cd terraform && terraform output -raw alb_dns_name)
curl http://$ALB_DNS/api/hello
curl http://$ALB_DNS/api/info
curl http://$ALB_DNS/api/backend
```

#### Step 6: Enable GitHub Actions (Optional)

After infrastructure is deployed, enable automated deployments:

1. Add GitHub secrets:
   - Go to: https://github.com/Copubah/ecs-fargate-microservices/settings/secrets/actions
   - Add AWS_ACCOUNT_ID (get with: aws sts get-caller-identity --query Account --output text)
   - Add AWS_REGION (e.g., us-east-1)

2. Enable the workflow:
```bash
mv .github/workflows/deploy.yml.disabled .github/workflows/deploy.yml
git add .github/workflows/deploy.yml
git rm .github/workflows/deploy.yml.disabled
git commit -m "Enable GitHub Actions workflow"
git push origin main
```

Future deployments will happen automatically when you push to main branch.


## Deployment Guide

### Initial Setup

1. Clone repository
2. Create Terraform backend (S3 + DynamoDB)
3. Configure terraform.tfvars
4. Update backend.tf with your bucket name

### Infrastructure Deployment

```bash
cd terraform

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Apply infrastructure
terraform apply

# View outputs
terraform output
```

### Container Deployment

```bash
# Get ECR repository URLs
cd terraform
SERVICE_A_REPO=$(terraform output -raw ecr_repository_urls | jq -r '.["service-a"]')
SERVICE_B_REPO=$(terraform output -raw ecr_repository_urls | jq -r '.["service-b"]')

# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin ${SERVICE_A_REPO%%/*}

# Build and push images
cd ..
docker build -t service-a:latest services/service-a
docker tag service-a:latest $SERVICE_A_REPO:latest
docker push $SERVICE_A_REPO:latest

docker build -t service-b:latest services/service-b
docker tag service-b:latest $SERVICE_B_REPO:latest
docker push $SERVICE_B_REPO:latest

# Update ECS services
cd terraform
terraform apply
```

### GitHub Actions Setup

1. Add GitHub secrets:
   - AWS_ACCOUNT_ID: Your AWS account ID
   - AWS_REGION: Your AWS region

2. Get GitHub Actions role ARN:
```bash
cd terraform
terraform output github_actions_role_arn
```

3. Push to GitHub to trigger deployment:
```bash
git add .
git commit -m "Initial deployment"
git push origin main
```

### Verification

Check ECS services:
```bash
aws ecs describe-services \
  --cluster ecs-microservices-production-cluster \
  --services ecs-microservices-service-a ecs-microservices-service-b
```

View logs:
```bash
aws logs tail /ecs/ecs-microservices-service-a --follow
aws logs tail /ecs/ecs-microservices-service-b --follow
```

Check target health:
```bash
aws elbv2 describe-target-health \
  --target-group-arn TARGET_GROUP_ARN
```

### Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

Note: Manually delete ECR images first if repositories are not empty.


## Configuration

### Terraform Variables

Key variables in terraform.tfvars:

- aws_region: AWS region for deployment
- project_name: Project identifier
- environment: Environment name (production, dev, etc.)
- vpc_cidr: VPC CIDR block
- availability_zones: List of AZs to use
- public_subnet_cidrs: CIDR blocks for public subnets
- private_subnet_cidrs: CIDR blocks for private subnets
- service_a_cpu: CPU units for Service A (256 = 0.25 vCPU)
- service_a_memory: Memory for Service A in MB
- service_b_cpu: CPU units for Service B
- service_b_memory: Memory for Service B in MB
- enable_waf: Enable AWS WAF on ALB
- alarm_email: Email for CloudWatch alarms
- github_repo: GitHub repository for OIDC (owner/repo)

### Backend Configuration

Update terraform/backend.tf:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "ecs-microservices/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

### Task Sizing

CPU and memory combinations for Fargate:

| CPU (vCPU) | Memory (GB) |
|------------|-------------|
| 0.25       | 0.5, 1, 2   |
| 0.5        | 1, 2, 3, 4  |
| 1          | 2, 3, 4, 5, 6, 7, 8 |
| 2          | 4-16 (1 GB increments) |
| 4          | 8-30 (1 GB increments) |

### Auto Scaling

Default configuration:
- Min tasks: 1
- Max tasks: 10
- CPU target: 70%
- Memory target: 70%

Modify in terraform/modules/ecs/main.tf

### Environment Variables

Service A environment variables:
- SERVICE_B_URL: URL for Service B (http://service-b.local:8001)

Add more in task definition:

```hcl
environment = [
  {
    name  = "ENV_VAR_NAME"
    value = "value"
  }
]
```

### Secrets

Use AWS Secrets Manager:

```hcl
secrets = [
  {
    name      = "DB_PASSWORD"
    valueFrom = "arn:aws:secretsmanager:region:account:secret:name"
  }
]
```


## Services

### Service A (API Gateway)

Port: 8000
Language: Python 3.11
Framework: FastAPI

Endpoints:
- GET /health - Health check for ALB
- GET /api/hello - Public API endpoint
- GET /api/info - Service information
- GET /api/backend - Calls Service B and returns response

Example responses:

```bash
# Health check
curl http://ALB_DNS/health
{"status":"healthy","service":"service-a"}

# Hello endpoint
curl http://ALB_DNS/api/hello
{"message":"Hello from Service A","timestamp":"2024-01-01T00:00:00","service":"service-a"}

# Info endpoint
curl http://ALB_DNS/api/info
{"service":"service-a","version":"1.0.0","description":"API Gateway Service"}

# Backend call
curl http://ALB_DNS/api/backend
{"service_a":"success","service_b_response":{...},"timestamp":"2024-01-01T00:00:00"}
```

### Service B (Backend)

Port: 8001
Language: Python 3.11
Framework: FastAPI

Endpoints:
- GET /health - Health check
- GET /process - Backend processing endpoint
- GET /internal/status - Internal status

Example responses:

```bash
# Health check
curl http://service-b.local:8001/health
{"status":"healthy","service":"service-b"}

# Process endpoint
curl http://service-b.local:8001/process
{"service":"service-b","status":"processed","processing_time":"0.25s"}

# Internal status
curl http://service-b.local:8001/internal/status
{"service":"service-b","version":"1.0.0","status":"running"}
```

### Adding New Services

1. Create service directory in services/
2. Add Dockerfile and application code
3. Create ECR repository in terraform/modules/ecr/
4. Add task definition in terraform/modules/ecs/
5. Create ECS service
6. Add target group and listener rules in terraform/modules/alb/
7. Update monitoring in terraform/modules/monitoring/

### Service Discovery

Services communicate using AWS Cloud Map:
- Service B is registered as service-b.local
- Service A resolves this DNS name within VPC
- No need for hardcoded IPs or external service discovery


## CI/CD Pipeline

### GitHub Actions Workflow

Location: .github/workflows/deploy.yml

Triggers:
- Push to main branch
- Pull requests to main branch

### Pipeline Steps

1. Checkout code
2. Configure AWS credentials (OIDC)
3. Login to Amazon ECR
4. Set up Docker Buildx
5. Build and push Service A image (with caching)
6. Build and push Service B image (with caching)
7. Scan images for vulnerabilities
8. Setup Terraform
9. Terraform init
10. Terraform plan
11. Terraform apply (main branch only)
12. Update ECS Service A
13. Update ECS Service B
14. Wait for service stability

### OIDC Configuration

No long-lived AWS credentials needed. Uses OpenID Connect:

1. GitHub Actions assumes IAM role
2. Role has permissions for ECR, ECS, Terraform
3. Temporary credentials issued per workflow run

Required GitHub secrets:
- AWS_ACCOUNT_ID
- AWS_REGION

### Docker Layer Caching

Uses GitHub Actions cache to speed up builds:
- Cache Docker layers between runs
- Significantly faster subsequent builds
- Automatic cache invalidation

### Image Scanning

ECR automatically scans images on push:
- Checks for known vulnerabilities (CVEs)
- Results available in AWS Console
- Can block deployments based on findings

View scan results:

```bash
aws ecr describe-image-scan-findings \
  --repository-name ecs-microservices-service-a \
  --image-id imageTag=latest
```

### Deployment Strategy

Rolling update:
- New task definition created
- New tasks started
- Health checks pass
- Old tasks drained and stopped
- Zero downtime deployment

### Branch Protection

Recommended GitHub branch protection rules:
- Require pull request reviews
- Require status checks to pass
- Require branches to be up to date
- Include administrators

### Manual Deployment

Force new deployment without code changes:

```bash
aws ecs update-service \
  --cluster ecs-microservices-production-cluster \
  --service ecs-microservices-service-a \
  --force-new-deployment
```

### Rollback

Rollback to previous task definition:

```bash
# List task definitions
aws ecs list-task-definitions \
  --family-prefix ecs-microservices-service-a

# Update service to previous version
aws ecs update-service \
  --cluster ecs-microservices-production-cluster \
  --service ecs-microservices-service-a \
  --task-definition ecs-microservices-service-a:PREVIOUS_VERSION
```


## Monitoring

### CloudWatch Container Insights

Enabled by default on ECS cluster. Provides:
- CPU utilization per service
- Memory utilization per service
- Network metrics
- Task count
- Container-level metrics

View in AWS Console:
CloudWatch > Container Insights > ECS Clusters

### CloudWatch Dashboard

Custom dashboard created by Terraform showing:
- Service A CPU and memory utilization
- Service B CPU and memory utilization
- ALB request count
- ALB response time
- ALB 5xx errors
- Healthy target count

Access dashboard:

```bash
cd terraform
terraform output cloudwatch_dashboard_url
```

### CloudWatch Alarms

8 alarms configured:

1. Service A High CPU (>80%)
2. Service A High Memory (>80%)
3. Service B High CPU (>80%)
4. Service B High Memory (>80%)
5. ALB 5xx Errors (>10 in 5 minutes)
6. Service A Unhealthy Targets (>0)
7. Service B Unhealthy Targets (>0)
8. Task Failures

All alarms send notifications to SNS topic.

### SNS Notifications

Configure email notifications:
1. Set alarm_email in terraform.tfvars
2. Apply Terraform
3. Confirm subscription email from AWS

### CloudWatch Logs

Log groups:
- /ecs/ecs-microservices-service-a
- /ecs/ecs-microservices-service-b

Features:
- 7-day retention
- KMS encryption
- Structured logging
- Log streams per task

View logs:

```bash
# Tail logs
aws logs tail /ecs/ecs-microservices-service-a --follow

# View last hour
aws logs tail /ecs/ecs-microservices-service-a --since 1h

# Filter logs
aws logs filter-log-events \
  --log-group-name /ecs/ecs-microservices-service-a \
  --filter-pattern "ERROR"
```

### Metrics

Key metrics to monitor:
- CPUUtilization (target: <70%)
- MemoryUtilization (target: <70%)
- TargetResponseTime (target: <500ms)
- RequestCount (track trends)
- HTTPCode_Target_5XX_Count (target: 0)
- HealthyHostCount (target: >=1)
- UnHealthyHostCount (target: 0)

### Custom Metrics

Add custom metrics in application code:

```python
import boto3

cloudwatch = boto3.client('cloudwatch')

cloudwatch.put_metric_data(
    Namespace='ECS/Microservices',
    MetricData=[
        {
            'MetricName': 'CustomMetric',
            'Value': 123,
            'Unit': 'Count'
        }
    ]
)
```

### Log Analysis

Use CloudWatch Logs Insights:

```sql
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20
```


## Security

### Network Security

Private Subnets:
- ECS tasks run in private subnets
- No public IP addresses
- No direct internet access
- Outbound traffic via NAT Gateway

Security Groups:
- ALB: Allow 80/443 from internet
- ECS: Allow 8000/8001 from ALB only
- Service-to-service: Allow 8001 within ECS security group

Network ACLs:
- Default allow within VPC
- Can add additional restrictions if needed

### IAM Security

Task Execution Role:
- Pull images from ECR
- Write logs to CloudWatch
- Access Secrets Manager

Task Role:
- Application-specific permissions
- Access to AWS services (S3, DynamoDB, etc.)
- Least privilege principle

GitHub Actions Role:
- OIDC federation (no long-lived credentials)
- Permissions for ECR, ECS, Terraform
- Scoped to specific GitHub repository

### Data Protection

Encryption at Rest:
- ECR images: AES256 encryption
- CloudWatch Logs: KMS encryption
- S3 Terraform state: Server-side encryption
- EBS volumes: Encrypted by default

Encryption in Transit:
- HTTPS for ALB (configure ACM certificate)
- TLS for service-to-service (optional)
- Encrypted connections to AWS services

### Application Security

AWS WAF:
- Rate limiting (2000 requests per 5 minutes per IP)
- Common attack protection (optional)
- SQL injection protection (optional)
- XSS protection (optional)

Container Security:
- Non-root user in containers
- Minimal base images (python:3.11-slim)
- Image scanning on push
- Regular dependency updates

Secrets Management:
- Use AWS Secrets Manager or SSM Parameter Store
- Never commit secrets to Git
- Rotate secrets regularly
- Use IAM for access control

### Security Best Practices

1. Enable HTTPS on ALB with ACM certificate
2. Use custom domain with Route 53
3. Enable CloudTrail for audit logging
4. Enable GuardDuty for threat detection
5. Use AWS Config for compliance
6. Implement VPC Flow Logs
7. Regular security audits
8. Keep dependencies updated
9. Use AWS Security Hub
10. Implement backup and disaster recovery

### Compliance

CIS AWS Foundations Benchmark:
- S3 bucket encryption enabled
- CloudWatch log encryption enabled
- Security groups restrict access
- IAM policies follow least privilege

For HIPAA/PCI DSS:
- Enable CloudTrail with log file validation
- Use customer-managed KMS keys
- Implement VPC Flow Logs
- Enable AWS Config
- Use AWS Security Hub

### Security Monitoring

Enable additional services:

CloudTrail:
```bash
aws cloudtrail create-trail \
  --name ecs-microservices-trail \
  --s3-bucket-name cloudtrail-bucket
```

GuardDuty:
```bash
aws guardduty create-detector --enable
```

Security Hub:
```bash
aws securityhub enable-security-hub
```

### Incident Response

1. Isolate: Update security groups to block traffic
2. Investigate: Review CloudWatch and CloudTrail logs
3. Contain: Stop affected tasks, rotate credentials
4. Remediate: Patch vulnerabilities, update configurations
5. Document: Record incident details and lessons learned


## Cost Estimation

### Monthly Cost Breakdown (us-east-1)

Production Environment (~$122/month):

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| ECS Fargate | 2 tasks, 0.25 vCPU, 0.5 GB | $18.03 |
| Application Load Balancer | 1 ALB, minimal traffic | $17.23 |
| NAT Gateway | 2 NAT Gateways (2 AZs) | $65.70 |
| NAT Gateway Data | ~50 GB outbound | $2.25 |
| ECR | 10 GB storage | $1.00 |
| CloudWatch Logs | 5 GB ingestion, 7-day retention | $2.65 |
| CloudWatch Metrics | 10 custom metrics | $3.00 |
| CloudWatch Alarms | 8 alarms | $0.80 |
| CloudWatch Dashboard | 1 dashboard | $3.00 |
| AWS WAF | 1 Web ACL, 1 rule | $6.00 |
| S3 | Terraform state | $0.10 |
| DynamoDB | State lock table | $0.10 |
| Data Transfer | 20 GB internet egress | $1.80 |
| Total | | $121.66 |

Development Environment (~$71/month):
- Single NAT Gateway: $32.85 (vs $65.70)
- Reduced logging: $1.50 (vs $2.65)
- WAF disabled: $0 (vs $6.00)
- Total: ~$71

Minimal Dev Environment (~$35-45/month):
- Single NAT Gateway
- Fargate Spot instances (70% discount)
- Scale to 0 during off-hours
- 3-day log retention

### Cost Optimization Strategies

1. Use Single NAT Gateway for Dev

Edit terraform/modules/vpc/main.tf:
```hcl
resource "aws_nat_gateway" "main" {
  count = var.environment == "production" ? length(var.availability_zones) : 1
}
```

2. Enable Fargate Spot

Edit terraform/modules/ecs/main.tf:
```hcl
capacity_provider_strategy {
  capacity_provider = "FARGATE_SPOT"
  weight           = 100
}
```
Savings: Up to 70% on compute costs

3. Scheduled Scaling

Scale down during off-hours:
```hcl
resource "aws_appautoscaling_scheduled_action" "scale_down" {
  name               = "scale-down-night"
  service_namespace  = "ecs"
  resource_id        = "service/cluster/service-a"
  scalable_dimension = "ecs:service:DesiredCount"
  schedule           = "cron(0 22 * * ? *)"
  
  scalable_target_action {
    min_capacity = 0
    max_capacity = 0
  }
}
```

4. Reduce Log Retention

For dev environments:
```hcl
resource "aws_cloudwatch_log_group" "service_a" {
  retention_in_days = 3  # vs 7 for production
}
```

5. VPC Endpoints

Reduce NAT Gateway data transfer:
```hcl
resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.ecr.api"
  vpc_endpoint_type = "Interface"
}
```
Cost: $7.20/month per endpoint
Break-even: If transferring >160 GB/month

6. Reserved Capacity

For predictable workloads:
- 1-year Fargate Savings Plan: 20% discount
- 3-year Fargate Savings Plan: 50% discount

### Cost Monitoring

Set up billing alarms:

```bash
aws cloudwatch put-metric-alarm \
  --alarm-name monthly-billing-alarm \
  --alarm-description "Alert when monthly costs exceed $150" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 21600 \
  --evaluation-periods 1 \
  --threshold 150 \
  --comparison-operator GreaterThanThreshold
```

Enable cost allocation tags in AWS Billing console.

Use AWS Cost Explorer to:
- Track daily costs
- Identify cost trends
- Compare month-over-month
- Filter by service or tag

### Scaling Cost Impact

Horizontal Scaling (more tasks):
- 2 tasks: $18/month
- 4 tasks: $36/month
- 10 tasks: $90/month

Vertical Scaling (larger tasks):
- 0.25 vCPU, 0.5 GB: $9/month per task
- 0.5 vCPU, 1 GB: $18/month per task
- 1 vCPU, 2 GB: $36/month per task

Traffic-Based Costs:
- Low (1M requests/month): ~$122/month
- Medium (10M requests/month): ~$160/month
- High (100M requests/month): ~$450-600/month


## Troubleshooting

### Tasks Not Starting

Symptoms:
- Tasks stuck in PENDING state
- Tasks start then immediately stop
- CannotPullContainerError

Solutions:

Check task stopped reason:
```bash
aws ecs describe-tasks \
  --cluster ecs-microservices-production-cluster \
  --tasks TASK_ID \
  --query 'tasks[0].stoppedReason'
```

Check CloudWatch logs:
```bash
aws logs tail /ecs/ecs-microservices-service-a --follow
```

Common fixes:
- Ensure ECR images exist and are tagged correctly
- Verify task execution role has ecr:GetAuthorizationToken
- Check VPC has NAT Gateway for private subnet internet access
- Verify security groups allow outbound HTTPS (443)

### Health Checks Failing

Symptoms:
- Targets showing unhealthy in target group
- Tasks continuously restarting
- 503 errors from ALB

Solutions:

Check target health:
```bash
aws elbv2 describe-target-health \
  --target-group-arn TARGET_GROUP_ARN
```

Verify security groups allow ALB to reach ECS tasks on ports 8000/8001

Test health endpoint directly from within VPC:
```bash
curl http://TASK_PRIVATE_IP:8000/health
```

Common fixes:
- Ensure health check path is /health
- Verify application starts within health check grace period (60s)
- Check security group rules
- Increase health check timeout if needed

### Cannot Access ALB

Symptoms:
- Timeout when accessing ALB DNS
- Connection refused

Solutions:

Check ALB state:
```bash
aws elbv2 describe-load-balancers \
  --names ecs-microservices-production-alb \
  --query 'LoadBalancers[0].State'
```

Verify security group allows inbound on port 80 from 0.0.0.0/0

Check target registration:
```bash
aws elbv2 describe-target-health \
  --target-group-arn TARGET_GROUP_ARN
```

Common fixes:
- Ensure ALB is in public subnets
- Verify internet gateway attached to VPC
- Check route table for public subnets has 0.0.0.0/0 to IGW
- Confirm at least one healthy target

### Service A Cannot Reach Service B

Symptoms:
- /api/backend endpoint returns 503
- Service B unavailable error

Solutions:

Check Service B health:
```bash
aws ecs describe-services \
  --cluster ecs-microservices-production-cluster \
  --services ecs-microservices-service-b
```

Verify service discovery:
```bash
aws servicediscovery list-services
aws servicediscovery discover-instances \
  --namespace-name local \
  --service-name service-b
```

Check security groups allow inbound on 8001 from ECS security group

Common fixes:
- Ensure Service B is running and healthy
- Verify Cloud Map namespace and service exist
- Check ECS security group allows self-referencing on port 8001
- Confirm SERVICE_B_URL environment variable is correct

### GitHub Actions Deployment Failing

Symptoms:
- Error: Could not assume role
- Access Denied errors
- Image push failures

Solutions:

Verify OIDC provider exists:
```bash
aws iam list-open-id-connect-providers
```

Check GitHub Actions role:
```bash
aws iam get-role \
  --role-name ecs-microservices-production-github-actions
```

Common fixes:
- Ensure GitHub repository name matches trust policy
- Verify AWS_ACCOUNT_ID and AWS_REGION secrets are set
- Check role has necessary permissions (ECR, ECS, IAM PassRole)
- Confirm OIDC thumbprint is correct

### High Costs

Symptoms:
- Unexpected AWS bill
- NAT Gateway data transfer charges

Solutions:

Check NAT Gateway usage:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/NATGateway \
  --metric-name BytesOutToSource \
  --dimensions Name=NatGatewayId,Value=NAT_GATEWAY_ID \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-31T23:59:59Z \
  --period 86400 \
  --statistics Sum
```

Cost optimization:
- Use single NAT Gateway for dev (edit VPC module)
- Reduce task count during off-hours
- Use Fargate Spot for non-critical workloads
- Reduce CloudWatch log retention
- Delete unused ECR images

### Terraform State Lock

Symptoms:
- Error acquiring the state lock
- Cannot run terraform commands

Solutions:

Check DynamoDB lock table:
```bash
aws dynamodb scan \
  --table-name terraform-state-lock \
  --region us-east-1
```

Force unlock (use carefully):
```bash
cd terraform
terraform force-unlock LOCK_ID
```

### Memory or CPU Issues

Symptoms:
- Tasks being killed (OOMKilled)
- Slow response times
- Auto-scaling triggering frequently

Solutions:

Check metrics:
```bash
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name MemoryUtilization \
  --dimensions Name=ServiceName,Value=ecs-microservices-service-a \
               Name=ClusterName,Value=ecs-microservices-production-cluster \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 300 \
  --statistics Average
```

Common fixes:
- Increase task CPU/memory in terraform.tfvars
- Optimize application code
- Add caching layer
- Review auto-scaling thresholds

### Logs Not Appearing

Symptoms:
- No logs in CloudWatch
- Empty log streams

Solutions:

Check log group exists:
```bash
aws logs describe-log-groups \
  --log-group-name-prefix /ecs/ecs-microservices
```

Verify task execution role has CloudWatch Logs permissions

Common fixes:
- Ensure log group exists before task starts
- Verify task execution role has logs:CreateLogStream and logs:PutLogEvents
- Check application is writing to stdout/stderr
- Confirm awslogs driver configuration in task definition


## Command Reference

### Terraform Commands

```bash
# Initialize Terraform
cd terraform && terraform init

# Plan changes
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy

# View outputs
terraform output

# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# View state
terraform state list

# Get specific output
terraform output alb_dns_name
```

### AWS CLI Commands

ECS Commands:
```bash
# List services
aws ecs list-services --cluster ecs-microservices-production-cluster

# Describe service
aws ecs describe-services \
  --cluster ecs-microservices-production-cluster \
  --services ecs-microservices-service-a

# List tasks
aws ecs list-tasks \
  --cluster ecs-microservices-production-cluster \
  --service-name ecs-microservices-service-a

# Describe task
aws ecs describe-tasks \
  --cluster ecs-microservices-production-cluster \
  --tasks TASK_ID

# Force new deployment
aws ecs update-service \
  --cluster ecs-microservices-production-cluster \
  --service ecs-microservices-service-a \
  --force-new-deployment

# Scale service
aws ecs update-service \
  --cluster ecs-microservices-production-cluster \
  --service ecs-microservices-service-a \
  --desired-count 4
```

CloudWatch Commands:
```bash
# Tail logs
aws logs tail /ecs/ecs-microservices-service-a --follow

# View last hour
aws logs tail /ecs/ecs-microservices-service-a --since 1h

# Filter logs
aws logs filter-log-events \
  --log-group-name /ecs/ecs-microservices-service-a \
  --filter-pattern "ERROR"

# List alarms
aws cloudwatch describe-alarms \
  --alarm-name-prefix ecs-microservices

# Get metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/ECS \
  --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=ecs-microservices-service-a \
               Name=ClusterName,Value=ecs-microservices-production-cluster \
  --start-time 2024-01-01T00:00:00Z \
  --end-time 2024-01-01T23:59:59Z \
  --period 300 \
  --statistics Average
```

ALB Commands:
```bash
# Describe load balancer
aws elbv2 describe-load-balancers \
  --names ecs-microservices-production-alb

# Check target health
aws elbv2 describe-target-health \
  --target-group-arn TARGET_GROUP_ARN

# List target groups
aws elbv2 describe-target-groups \
  --load-balancer-arn LOAD_BALANCER_ARN
```

ECR Commands:
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com

# List images
aws ecr list-images --repository-name ecs-microservices-service-a

# Describe image scan findings
aws ecr describe-image-scan-findings \
  --repository-name ecs-microservices-service-a \
  --image-id imageTag=latest

# Delete image
aws ecr batch-delete-image \
  --repository-name ecs-microservices-service-a \
  --image-ids imageTag=TAG
```

### Docker Commands

```bash
# Build images
docker build -t service-a:latest services/service-a
docker build -t service-b:latest services/service-b

# Tag images
docker tag service-a:latest ECR_URL/service-a:latest
docker tag service-b:latest ECR_URL/service-b:latest

# Push images
docker push ECR_URL/service-a:latest
docker push ECR_URL/service-b:latest

# Run locally
docker run -p 8000:8000 service-a:latest
docker run -p 8001:8001 service-b:latest

# View logs
docker logs CONTAINER_ID

# Execute command in container
docker exec -it CONTAINER_ID /bin/sh
```

### Makefile Commands

```bash
# Show help
make help

# Initialize Terraform
make init

# Plan changes
make plan

# Apply changes
make apply

# Destroy infrastructure
make destroy

# Test services
make test

# View Service A logs
make logs-a

# View Service B logs
make logs-b

# Build Docker images
make build

# Push images to ECR
make push

# Clean artifacts
make clean
```

### Script Commands

```bash
# Setup Terraform backend
./scripts/setup-backend.sh BUCKET_NAME REGION

# Build and push images
./scripts/push-images.sh

# Test deployed services
./scripts/test-services.sh
```

### Testing Commands

```bash
# Get ALB DNS
ALB_DNS=$(cd terraform && terraform output -raw alb_dns_name)

# Test Service A endpoints
curl http://$ALB_DNS/health
curl http://$ALB_DNS/api/hello
curl http://$ALB_DNS/api/info
curl http://$ALB_DNS/api/backend

# Test with verbose output
curl -v http://$ALB_DNS/api/hello

# Test with timing
curl -w "@curl-format.txt" -o /dev/null -s http://$ALB_DNS/api/hello
```

## File Structure

```
ecs-fargate-microservices/
|
|-- README.md                          # This file
|-- .gitignore                         # Git ignore rules
|-- Makefile                           # Common commands
|
|-- .github/
|   `-- workflows/
|       `-- deploy.yml                 # CI/CD pipeline
|
|-- services/
|   |-- service-a/                     # API Gateway service
|   |   |-- app.py                    # FastAPI application
|   |   |-- Dockerfile                # Container definition
|   |   `-- requirements.txt          # Python dependencies
|   `-- service-b/                     # Backend service
|       |-- app.py                    # FastAPI application
|       |-- Dockerfile                # Container definition
|       `-- requirements.txt          # Python dependencies
|
|-- terraform/
|   |-- main.tf                        # Root module
|   |-- variables.tf                   # Input variables
|   |-- outputs.tf                     # Output values
|   |-- backend.tf                     # S3 backend config
|   |-- terraform.tfvars.example       # Example configuration
|   `-- modules/
|       |-- vpc/                       # VPC module
|       |   |-- main.tf
|       |   |-- variables.tf
|       |   `-- outputs.tf
|       |-- alb/                       # Load balancer module
|       |   |-- main.tf
|       |   |-- variables.tf
|       |   `-- outputs.tf
|       |-- ecs/                       # ECS cluster module
|       |   |-- main.tf
|       |   |-- variables.tf
|       |   `-- outputs.tf
|       |-- ecr/                       # Container registry module
|       |   |-- main.tf
|       |   |-- variables.tf
|       |   `-- outputs.tf
|       |-- iam/                       # IAM roles module
|       |   |-- main.tf
|       |   |-- variables.tf
|       |   `-- outputs.tf
|       `-- monitoring/                # CloudWatch module
|           |-- main.tf
|           |-- variables.tf
|           `-- outputs.tf
|
`-- scripts/
    |-- setup-backend.sh               # Setup S3 + DynamoDB
    |-- push-images.sh                 # Build and push images
    `-- test-services.sh               # Test endpoints
```

## Additional Resources

- AWS ECS Best Practices: https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/
- Terraform AWS Provider: https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- GitHub Actions OIDC: https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
- FastAPI Documentation: https://fastapi.tiangolo.com/
- Docker Best Practices: https://docs.docker.com/develop/dev-best-practices/

## License

This project is provided as-is for educational and production use.

## Support

For issues or questions:
1. Check the Troubleshooting section
2. Review AWS documentation
3. Open a GitHub issue
