#!/bin/bash

set -e

echo "=========================================="
echo "KUBERNETES CI/CD CLEANUP SCRIPT"
echo "=========================================="
echo ""
echo "This will DELETE:"
echo "  - All Kubernetes resources in job-board namespace"
echo "  - ArgoCD installation"
echo "  - EKS cluster and all AWS resources"
echo "  - Local Terraform state"
echo ""
read -p "Are you sure? (type 'yes' to confirm): " -r
echo ""

if [[ ! $REPLY == "yes" ]]; then
    echo "❌ Cleanup cancelled"
    exit 1
fi

echo "Starting cleanup..."
echo ""

# ====================
# STEP 1: Kubernetes Resources
# ====================
echo "Step 1: Deleting Kubernetes resources..."

if kubectl get namespace job-board &>/dev/null; then
    echo "  - Deleting job-board application..."
    kubectl delete application job-board -n argocd --ignore-not-found=true
    
    echo "  - Deleting job-board namespace..."
    kubectl delete namespace job-board --ignore-not-found=true --timeout=120s
    
    echo "  ✅ Kubernetes resources deleted"
else
    echo "  ℹ️  job-board namespace not found"
fi

echo ""

# ====================
# STEP 2: ArgoCD
# ====================
echo "Step 2: Deleting ArgoCD..."

if kubectl get namespace argocd &>/dev/null; then
    echo "  - Stopping port-forward processes..."
    pkill -f "port-forward.*argocd" || true
    
    echo "  - Deleting ArgoCD namespace..."
    kubectl delete namespace argocd --timeout=120s
    
    echo "  ✅ ArgoCD deleted"
else
    echo "  ℹ️  ArgoCD namespace not found"
fi

echo ""

# ====================
# STEP 3: AWS Load Balancers (clean up before Terraform)
# ====================
echo "Step 3: Cleaning up AWS Load Balancers..."

ALB_ARNS=$(aws elbv2 describe-load-balancers --region eu-west-2 \
    --query "LoadBalancers[?contains(LoadBalancerName, 'k8s-jobboard')].LoadBalancerArn" \
    --output text 2>/dev/null || echo "")

if [ -n "$ALB_ARNS" ]; then
    for ALB_ARN in $ALB_ARNS; do
        echo "  - Deleting ALB: $ALB_ARN"
        aws elbv2 delete-load-balancer --load-balancer-arn $ALB_ARN --region eu-west-2 2>/dev/null || true
    done
    
    echo "  - Waiting for ALBs to be deleted (30 seconds)..."
    sleep 30
    echo "  ✅ ALBs deleted"
else
    echo "  ℹ️  No ALBs found"
fi

echo ""

# ====================
# STEP 4: Target Groups
# ====================
echo "Step 4: Cleaning up Target Groups..."

TG_ARNS=$(aws elbv2 describe-target-groups --region eu-west-2 \
    --query "TargetGroups[?contains(TargetGroupName, 'k8s-jobboard')].TargetGroupArn" \
    --output text 2>/dev/null || echo "")

if [ -n "$TG_ARNS" ]; then
    for TG_ARN in $TG_ARNS; do
        echo "  - Deleting Target Group: $TG_ARN"
        aws elbv2 delete-target-group --target-group-arn $TG_ARN --region eu-west-2 2>/dev/null || true
    done
    echo "  ✅ Target Groups deleted"
else
    echo "  ℹ️  No Target Groups found"
fi

echo ""

# ====================
# STEP 5: Security Groups Created by ALB Controller
# ====================
echo "Step 5: Cleaning up ALB Controller Security Groups..."

SG_IDS=$(aws ec2 describe-security-groups --region eu-west-2 \
    --filters "Name=tag:elbv2.k8s.aws/cluster,Values=job-board-eks" \
    --query "SecurityGroups[].GroupId" \
    --output text 2>/dev/null || echo "")

if [ -n "$SG_IDS" ]; then
    echo "  - Waiting 30 seconds for resources to detach..."
    sleep 30
    
    for SG_ID in $SG_IDS; do
        echo "  - Deleting Security Group: $SG_ID"
        aws ec2 delete-security-group --group-id $SG_ID --region eu-west-2 2>/dev/null || true
    done
    echo "  ✅ Security Groups deleted"
else
    echo "  ℹ️  No ALB Controller Security Groups found"
fi

echo ""

# ====================
# STEP 6: Terraform Destroy
# ====================
echo "Step 6: Destroying Terraform infrastructure..."

if [ -d "terraform/eks" ]; then
    cd terraform/eks
    
    if [ -f "terraform.tfstate" ]; then
        echo "  - Running terraform destroy..."
        terraform destroy -auto-approve
        
        echo "  - Cleaning up Terraform files..."
        rm -rf .terraform .terraform.lock.hcl terraform.tfstate terraform.tfstate.backup
        
        echo "  ✅ Terraform infrastructure destroyed"
    else
        echo "  ℹ️  No Terraform state found"
    fi
    
    cd ../..
else
    echo "  ℹ️  Terraform directory not found"
fi

echo ""

# ====================
# STEP 7: ECR Images (Optional)
# ====================
echo "Step 7: Cleaning up ECR images..."

read -p "Delete ECR repositories and all images? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    aws ecr delete-repository --repository-name job-board-backend --region eu-west-2 --force 2>/dev/null || true
    aws ecr delete-repository --repository-name job-board-frontend --region eu-west-2 --force 2>/dev/null || true
    echo "  ✅ ECR repositories deleted"
else
    echo "  ℹ️  Skipping ECR deletion"
fi

echo ""

# ====================
# STEP 8: Kubeconfig Cleanup
# ====================
echo "Step 8: Cleaning up kubeconfig..."

if kubectl config get-contexts | grep -q "job-board-eks"; then
    kubectl config delete-context $(kubectl config current-context) 2>/dev/null || true
    kubectl config delete-cluster job-board-eks 2>/dev/null || true
    kubectl config unset users.job-board-eks 2>/dev/null || true
    echo "  ✅ Kubeconfig cleaned"
else
    echo "  ℹ️  No job-board-eks context found"
fi

echo ""

# ====================
# STEP 9: Local Cleanup (Optional)
# ====================
echo "Step 9: Local cleanup..."

read -p "Delete local job-board directory? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    cd ~
    rm -rf job-board
    echo "  ✅ Local directory deleted"
else
    echo "  ℹ️  Keeping local directory"
fi

echo ""

# ====================
# Summary
# ====================
echo "=========================================="
echo "✅ CLEANUP COMPLETE"
echo "=========================================="
echo ""
echo "Cleaned up:"
echo "  ✅ Kubernetes resources"
echo "  ✅ ArgoCD"
echo "  ✅ AWS Load Balancers"
echo "  ✅ Target Groups"
echo "  ✅ Security Groups"
echo "  ✅ EKS cluster"
echo "  ✅ VPC and networking"
echo ""
echo "Verify cleanup:"
echo "  aws eks list-clusters --region eu-west-2"
echo "  aws elbv2 describe-load-balancers --region eu-west-2"
