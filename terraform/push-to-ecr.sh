#!/bin/bash

# Script to build and push Docker images to AWS ECR
# Usage: ./push-to-ecr.sh [version]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VERSION=${1:-"latest"}
AWS_REGION=${AWS_REGION:-"eu-west-2"}
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CLUSTER_NAME="job-board-eks"

# ECR URLs (from Terraform output)
BACKEND_ECR="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${CLUSTER_NAME}/backend"
FRONTEND_ECR="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${CLUSTER_NAME}/frontend"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Push Docker Images to ECR${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""
echo -e "${BLUE}Configuration:${NC}"
echo "  AWS Account: ${AWS_ACCOUNT_ID}"
echo "  AWS Region: ${AWS_REGION}"
echo "  Version: ${VERSION}"
echo ""

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install it first."
    exit 1
fi

# Check if we're in the project root
if [ ! -d "./backend" ] || [ ! -d "./frontend" ]; then
    print_error "Please run this script from the project root directory."
    exit 1
fi

# Step 1: Authenticate Docker to ECR
echo -e "${BLUE}Step 1: Authenticating Docker to ECR${NC}"
echo "-----------------------------------"
print_info "Logging in to ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
print_status "Successfully authenticated to ECR"
echo ""

# Step 2: Build Docker Images
echo -e "${BLUE}Step 2: Building Docker Images${NC}"
echo "-----------------------------------"

print_info "Building backend image..."
docker build -t job-board-backend:${VERSION} ./backend
print_status "Backend image built"

print_info "Building frontend image..."
docker build -t job-board-frontend:${VERSION} ./frontend
print_status "Frontend image built"
echo ""

# Step 3: Tag Images for ECR
echo -e "${BLUE}Step 3: Tagging Images${NC}"
echo "-----------------------------------"

print_info "Tagging backend image..."
docker tag job-board-backend:${VERSION} ${BACKEND_ECR}:${VERSION}
docker tag job-board-backend:${VERSION} ${BACKEND_ECR}:latest
print_status "Backend image tagged"

print_info "Tagging frontend image..."
docker tag job-board-frontend:${VERSION} ${FRONTEND_ECR}:${VERSION}
docker tag job-board-frontend:${VERSION} ${FRONTEND_ECR}:latest
print_status "Frontend image tagged"
echo ""

# Step 4: Push Images to ECR
echo -e "${BLUE}Step 4: Pushing Images to ECR${NC}"
echo "-----------------------------------"

print_info "Pushing backend image..."
docker push ${BACKEND_ECR}:${VERSION}
docker push ${BACKEND_ECR}:latest
print_status "Backend image pushed to ${BACKEND_ECR}:${VERSION}"

print_info "Pushing frontend image..."
docker push ${FRONTEND_ECR}:${VERSION}
docker push ${FRONTEND_ECR}:latest
print_status "Frontend image pushed to ${FRONTEND_ECR}:${VERSION}"
echo ""

# Step 5: Verify Images
echo -e "${BLUE}Step 5: Verifying Images${NC}"
echo "-----------------------------------"

print_info "Listing backend images..."
aws ecr list-images --repository-name ${CLUSTER_NAME}/backend --region ${AWS_REGION} --output table

print_info "Listing frontend images..."
aws ecr list-images --repository-name ${CLUSTER_NAME}/frontend --region ${AWS_REGION} --output table
echo ""

print_status "All images pushed successfully!"
echo ""
echo -e "${GREEN}Images are now available in ECR:${NC}"
echo "  Backend:  ${BACKEND_ECR}:${VERSION}"
echo "  Frontend: ${FRONTEND_ECR}:${VERSION}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Update Kubernetes manifests with new image URLs"
echo "  2. Deploy to EKS: kubectl apply -f kubernetes-eks/"
echo ""

# Export variables for use in other scripts
export BACKEND_IMAGE="${BACKEND_ECR}:${VERSION}"
export FRONTEND_IMAGE="${FRONTEND_ECR}:${VERSION}"

cat > .env.eks << EOF
BACKEND_IMAGE=${BACKEND_ECR}:${VERSION}
FRONTEND_IMAGE=${FRONTEND_ECR}:${VERSION}
AWS_REGION=${AWS_REGION}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}
EOF

print_status "Environment variables saved to .env.eks"
