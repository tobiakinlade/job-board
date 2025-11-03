variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-west-2"
}

variable "environment" {
  description = "Environment name (e.g., dev, staging, prod)"
  type        = string
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.28"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "single_nat_gateway" {
  description = "Use a single NAT gateway (cheaper but less resilient)"
  type        = bool
  default     = false
}

variable "min_nodes" {
  description = "Minimum number of nodes in the node group"
  type        = number
  default     = 2
}

variable "max_nodes" {
  description = "Maximum number of nodes in the node group"
  type        = number
  default     = 10
}

variable "desired_nodes" {
  description = "Desired number of nodes in the node group"
  type        = number
  default     = 3
}

variable "node_instance_types" {
  description = "Instance types for the EKS node group"
  type        = list(string)
  default     = ["t3.medium"]
}

# variable "alb_security_group_id" {
#   description = "Security group ID of the ALB that needs access to the EKS nodes"
#   type        = string
#   default = ""
# }
