output "cluster_id" {
  description = "EKS cluster ID"
  value       = module.eks.cluster_id
}

output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = module.eks.cluster_endpoint
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = module.eks.cluster_security_group_id
}

output "cluster_name" {
  description = "Kubernetes Cluster Name"
  value       = module.eks.cluster_name
}

output "region" {
  description = "AWS region"
  value       = var.aws_region
}

output "ecr_backend_repository_url" {
  description = "ECR repository URL for backend"
  value       = aws_ecr_repository.backend.repository_url
}

output "ecr_frontend_repository_url" {
  description = "ECR repository URL for frontend"
  value       = aws_ecr_repository.frontend.repository_url
}

output "vpc_id" {
  description = "VPC ID"
  value       = module.vpc.vpc_id
}

output "private_subnets" {
  description = "Private subnet IDs"
  value       = module.vpc.private_subnets
}

output "public_subnets" {
  description = "Public subnet IDs"
  value       = module.vpc.public_subnets
}

output "ebs_csi_driver_role_arn" {
  description = "ARN of IAM role for EBS CSI driver"
  value       = module.ebs_csi_irsa_role.iam_role_arn
}

output "lb_controller_role_arn" {
  description = "ARN of IAM role for AWS Load Balancer Controller"
  value       = module.lb_controller_irsa_role.iam_role_arn
}

output "configure_kubectl" {
  description = "Configure kubectl: run the following command to update your kubeconfig"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}


output "application_url" {
  description = "Application URL - Access your application via this URL"
  value       = "Application will be accessible via Kubernetes ingress. Run: kubectl get ingress -n default"
}

output "get_ingress_url" {
  description = "Command to get the ingress URL"
  value       = "kubectl get ingress job-board-ingress -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
}
