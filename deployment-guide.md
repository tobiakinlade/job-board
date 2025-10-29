# AWS EKS Deployment Guide - Job Board Application

This guide walks you through deploying the Job Board application to Amazon EKS (Elastic Kubernetes Service).

## 📋 Prerequisites

### Required Tools
- **AWS CLI** (v2.x or later)
- **kubectl** (v1.28 or later)
- **Terraform** (v1.0 or later)
- **Docker** (v20.x or later)
- **Git**

### AWS Account Requirements
- AWS account with appropriate permissions
- IAM user or role with permissions for:
  - EKS (Elastic Kubernetes Service)
  - EC2 (Virtual Private Cloud, Security Groups)
  - ECR (Elastic Container Registry)
  - IAM (Roles and Policies)
  - EBS (Elastic Block Storage)
  - Application Load Balancer

### Install Tools

**AWS CLI:**
```bash
# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Verify
aws --version
```

**kubectl:**
```bash
# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
sudo mv kubectl /usr/local/bin/

# Verify
kubectl version --client
```

**Terraform:**
```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/

# Verify
terraform version
```

### Configure AWS Credentials

```bash
# Configure AWS CLI
aws configure

# Or use environment variables
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Verify
aws sts get-caller-identity
```

## 🗂️ Project Structure

```
job-board/
├── backend/
├── frontend/
├── terraform/                       # EKS Infrastructure as Code
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── kubernetes-addons.tf
├── kubernetes-eks/                  # EKS-specific K8s manifests
│   ├── 00-namespace.yaml
│   ├── 01-configmap.yaml
│   ├── 02-secret.yaml
│   ├── 03-pvc.yaml
│   ├── 04-postgres-init-configmap.yaml
│   ├── 05-postgres-statefulset.yaml
│   ├── 06-postgres-service.yaml
│   ├── 07-backend-deployment.yaml
│   ├── 08-backend-service.yaml
│   ├── 09-frontend-deployment.yaml
│   └── 11-ingress-alb.yaml
└── scripts/
    ├── push-to-ecr.sh              # Push images to ECR
    └── deploy-to-eks.sh            # Complete deployment automation
```

## 🚀 Quick Start (Automated)

### Option 1: One-Command Deployment

```bash
# Make scripts executable
chmod +x scripts/*.sh

# Run automated deployment
./scripts/deploy-to-eks.sh
```

This script will:
1. Check prerequisites
2. Create EKS cluster (if needed)
3. Build and push Docker images to ECR
4. Deploy application to EKS
5. Create Application Load Balancer
6. Display application URL

## 📝 Step-by-Step Deployment (Manual)

### Step 1: Configure Terraform Variables

Edit `terraform/variables.tf` or create `terraform/terraform.tfvars`:

```hcl
aws_region         = "us-east-1"
cluster_name       = "job-board-eks"
cluster_version    = "1.28"
environment        = "production"
min_nodes          = 2
max_nodes          = 5
desired_nodes      = 2
node_instance_types = ["t3.medium"]
single_nat_gateway = true  # Set to false for HA
```

### Step 2: Create EKS Infrastructure

```bash
cd terraform

# Initialize Terraform
terraform init

# Review planned changes
terraform plan

# Create infrastructure (takes 15-20 minutes)
terraform apply

# Save outputs
terraform output > ../terraform-outputs.txt
```

**What gets created:**
- VPC with public and private subnets across 3 AZs
- EKS cluster (control plane)
- EKS managed node group (worker nodes)
- ECR repositories for Docker images
- IAM roles for EKS, EBS CSI Driver, and ALB Controller
- Security groups and networking
- EBS CSI Driver (for persistent volumes)
- AWS Load Balancer Controller

### Step 3: Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name job-board-eks

# Verify connection
kubectl get nodes
kubectl get pods -A
```

### Step 4: Build and Push Docker Images to ECR

```bash
cd ..  # Back to project root

# Get ECR repository URLs from Terraform output
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION="us-east-1"
export BACKEND_ECR="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/job-board-eks/backend"
export FRONTEND_ECR="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/job-board-eks/frontend"

# Login to ECR
aws ecr get-login-password --region ${AWS_REGION} | \
  docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# Build images
docker build -t job-board-backend:latest ./backend
docker build -t job-board-frontend:latest ./frontend

# Tag images
docker tag job-board-backend:latest ${BACKEND_ECR}:latest
docker tag job-board-frontend:latest ${FRONTEND_ECR}:latest

# Push to ECR
docker push ${BACKEND_ECR}:latest
docker push ${FRONTEND_ECR}:latest

