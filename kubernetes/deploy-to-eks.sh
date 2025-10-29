#!/bin/bash

# Script to deploy Job Board application to AWS EKS
# Prerequisites: AWS CLI, kubectl, terraform configured

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
AWS_REGION=${AWS_REGION:-"eu-west-2"}
CLUSTER_NAME="job-board-eks"
NAMESPACE="job-board"

echo -e "${BLUE}======================================${NC}"
echo -e "${BLUE}  Deploy to AWS EKS${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Function to print colored output
print_status() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    echo -e "${BLUE}Checking prerequisites...${NC}"
    
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    if ! command -v terraform &> /dev/null; then
        print_error "Terraform is not installed"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured"
        exit 1
    fi
    
    print_status "All prerequisites met"
    echo ""
}

# Load environment variables if exists
if [ -f ".env.eks" ]; then
    source .env.eks
    print_info "Loaded environment variables from .env.eks"
fi

# Main deployment flow
main() {
    check_prerequisites
    
    # Step 1: Check if EKS cluster exists
    echo -e "${BLUE}Step 1: Checking EKS cluster${NC}"
    echo "-----------------------------------"
    
    if aws eks describe-cluster --name ${CLUSTER_NAME} --region ${AWS_REGION} &> /dev/null; then
        print_status "EKS cluster '${CLUSTER_NAME}' exists"
        
        # Update kubeconfig
        print_info "Updating kubeconfig..."
        aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
        print_status "Kubeconfig updated"
    else
        print_warning "EKS cluster '${CLUSTER_NAME}' does not exist"
        echo ""
        read -p "Would you like to create the cluster using Terraform? (y/n) " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo ""
            echo -e "${BLUE}Initializing Terraform...${NC}"
            cd terraform
            terraform init
            
            echo ""
            echo -e "${BLUE}Planning infrastructure...${NC}"
            terraform plan
            
            echo ""
            read -p "Continue with infrastructure creation? (y/n) " -n 1 -r
            echo
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                terraform apply -auto-approve
                cd ..
                
                # Update kubeconfig
                aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
                print_status "EKS cluster created and kubeconfig updated"
            else
                print_info "Deployment cancelled"
                exit 0
            fi
        else
            print_info "Please create the EKS cluster first"
            exit 1
        fi
    fi
    echo ""
    
    # Step 2: Push images to ECR
    echo -e "${BLUE}Step 2: Push Docker images to ECR${NC}"
    echo "-----------------------------------"
    
    if [ ! -f ".env.eks" ]; then
        read -p "Would you like to build and push images to ECR? (y/n) " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ./scripts/push-to-ecr.sh latest
            source .env.eks
        else
            print_error "Images must be pushed to ECR before deployment"
            exit 1
        fi
    else
        print_info "Using existing images from .env.eks"
        print_info "Backend: ${BACKEND_IMAGE}"
        print_info "Frontend: ${FRONTEND_IMAGE}"
    fi
    echo ""
    
    # Step 3: Update Kubernetes manifests with ECR URLs
    echo -e "${BLUE}Step 3: Updating Kubernetes manifests${NC}"
    echo "-----------------------------------"
    
    print_info "Updating backend deployment..."
    sed -i.bak "s|REPLACE_WITH_ECR_BACKEND_URL:latest|${BACKEND_IMAGE}|g" kubernetes-eks/07-backend-deployment.yaml
    
    print_info "Updating frontend deployment..."
    sed -i.bak "s|REPLACE_WITH_ECR_FRONTEND_URL:latest|${FRONTEND_IMAGE}|g" kubernetes-eks/09-frontend-deployment.yaml
    
    print_status "Manifests updated"
    echo ""
    
    # Step 4: Deploy to Kubernetes
    echo -e "${BLUE}Step 4: Deploying to Kubernetes${NC}"
    echo "-----------------------------------"
    
    # Copy manifests that don't need changes
    cp kubernetes/00-namespace.yaml kubernetes-eks/ 2>/dev/null || true
    cp kubernetes/02-secret.yaml kubernetes-eks/ 2>/dev/null || true
    cp kubernetes/04-postgres-init-configmap.yaml kubernetes-eks/ 2>/dev/null || true
    cp kubernetes/05-postgres-statefulset.yaml kubernetes-eks/ 2>/dev/null || true
    cp kubernetes/06-postgres-service.yaml kubernetes-eks/ 2>/dev/null || true
    
    print_info "Applying Kubernetes manifests..."
    kubectl apply -f kubernetes-eks/00-namespace.yaml
    kubectl apply -f kubernetes-eks/01-configmap.yaml
    kubectl apply -f kubernetes-eks/02-secret.yaml
    kubectl apply -f kubernetes-eks/03-pvc.yaml
    kubectl apply -f kubernetes-eks/04-postgres-init-configmap.yaml
    kubectl apply -f kubernetes-eks/05-postgres-statefulset.yaml
    kubectl apply -f kubernetes-eks/06-postgres-service.yaml
    
    # Wait for PostgreSQL
    print_info "Waiting for PostgreSQL to be ready..."
    kubectl wait --for=condition=ready pod -l app=postgres -n ${NAMESPACE} --timeout=300s
    
    kubectl apply -f kubernetes-eks/07-backend-deployment.yaml
    kubectl apply -f kubernetes-eks/08-backend-service.yaml
    
    # Wait for backend
    print_info "Waiting for backend to be ready..."
    kubectl wait --for=condition=available deployment/backend -n ${NAMESPACE} --timeout=300s
    
    kubectl apply -f kubernetes-eks/09-frontend-deployment.yaml
    kubectl apply -f kubernetes-eks/08-backend-service.yaml  # Frontend service is in same file
    
    # Wait for frontend
    print_info "Waiting for frontend to be ready..."
    kubectl wait --for=condition=available deployment/frontend -n ${NAMESPACE} --timeout=300s
    
    kubectl apply -f kubernetes-eks/11-ingress-alb.yaml
    
    print_status "All resources deployed"
    echo ""
    
    # Step 5: Get ALB URL
    echo -e "${BLUE}Step 5: Getting Application URL${NC}"
    echo "-----------------------------------"
    
    print_info "Waiting for ALB to be provisioned (this may take 2-3 minutes)..."
    sleep 30
    
    ALB_URL=""
    for i in {1..30}; do
        ALB_URL=$(kubectl get ingress job-board-ingress -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
        if [ ! -z "$ALB_URL" ]; then
            break
        fi
        echo -n "."
        sleep 5
    done
    echo ""
    
    if [ ! -z "$ALB_URL" ]; then
        print_status "Application deployed successfully!"
        echo ""
        echo -e "${GREEN}Application URL: http://${ALB_URL}${NC}"
        echo ""
        
        # Update ConfigMap with ALB URL
        print_info "Updating ConfigMap with ALB URL..."
        kubectl patch configmap job-board-config -n ${NAMESPACE} --type merge -p "{\"data\":{\"REACT_APP_API_URL\":\"http://${ALB_URL}/api\"}}"
        
        # Restart frontend to pick up new config
        kubectl rollout restart deployment/frontend -n ${NAMESPACE}
        
        echo ""
        print_info "Useful commands:"
        echo "  kubectl get all -n ${NAMESPACE}"
        echo "  kubectl logs -f -n ${NAMESPACE} -l app=backend"
        echo "  kubectl logs -f -n ${NAMESPACE} -l app=frontend"
    else
        print_warning "Could not retrieve ALB URL. Check ingress status:"
        echo "  kubectl describe ingress job-board-ingress -n ${NAMESPACE}"
    fi
    
    # Cleanup backup files
    rm -f kubernetes-eks/*.bak
    
    echo ""
    print_status "Deployment completed!"
}

# Run main deployment
main
