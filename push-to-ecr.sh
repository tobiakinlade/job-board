#!/bin/bash

set -e

VERSION=${1:-"latest"}
AWS_REGION=${AWS_REGION:-"eu-west-2"}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CLUSTER_NAME="job-board-eks"

BACKEND_ECR="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${CLUSTER_NAME}/backend"
FRONTEND_ECR="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${CLUSTER_NAME}/frontend"

echo "======================================="
echo "  Push Docker Images to ECR"
echo "======================================="
echo "Region: ${AWS_REGION}"
echo "Version: ${VERSION}"
echo ""

# Login to ECR
echo "Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Build images
echo "Building backend image..."
docker build -t job-board-backend:${VERSION} ./backend

echo "Building frontend image..."
docker build -t job-board-frontend:${VERSION} ./frontend

# Tag images
echo "Tagging images..."
docker tag job-board-backend:${VERSION} ${BACKEND_ECR}:${VERSION}
docker tag job-board-backend:${VERSION} ${BACKEND_ECR}:latest
docker tag job-board-frontend:${VERSION} ${FRONTEND_ECR}:${VERSION}
docker tag job-board-frontend:${VERSION} ${FRONTEND_ECR}:latest

# Push images
echo "Pushing backend image..."
docker push ${BACKEND_ECR}:${VERSION}
docker push ${BACKEND_ECR}:latest

echo "Pushing frontend image..."
docker push ${FRONTEND_ECR}:${VERSION}
docker push ${FRONTEND_ECR}:latest

echo ""
echo "✅ Images pushed successfully!"
echo "Backend:  ${BACKEND_ECR}:${VERSION}"
echo "Frontend: ${FRONTEND_ECR}:${VERSION}"

# Save to env file
cat > .env.eks << EOF
BACKEND_IMAGE=${BACKEND_ECR}:${VERSION}
FRONTEND_IMAGE=${FRONTEND_ECR}:${VERSION}
AWS_REGION=${AWS_REGION}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
EOF

echo "Environment variables saved to .env.eks"