# Verify
aws ecr list-images --repository-name job-board-eks/backend --region ${AWS_REGION}
aws ecr list-images --repository-name job-board-eks/frontend --region ${AWS_REGION}
```

**Or use the automated script:**
```bash
./scripts/push-to-ecr.sh latest
```

### Step 5: Update Kubernetes Manifests

Update image URLs in deployment files:

```bash
# Update backend deployment
sed -i "s|REPLACE_WITH_ECR_BACKEND_URL:latest|${BACKEND_ECR}:latest|g" \
  kubernetes-eks/07-backend-deployment.yaml

# Update frontend deployment
sed -i "s|REPLACE_WITH_ECR_FRONTEND_URL:latest|${FRONTEND_ECR}:latest|g" \
  kubernetes-eks/09-frontend-deployment.yaml
```

### Step 6: Deploy to EKS

```bash
# Deploy namespace
kubectl apply -f kubernetes-eks/00-namespace.yaml

# Deploy ConfigMap and Secrets
kubectl apply -f kubernetes-eks/01-configmap.yaml
kubectl apply -f kubernetes-eks/02-secret.yaml

# Deploy storage
kubectl apply -f kubernetes-eks/03-pvc.yaml

# Deploy database
kubectl apply -f kubernetes-eks/04-postgres-init-configmap.yaml
kubectl apply -f kubernetes-eks/05-postgres-statefulset.yaml
kubectl apply -f kubernetes-eks/06-postgres-service.yaml

# Wait for database
kubectl wait --for=condition=ready pod -l app=postgres -n job-board --timeout=300s

# Deploy backend
kubectl apply -f kubernetes-eks/07-backend-deployment.yaml
kubectl apply -f kubernetes-eks/08-backend-service.yaml

# Wait for backend
kubectl wait --for=condition=available deployment/backend -n job-board --timeout=300s

# Deploy frontend
kubectl apply -f kubernetes-eks/09-frontend-deployment.yaml

# Wait for frontend
kubectl wait --for=condition=available deployment/frontend -n job-board --timeout=300s

# Deploy Ingress (creates ALB)
kubectl apply -f kubernetes-eks/11-ingress-alb.yaml
```

### Step 7: Get Application URL

```bash
# Wait for ALB provisioning (2-3 minutes)
kubectl get ingress job-board-ingress -n job-board -w

