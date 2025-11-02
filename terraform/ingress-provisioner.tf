# ingress-provisioner.tf

# Generate ingress manifest - this is safe and doesn't depend on cluster readiness
resource "local_file" "ingress_manifest" {
  content = templatefile("${path.module}/../kubernetes/ingress.yaml.tpl", {
    ssl_enabled     = false
    certificate_arn = ""
    domain_name     = ""
    namespace       = "job-board"
  })
  filename        = "${path.module}/../kubernetes/ingress-generated.yaml"
  file_permission = "0644"
}

# Create namespace for your application
resource "kubernetes_namespace" "job_board" {
  metadata {
    name = "job-board"
    labels = {
      name = "job-board"
    }
  }

  depends_on = [helm_release.aws_load_balancer_controller]
}

# Create the ingress resource using Terraform (recommended approach)
resource "kubernetes_ingress_v1" "job_board" {
  metadata {
    name      = "job-board-ingress"
    namespace = kubernetes_namespace.job_board.metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/scheme"                    = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"               = "ip"
      "alb.ingress.kubernetes.io/load-balancer-name"        = "job-board-alb"
      "alb.ingress.kubernetes.io/healthcheck-protocol"      = "HTTP"
      "alb.ingress.kubernetes.io/healthcheck-port"          = "traffic-port"
      "alb.ingress.kubernetes.io/healthcheck-path"          = "/"
      "alb.ingress.kubernetes.io/backend-protocol"          = "HTTP"
      "alb.ingress.kubernetes.io/listen-ports"              = "[{\"HTTP\": 80}]"
      "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = "15"
      "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"  = "5"
      "alb.ingress.kubernetes.io/success-codes"             = "200,301,302"
      "alb.ingress.kubernetes.io/healthy-threshold-count"   = "2"
      "alb.ingress.kubernetes.io/unhealthy-threshold-count" = "2"
    }
  }

  spec {
    ingress_class_name = "alb"

    rule {
      http {
        path {
          path      = "/api"
          path_type = "Prefix"
          backend {
            service {
              name = "backend-service"
              port {
                number = 3001
              }
            }
          }
        }

        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "frontend-service"
              port {
                number = 3000
              }
            }
          }
        }
      }
    }
  }

  depends_on = [
    helm_release.aws_load_balancer_controller,
    kubernetes_namespace.job_board
  ]
}

output "infrastructure_ready" {
  value = <<-EOT
    ✅ Infrastructure provisioned successfully!
    
    Cluster: ${module.eks.cluster_name}
    Endpoint: ${module.eks.cluster_endpoint}
    
    ECR Repositories:
    - Backend: ${aws_ecr_repository.backend.repository_url}
    - Frontend: ${aws_ecr_repository.frontend.repository_url}
    
    Next steps:
    1. Build and push your Docker images to ECR
    2. Deploy your application services using kubectl
    3. The ALB ingress is already configured and ready
    
    To get the ALB DNS name after deployment:
    kubectl get ingress -n job-board
    
    To verify everything is working:
    kubectl get pods -n job-board
    kubectl get services -n job-board
  EOT

  depends_on = [
    kubernetes_ingress_v1.job_board,
    helm_release.aws_load_balancer_controller
  ]
}
