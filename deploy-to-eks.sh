#!/bin/bash

set -e

echo "======================================="
echo "  Deploy to AWS EKS"
echo "======================================="
echo ""

# Step 1: Push images to ECR
echo "Step 1: Building and pushing images to ECR..."
./push-to-ecr.sh

# Step 2: Load environment variables
source .env.eks

# Step 3: Update manifests
echo ""
echo "Step 2: Updating Kubernetes manifests..."
sed -i '' "s|REPLACE_WITH_ECR_BACKEND_URL:latest|${BACKEND_IMAGE}|g" kubernetes/backend-deployment.yaml
sed -i '' "s|REPLACE_WITH_ECR_FRONTEND_URL:latest|${FRONTEND_IMAGE}|g" kubernetes/frontend-deployment.yaml

echo "✓ Manifests updated"

# Step 4: Configure kubectl
echo ""
echo "Step 3: Configuring kubectl..."
aws eks update-kubeconfig --region eu-west-2 --name job-board-eks
echo "✓ kubectl configured"

# Step 5: Deploy to Kubernetes
echo ""
echo "Step 4: Deploying to EKS..."
kubectl apply -f kubernetes/namespace.yaml
kubectl apply -f kubernetes/configmap.yaml
kubectl apply -f kubernetes/secrets.yaml
kubectl apply -f kubernetes/pvc.yaml
kubectl apply -f kubernetes/postgres-init-configmap.yaml
kubectl apply -f kubernetes/postgres-statefulset.yaml
kubectl apply -f kubernetes/postgres-service.yaml

echo "Waiting for PostgreSQL..."
kubectl wait --for=condition=ready pod -l app=postgres -n job-board --timeout=300s

kubectl apply -f kubernetes/backend-deployment.yaml
kubectl apply -f kubernetes/backend-service.yaml

echo "Waiting for backend..."
kubectl wait --for=condition=available deployment/backend -n job-board --timeout=300s

kubectl apply -f kubernetes/frontend-deployment.yaml
kubectl apply -f kubernetes/frontend-service.yaml

echo "Waiting for frontend..."
kubectl wait --for=condition=available deployment/frontend -n job-board --timeout=300s

kubectl apply -f kubernetes/ingress.yaml

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Getting Application Load Balancer URL..."
sleep 30

ALB_URL=$(kubectl get ingress job-board-ingress -n job-board -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

if [ ! -z "$ALB_URL" ]; then
    echo "🎉 Application URL: http://${ALB_URL}"
else
    echo "⏳ ALB is still provisioning. Check status with:"
    echo "   kubectl get ingress job-board-ingress -n job-board"
fi

echo ""
echo "Useful commands:"
echo "  kubectl get all -n job-board"
echo "  kubectl logs -f -l app=backend -n job-board"
echo "  kubectl logs -f -l app=frontend -n job-board"
