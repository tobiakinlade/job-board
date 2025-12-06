# Job Board - Production-Grade Kubernetes Deployment

A complete 3-part series demonstrating production-ready deployment practices on AWS EKS with Infrastructure as Code, GitOps CI/CD, and full observability.

![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat&logo=kubernetes&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-232F3E?style=flat&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-7B42BC?style=flat&logo=terraform&logoColor=white)
![ArgoCD](https://img.shields.io/badge/ArgoCD-EF7B4D?style=flat&logo=argo&logoColor=white)
![Prometheus](https://img.shields.io/badge/Prometheus-E6522C?style=flat&logo=prometheus&logoColor=white)
![Grafana](https://img.shields.io/badge/Grafana-F46800?style=flat&logo=grafana&logoColor=white)

---

## 📋 Overview

This project demonstrates a complete DevOps workflow for deploying and managing a Job Board application on AWS EKS:

| Part | Focus | Technologies |
|------|-------|--------------|
| **Part 1** | Infrastructure | Terraform, AWS EKS, VPC, IAM |
| **Part 2** | CI/CD Pipeline | GitHub Actions, ArgoCD, Kustomize |
| **Part 3** | Observability | Prometheus, Grafana, Loki, Alertmanager |

---

## 🏗️ Architecture
/job-board-CI_CD-HLD.jpg

/observability-HLD.png
---

## 🚀 Quick Start

### Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform >= 1.0
- kubectl
- Helm 3
- Docker

### 1. Clone the Repository

```bash
git clone https://github.com/tobiakinlade/job-board.git
cd job-board
```

### 2. Deploy Infrastructure (Part 1)

```bash
cd terraform
terraform init
terraform apply --auto-approve
```

### 3. Configure kubectl

```bash
aws eks update-kubeconfig --name job-board-eks --region eu-west-2
```

### 4. Install ArgoCD (Part 2)

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl apply -f argocd/applications.yaml
```

### 5. Create Application Secrets

```bash
kubectl create namespace job-board
kubectl create secret generic job-board-secrets \
  --from-literal=DB_HOST=postgres-service \
  --from-literal=DB_PORT=5432 \
  --from-literal=DB_NAME=jobboard \
  --from-literal=DB_USER=jobboard_user \
  --from-literal=DB_PASSWORD=your_secure_password \
  --from-literal=POSTGRES_DB=jobboard \
  --from-literal=POSTGRES_USER=jobboard_user \
  --from-literal=POSTGRES_PASSWORD=your_secure_password \
  -n job-board
```

### 6. Deploy Monitoring Stack (Part 3)

```bash
# Add Helm repos
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Create monitoring namespace
kubectl create namespace monitoring

# Install Prometheus Stack
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --values monitoring/prometheus-values.yaml

# Install Loki Stack
helm install loki grafana/loki-stack \
  --namespace monitoring \
  --set loki.persistence.enabled=false \
  --set promtail.enabled=true \
  --set grafana.enabled=false

# Apply monitoring configurations
kubectl apply -f monitoring/grafana-datasource-loki.yaml
kubectl apply -f monitoring/servicemonitor.yaml
kubectl apply -f monitoring/prometheus-rules.yaml
kubectl apply -f monitoring/grafana-dashboard.yaml
kubectl apply -f monitoring/alertmanager-config.yaml

# Restart Grafana to load new configs
kubectl rollout restart deployment prometheus-grafana -n monitoring
```

---

## 📁 Project Structure

```
job-board/
├── terraform/                    # Infrastructure as Code
│   ├── main.tf                   # Main Terraform configuration
│   ├── variables.tf              # Variable definitions
│   ├── outputs.tf                # Output values
│   └── modules/                  # Terraform modules
│
├── kubernetes/                   # Kubernetes manifests
│   ├── base/                     # Base Kustomize resources
│   │   ├── frontend-deployment.yaml
│   │   ├── backend-deployment.yaml
│   │   ├── postgres-statefulset.yaml
│   │   ├── services.yaml
│   │   └── kustomization.yaml
│   └── overlays/                 # Environment-specific overlays
│       └── dev/
│           └── kustomization.yaml
│
├── argocd/                       # ArgoCD configuration
│   └── applications.yaml         # ArgoCD Application manifest
│
├── monitoring/                   # Observability stack
│   ├── prometheus-values.yaml    # Prometheus Helm values
│   ├── grafana-datasource-loki.yaml
│   ├── servicemonitor.yaml       # ServiceMonitor definitions
│   ├── prometheus-rules.yaml     # Alert rules
│   ├── grafana-dashboard.yaml    # Custom dashboards
│   └── alertmanager-config.yaml  # Alertmanager configuration
│
├── backend/                      # Node.js API
│   ├── src/
│   ├── Dockerfile
│   └── package.json
│
├── frontend/                     # React application
│   ├── src/
│   ├── Dockerfile
│   └── nginx.conf
│
├── .github/workflows/            # CI/CD pipelines
│   └── deploy.yml                # GitHub Actions workflow
│
└── scripts/                      # Automation scripts
    ├── clean-setup.sh            # Full deployment script
    └── setup-monitoring.sh       # Monitoring setup script
```

---

## 🔧 Components

### Part 1: Infrastructure (Terraform)

| Resource | Description |
|----------|-------------|
| VPC | Custom VPC with public/private subnets |
| EKS Cluster | Managed Kubernetes cluster |
| Node Groups | t3.medium instances (2 nodes) |
| ECR | Container image repositories |
| IAM Roles | IRSA for EBS CSI and Load Balancer Controller |
| EBS CSI Driver | Persistent volume support |
| AWS Load Balancer Controller | ALB ingress support |

### Part 2: CI/CD Pipeline

| Component | Purpose |
|-----------|---------|
| GitHub Actions | Build and push Docker images |
| ArgoCD | GitOps continuous deployment |
| Kustomize | Environment-specific configurations |
| ECR | Container registry |

### Part 3: Observability

| Component | Purpose |
|-----------|---------|
| Prometheus | Metrics collection and storage |
| Grafana | Visualization and dashboards |
| Loki | Log aggregation |
| Promtail | Log shipping |
| Alertmanager | Alert routing to Slack |
| ServiceMonitors | Automatic scrape target discovery |
| PrometheusRules | Alert definitions and SLOs |

---

## 📊 Accessing the Stack

### Application

```bash
# Get the ALB URL
kubectl get ingress -n job-board
```

### Grafana

```bash
kubectl port-forward svc/prometheus-grafana -n monitoring 3000:80
# URL: http://localhost:3000
# Username: admin
# Password: (from prometheus-values.yaml)
```

### Prometheus

```bash
kubectl port-forward svc/prometheus-kube-prometheus-prometheus -n monitoring 9090:9090
# URL: http://localhost:9090
```

### Alertmanager

```bash
kubectl port-forward svc/prometheus-kube-prometheus-alertmanager -n monitoring 9093:9093
# URL: http://localhost:9093
```

### ArgoCD

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# URL: https://localhost:8080
# Username: admin
# Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

---

## 🚨 Alert Rules

| Alert | Condition | Severity |
|-------|-----------|----------|
| JobBoardPodNotReady | Pod not ready for 5m | Warning |
| JobBoardPodRestartingFrequently | >3 restarts in 1h | Warning |
| JobBoardHighMemoryUsage | Memory >85% for 5m | Warning |
| JobBoardHighCPUUsage | CPU >80% for 5m | Warning |
| JobBoardDeploymentReplicasMismatch | Replicas unavailable for 5m | Critical |
| JobBoardPVCAlmostFull | PVC >85% full | Warning |
| JobBoardSLOAvailabilityBreach | Availability <99.9% | Critical |

---

## 💰 Cost Estimation

| Resource | Monthly Cost (Approx) |
|----------|----------------------|
| EKS Control Plane | $73 |
| EC2 Nodes (2x t3.medium) | $60 |
| NAT Gateway | $32 |
| Application Load Balancer | $16 |
| EBS Volumes | $10 |
| **Total** | **~$190/month** |

**Tip:** Destroy resources when not in use:

```bash
cd terraform
terraform destroy --auto-approve
```

---

## 📚 Blog Series

- [Part 1: Building Production-Grade EKS Infrastructure with Terraform](https://medium.com/@tobiakinlade)
- [Part 2: Kubernetes CI/CD Pipeline with GitOps](https://medium.com/@tobiakinlade)
- [Part 3: Production-Grade Observability for AWS EKS](https://medium.com/@tobiakinlade)

---

## 🛠️ Troubleshooting

| Issue | Solution |
|-------|----------|
| ALB returning 504 | Add security group rules for ports 3000/3001 |
| ServiceMonitor not discovered | Ensure `release: prometheus` label exists |
| Grafana CrashLoopBackOff | Check for duplicate default datasources |
| Loki not receiving logs | Verify Promtail pods are running |
| ArgoCD sync failing | Check application logs and Git credentials |

---

## 🤝 Contributing

Contributions are welcome! Please open an issue or submit a pull request.

---

## 📄 License

This project is licensed under the MIT License.

---

## 👤 Author

**Oluwatobi Akinlade**

- LinkedIn: [linkedin.com/in/tobiakinlade](https://linkedin.com/in/tobiakinlade)
- Medium: [medium.com/@tobiakinlade](https://medium.com/@tobiakinlade)
- GitHub: [github.com/tobiakinlade](https://github.com/tobiakinlade)
