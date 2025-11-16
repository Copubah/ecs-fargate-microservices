#!/bin/bash
set -e

# Get ALB DNS from Terraform
cd terraform
ALB_DNS=$(terraform output -raw alb_dns_name)
cd ..

echo "Testing ECS Microservices"
echo "ALB DNS: $ALB_DNS"
echo ""

# Test Service A - Hello endpoint
echo "1. Testing Service A - /api/hello"
curl -s http://$ALB_DNS/api/hello | jq
echo ""

# Test Service A - Info endpoint
echo "2. Testing Service A - /api/info"
curl -s http://$ALB_DNS/api/info | jq
echo ""

# Test Service A calling Service B
echo "3. Testing Service A -> Service B - /api/backend"
curl -s http://$ALB_DNS/api/backend | jq
echo ""

# Health checks
echo "4. Testing Service A health"
curl -s http://$ALB_DNS/health | jq
echo ""

echo "All tests completed!"
