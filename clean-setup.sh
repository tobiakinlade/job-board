#!/bin/bash
# clean-setup.sh - Complete teardown and rebuild

echo "=========================================="
echo "CLEAN ROOM SETUP TEST"
echo "=========================================="

# 1. Provision everything
echo "Step 1: Provisioning infrastructure..."
cd terraform/
terraform apply --auto-approve

# 2. Update kubeconfig
echo ""
echo "Step 2: Updating kubeconfig..."
aws eks update-kubeconfig --name job-board-eks --region eu-west-2

# 3. Install ArgoCD
echo ""
echo "Step 3: Installing ArgoCD..."
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD
echo "Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd

# 4. Create application
echo ""
echo "Step 4: Creating ArgoCD application..."
kubectl apply -f argocd/applications.yaml

# 5. Create secrets
echo ""
echo "Step 5: Creating secrets..."
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

# 6. Wait for pods and ingress to be created
echo ""
echo "Step 6: Waiting for pods and ingress to be created (90 seconds)..."
sleep 90

# 7. Configure Security Groups for ALB -> Pod communication
echo ""
echo "Step 7: Configuring security groups..."

# Get node security group
NODE_SG=$(aws ec2 describe-security-groups --region eu-west-2 \
  --filters "Name=tag:kubernetes.io/cluster/job-board-eks,Values=owned" "Name=group-name,Values=*node*" \
  --query 'SecurityGroups[0].GroupId' --output text)
echo "Node Security Group: $NODE_SG"

# Wait for ALB security group to be created
echo "Waiting for ALB security group..."
for i in {1..30}; do
  ALB_SG=$(aws ec2 describe-security-groups --region eu-west-2 \
    --filters "Name=group-name,Values=*k8s-jobboard*" \
    --query 'SecurityGroups[0].GroupId' --output text 2>/dev/null)
  
  if [ -n "$ALB_SG" ] && [ "$ALB_SG" != "None" ]; then
    echo "ALB Security Group: $ALB_SG"
    break
  fi
  echo "  Waiting for ALB SG... ($i/30)"
  sleep 10
done

if [ -n "$ALB_SG" ] && [ "$ALB_SG" != "None" ]; then
  # Add ingress rule for frontend (port 3000)
  echo "Adding security group rule for port 3000 (frontend)..."
  aws ec2 authorize-security-group-ingress \
    --group-id $NODE_SG \
    --protocol tcp \
    --port 3000 \
    --source-group $ALB_SG \
    --region eu-west-2 2>/dev/null || echo "  Rule may already exist"

  # Add ingress rule for backend (port 3001)
  echo "Adding security group rule for port 3001 (backend)..."
  aws ec2 authorize-security-group-ingress \
    --group-id $NODE_SG \
    --protocol tcp \
    --port 3001 \
    --source-group $ALB_SG \
    --region eu-west-2 2>/dev/null || echo "  Rule may already exist"

  echo "✅ Security group rules configured"
else
  echo "⚠️  Could not find ALB security group. You may need to add rules manually."
fi

# 8. Wait for targets to become healthy
echo ""
echo "Step 8: Waiting for targets to become healthy (60 seconds)..."
sleep 60

# 9. Check status
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
  TG_NAME=$(aws elbv2 describe-target-groups --target-group-arns $TG --region eu-west-2 \
    --query 'TargetGroups[0].TargetGroupName' --output text)
  HEALTH=$(aws elbv2 describe-target-health --target-group-arn $TG --region eu-west-2 \
    --query 'TargetHealthDescriptions[0].TargetHealth.State' --output text)
  echo "  $TG_NAME: $HEALTH"
done

echo ""
ALB_DNS=$(kubectl get ingress job-board-ingress -n job-board \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [ -n "$ALB_DNS" ]; then
  echo "✅ Application URL: http://$ALB_DNS"
  echo ""
  echo "Testing endpoints..."
  echo -n "  Frontend: "
  curl -s -o /dev/null -w "%{http_code}\n" http://$ALB_DNS/
  echo -n "  Backend API: "
  curl -s -o /dev/null -w "%{http_code}\n" http://$ALB_DNS/api/jobs
else
  echo "⏳ ALB still provisioning..."
fi

echo ""
echo "=========================================="
echo "ARGOCD ACCESS"
echo "=========================================="
echo "Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
echo "Port forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "URL: https://localhost:8080"
