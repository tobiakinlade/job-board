#!/bin/bash
# clean-setup.sh - Complete teardown and rebuild

echo "=========================================="
echo "CLEAN ROOM SETUP TEST"
echo "=========================================="

# 1. Destroy everything
echo "Step 1: Destroying infrastructure..."
cd ~/job-board/terraform/
terraform destroy -auto-approve

# 2. Recreate infrastructure
echo ""
echo "Step 2: Creating infrastructure..."
terraform apply -auto-approve

# 3. Update kubeconfig
echo ""
echo "Step 3: Updating kubeconfig..."
aws eks update-kubeconfig --name job-board-eks --region eu-west-2

# 4. Install ArgoCD
echo ""
echo "Step 4: Installing ArgoCD..."
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD
echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# 5. Create application
echo ""
echo "Step 5: Creating ArgoCD application..."
kubectl apply -f ~/job-board/argocd/applications.yaml

# 6. Create secrets
echo ""
echo "Step 6: Creating secrets..."
kubectl create secret generic job-board-secrets \
  --from-literal=DB_HOST=postgres-service \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=jobboard \
  --from-literal=DB_USER=jobboard_user \
  --from-literal=DB_PASSWORD=secure_password_123 \
  --from-literal=POSTGRES_DB=jobboard \
  --from-literal=POSTGRES_USER=jobboard_user \
  --from-literal=POSTGRES_PASSWORD=secure_password_123 \
  -n job-board

# 7. Wait for deployment
echo ""
echo "Step 7: Waiting for deployment (120 seconds)..."
sleep 120

# 8. Check status
echo ""
echo "=========================================="
echo "DEPLOYMENT STATUS"
echo "=========================================="
kubectl get all,ingress,pvc -n job-board

echo ""
echo "TARGET HEALTH:"
TG_ARNS=$(aws elbv2 describe-target-groups --region eu-west-2 \
  --query "TargetGroups[?contains(TargetGroupName, 'jobboard')].TargetGroupArn" \
  --output text)

for TG in $TG_ARNS; do
  aws elbv2 describe-target-health --target-group-arn $TG --region eu-west-2 \
    --query 'TargetHealthDescriptions[0].TargetHealth.State' --output text
done

echo ""
ALB_DNS=$(kubectl get ingress job-board-ingress -n job-board \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [ -n "$ALB_DNS" ]; then
  echo "✅ Application URL: http://$ALB_DNS"
  echo ""
  echo "Testing..."
  curl -s -o /dev/null -w "HTTP Status: %{http_code}\n" http://$ALB_DNS
else
  echo "⏳ ALB still provisioning..."
fi
