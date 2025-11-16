# ECS Fargate Microservices Architecture

Complete production-ready microservices platform on AWS using ECS Fargate, Terraform, and GitHub Actions.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                          Internet                                │
└────────────────────────────┬────────────────────────────────────┘
                             │
                    ┌────────▼────────┐
                    │   AWS WAF       │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Application    │
                    │  Load Balancer  │
                    │  (Public Subnet)│
                    └────┬───────┬────┘
                         │       │
        ┌────────────────┘       └────────────────┐
        │                                         │
┌───────▼────────┐                       ┌───────▼────────┐
│  ECS Service A │                       │  ECS Service B │
│  (Fargate)     │──────────────────────▶│  (Fargate)     │
│ Private Subnet │                       │ Private Subnet │
└───────┬────────┘                       └───────┬────────┘
        │                                         │
        └─────────────────┬───────────────────────┘
                          │
                 ┌────────▼────────┐
                 │   NAT Gateway   │
                 │  (Public Subnet)│
                 └────────┬────────┘
                          │
              ┌───────────▼───────────┐
              │  ECR / Secrets Mgr    │
              │  CloudWatch Logs      │
              └───────────────────────┘
```

## Services

- **Service A (API Gateway)**: Public-facing REST API on port 8000
- **Service B (Backend)**: Internal service on port 8001

## Prerequisites

- AWS Account with appropriate permissions
- Terraform >= 1.5.0
- Docker
- GitHub repository
- AWS CLI configured

## Quick Start

### 1. Configure Backend

Create S3 bucket and DynamoDB table for Terraform state:

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

### 2. Configure Terraform Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

### 3. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### 4. Configure GitHub Actions

Set up GitHub OIDC provider (already in Terraform), then add secrets:

- `AWS_ACCOUNT_ID`: Your AWS account ID
- `AWS_REGION`: Deployment region (e.g., us-east-1)

### 5. Deploy Services

Push to main branch to trigger CI/CD:

```bash
git add .
git commit -m "Initial deployment"
git push origin main
```

## Testing Endpoints

Get ALB DNS name:

```bash
terraform output alb_dns_name
```

Test Service A:

```bash
curl http://<alb-dns-name>/api/hello
curl http://<alb-dns-name>/api/info
```

Test Service B (via Service A):

```bash
curl http://<alb-dns-name>/api/backend
```

## CI/CD Workflow

```
┌──────────────┐
│  Git Push    │
└──────┬───────┘
       │
┌──────▼───────────────────────────────────────────┐
│  GitHub Actions Workflow                         │
├──────────────────────────────────────────────────┤
│  1. Checkout code                                │
│  2. Configure AWS credentials (OIDC)             │
│  3. Build Docker images (with cache)             │
│  4. Scan images for vulnerabilities              │
│  5. Push to ECR                                  │
│  6. Run Terraform plan                           │
│  7. Apply infrastructure changes                 │
│  8. Deploy new task definitions                  │
│  9. Wait for service stability                   │
└──────┬───────────────────────────────────────────┘
       │
┌──────▼───────┐
│  ECS Fargate │
│  Running     │
└──────────────┘
```

## Monitoring

### CloudWatch Dashboards

Access dashboards in AWS Console:
- ECS Container Insights
- Custom metrics dashboard (created by Terraform)

### Alarms

Configured alarms:
- High CPU utilization (>80%)
- High memory utilization (>80%)
- ALB 5xx errors
- ECS task failures
- Unhealthy target count

### Logs

View logs:

```bash
aws logs tail /ecs/service-a --follow
aws logs tail /ecs/service-b --follow
```

## Cost Estimation

Monthly costs (us-east-1, approximate):

| Service | Configuration | Monthly Cost |
|---------|--------------|--------------|
| ECS Fargate (2 services) | 0.25 vCPU, 0.5 GB each, 24/7 | ~$15 |
| ALB | 1 ALB, minimal traffic | ~$20 |
| NAT Gateway | 2 AZs | ~$65 |
| ECR | 10 GB storage | ~$1 |
| CloudWatch Logs | 5 GB ingestion, 1 month retention | ~$3 |
| S3 (Terraform state) | Minimal | <$1 |
| **Total** | | **~$105/month** |

Cost optimization tips:
- Use single NAT Gateway for dev environments
- Reduce Fargate task count during off-hours
- Implement log retention policies
- Use Fargate Spot for non-critical workloads

## Security Features

- ✅ Private subnets for ECS tasks
- ✅ Security groups with least privilege
- ✅ IAM task roles (no hardcoded credentials)
- ✅ ECR image scanning enabled
- ✅ CloudWatch logs encrypted
- ✅ S3 backend encryption
- ✅ Secrets Manager for sensitive data
- ✅ AWS WAF on ALB
- ✅ HTTPS support (configure ACM certificate)

## Scaling Configuration

Auto-scaling policies configured:
- Target tracking on CPU (70%)
- Target tracking on memory (70%)
- Min tasks: 1
- Max tasks: 10

Modify in `terraform/modules/ecs/main.tf`

## Troubleshooting

### Tasks not starting

```bash
# Check service events
aws ecs describe-services \
  --cluster ecs-cluster \
  --services service-a

# Check task logs
aws logs tail /ecs/service-a --follow
```

### Cannot pull ECR images

Verify IAM task execution role has ECR permissions:

```bash
aws iam get-role --role-name ecs-task-execution-role
```

### ALB health checks failing

Check target group health:

```bash
aws elbv2 describe-target-health \
  --target-group-arn <target-group-arn>
```

Verify security groups allow ALB → ECS communication.

### High costs

- Check NAT Gateway data transfer
- Review CloudWatch Logs retention
- Verify no unused resources

## File Structure

```
.
├── README.md
├── .github/
│   └── workflows/
│       └── deploy.yml
├── services/
│   ├── service-a/
│   │   ├── Dockerfile
│   │   ├── app.py
│   │   └── requirements.txt
│   └── service-b/
│       ├── Dockerfile
│       ├── app.py
│       └── requirements.txt
└── terraform/
    ├── main.tf
    ├── variables.tf
    ├── outputs.tf
    ├── backend.tf
    ├── terraform.tfvars.example
    └── modules/
        ├── vpc/
        ├── alb/
        ├── ecs/
        ├── ecr/
        ├── iam/
        └── monitoring/
```

## Cleanup

To destroy all resources:

```bash
cd terraform
terraform destroy
```

Note: Manually delete ECR images first if repositories are not empty.

## Additional Resources

- [AWS ECS Best Practices](https://docs.aws.amazon.com/AmazonECS/latest/bestpracticesguide/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions OIDC](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)

## Support

For issues or questions, please open a GitHub issue.