# Get ALB URL
ALB_URL=$(kubectl get ingress job-board-ingress -n job-board \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Application URL: http://${ALB_URL}"

# Update ConfigMap with ALB URL
kubectl patch configmap job-board-config -n job-board --type merge \
  -p "{\"data\":{\"REACT_APP_API_URL\":\"http://${ALB_URL}/api\"}}"

# Restart frontend to pick up new config
kubectl rollout restart deployment/frontend -n job-board
```

### Step 8: Verify Deployment

```bash
# Check all resources
kubectl get all -n job-board

# Check pods
kubectl get pods -n job-board

# Check services
kubectl get svc -n job-board

# Check ingress
kubectl get ingress -n job-board

# View logs
kubectl logs -f -n job-board -l app=backend
kubectl logs -f -n job-board -l app=frontend
kubectl logs -f -n job-board -l app=postgres
```

## 🔍 Monitoring and Management

### View Application Logs

```bash
# Backend logs
kubectl logs -f -n job-board deployment/backend

# Frontend logs
kubectl logs -f -n job-board deployment/frontend

# Database logs
kubectl logs -f -n job-board statefulset/postgres

# All logs with labels
stern -n job-board .
```

### Check Resource Usage

```bash
# Pod metrics
kubectl top pods -n job-board

# Node metrics
kubectl top nodes

# Describe resources
kubectl describe deployment backend -n job-board
kubectl describe ingress job-board-ingress -n job-board
```

### Access Database

```bash
# Get shell in postgres pod
kubectl exec -it postgres-0 -n job-board -- psql -U jobboard -d jobboard

# Run SQL commands
\dt
SELECT * FROM jobs;
```

### Scale Application

```bash
# Manual scaling
kubectl scale deployment backend --replicas=3 -n job-board
kubectl scale deployment frontend --replicas=3 -n job-board

# Auto-scaling (HPA)
kubectl autoscale deployment backend \
  --cpu-percent=70 \
  --min=2 \
  --max=10 \
  -n job-board

# Check HPA
kubectl get hpa -n job-board
```

## 🔐 Security Best Practices

### 1. Update Secrets

Never use default passwords in production:

```bash
# Generate new base64 encoded passwords
echo -n 'new-secure-password' | base64

# Update secrets
kubectl edit secret job-board-secrets -n job-board

# Restart deployments
kubectl rollout restart deployment/backend -n job-board
kubectl rollout restart statefulset/postgres -n job-board
```

### 2. Enable HTTPS/TLS

Request ACM certificate:
```bash
# Request certificate in AWS Certificate Manager
aws acm request-certificate \
  --domain-name job-board.example.com \
  --validation-method DNS \
  --region us-east-1

# Get certificate ARN
aws acm list-certificates --region us-east-1
```

Update Ingress:
```yaml
annotations:
  alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
  alb.ingress.kubernetes.io/certificate-arn: arn:aws:acm:REGION:ACCOUNT:certificate/CERT-ID
  alb.ingress.kubernetes.io/ssl-redirect: '443'
```

### 3. Network Policies

Apply network policies for zero-trust:
```bash
kubectl apply -f kubernetes/13-network-policies.yaml
```

### 4. Pod Security Standards

Enable pod security:
```bash
kubectl label namespace job-board \
  pod-security.kubernetes.io/enforce=restricted \
  pod-security.kubernetes.io/audit=restricted \
  pod-security.kubernetes.io/warn=restricted
```

## 💰 Cost Optimization

### Monitor Costs

```bash
# Check running resources
kubectl get nodes
kubectl get pods -A

# View EKS costs in AWS Console
# Cost Explorer > EKS
```

### Reduce Costs

1. **Use Spot Instances** for non-critical workloads
2. **Right-size instances** based on actual usage
3. **Use single NAT Gateway** for non-prod (already configured)
4. **Enable Cluster Autoscaler**
5. **Set up resource quotas and limits**
6. **Delete unused resources**

### Estimated Monthly Costs (us-east-1)

- EKS Control Plane: ~$73/month
- 2x t3.medium nodes: ~$60/month
- NAT Gateway: ~$32/month
- Application Load Balancer: ~$23/month
- EBS Storage (10Gi): ~$1/month
- **Total: ~$189/month**

## 🧹 Cleanup

### Delete Application Only

```bash
# Delete Kubernetes resources
kubectl delete namespace job-board

# Or delete individually
kubectl delete -f kubernetes-eks/
```

### Delete Everything (Infrastructure + Application)

```bash
# Delete Kubernetes resources first
kubectl delete namespace job-board

# Delete EKS cluster and all infrastructure
cd terraform
terraform destroy

# Confirm with: yes

# Manual cleanup if needed
aws ecr delete-repository --repository-name job-board-eks/backend --force --region us-east-1
aws ecr delete-repository --repository-name job-board-eks/frontend --force --region us-east-1
```

## 🔧 Troubleshooting

### Pods not starting

```bash
# Check pod status
kubectl get pods -n job-board

# Describe pod
kubectl describe pod <pod-name> -n job-board

# Check logs
kubectl logs <pod-name> -n job-board

# Check events
kubectl get events -n job-board --sort-by='.lastTimestamp'
```

### Image pull errors

```bash
# Verify ECR repository
aws ecr describe-repositories --region us-east-1

# Check if images exist
aws ecr list-images --repository-name job-board-eks/backend --region us-east-1

# Verify node IAM role has ECR permissions
aws iam list-attached-role-policies --role-name <node-role-name>
```

### ALB not created

```bash
# Check ingress status
kubectl describe ingress job-board-ingress -n job-board

# Check ALB controller logs
kubectl logs -n kube-system deployment/aws-load-balancer-controller

# Verify subnets are tagged correctly
aws ec2 describe-subnets --filters "Name=tag:kubernetes.io/role/elb,Values=1"
```

### Database connection issues

```bash
# Test connectivity from backend pod
kubectl exec -it <backend-pod> -n job-board -- sh
nc -zv postgres-service 5432

# Check PostgreSQL logs
kubectl logs postgres-0 -n job-board

# Verify PVC is bound
kubectl get pvc -n job-board
```

### Terraform errors

```bash
# If terraform state is locked
terraform force-unlock <lock-id>

# If resources exist
terraform import <resource-type>.<resource-name> <resource-id>

# Reset state (careful!)
terraform state rm <resource>
```

## 📚 Next Steps

### 1. Set Up CI/CD

- GitHub Actions for automated deployments
- ArgoCD for GitOps
- Flux CD for continuous delivery

### 2. Add Monitoring

```bash
# Install Prometheus and Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace
```

### 3. Implement Logging

- AWS CloudWatch Container Insights
- ELK Stack (Elasticsearch, Logstash, Kibana)
- Loki + Grafana

### 4. Add Backup Solution

- Velero for Kubernetes backups
- AWS Backup for EBS volumes
- Automated database backups to S3

### 5. Multi-Environment Setup

- Create separate clusters for dev/staging/prod
- Use Kustomize or Helm for environment-specific configs
- Implement proper IAM separation

## 📖 Useful Resources

- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Load Balancer Controller](https://kubernetes-sigs.github.io/aws-load-balancer-controller/)
- [EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)

## 🎉 Success!

Your Job Board application is now running on AWS EKS with:
- ✅ High availability across multiple AZs
- ✅ Auto-scaling capabilities
- ✅ Persistent storage with EBS
- ✅ Production-ready ALB
- ✅ Secure networking with VPC
- ✅ Container registry with ECR
- ✅ Infrastructure as Code with Terraform

Access your application at the ALB URL and start posting jobs! 🚀
