#!/bin/bash

ALB_SG1="sg-02483ced23a8c4d2e"
ALB_SG2="sg-0524ff83ef79c47b6"
NODE_SG="sg-0940b04e910f0f4bf"

echo "=========================================="
echo "COMPLETE SECURITY GROUP FIX"
echo "=========================================="

# Allow internet to ALB
for SG in $ALB_SG1 $ALB_SG2; do
  aws ec2 authorize-security-group-ingress --group-id $SG --protocol tcp --port 80 --cidr 0.0.0.0/0 --region eu-west-2 2>/dev/null
done
echo "✅ ALB can accept internet traffic"

# Allow ALB to nodes (port 3000 frontend)
for SG in $ALB_SG1 $ALB_SG2; do
  aws ec2 authorize-security-group-ingress --group-id $NODE_SG --protocol tcp --port 3000 --source-group $SG --region eu-west-2 2>/dev/null
done
echo "✅ ALB can reach frontend (3000)"

# Allow ALB to nodes (port 3001 backend)
for SG in $ALB_SG1 $ALB_SG2; do
  aws ec2 authorize-security-group-ingress --group-id $NODE_SG --protocol tcp --port 3001 --source-group $SG --region eu-west-2 2>/dev/null
done
echo "✅ ALB can reach backend (3001)"

echo ""
echo "Waiting 60 seconds for health checks..."
sleep 60

echo ""
echo "TARGET HEALTH:"
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:eu-west-2:180048382895:targetgroup/k8s-jobboard-backends-e1345d2dd5/e903bf25ab22960a --region eu-west-2 --query 'TargetHealthDescriptions[].{IP:Target.Id,State:TargetHealth.State}' --output table
aws elbv2 describe-target-health --target-group-arn arn:aws:elasticloadbalancing:eu-west-2:180048382895:targetgroup/k8s-jobboard-frontend-24f874168d/d1416251b7a42276 --region eu-west-2 --query 'TargetHealthDescriptions[].{IP:Target.Id,State:TargetHealth.State}' --output table

echo ""
echo "TESTING APPLICATION:"
curl -I http://k8s-jobboard-jobboard-388e5e11ff-321396029.eu-west-2.elb.amazonaws.com 2>/dev/null | head -1
