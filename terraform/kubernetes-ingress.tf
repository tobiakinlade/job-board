# Generate ingress manifest template (optional, but kept as you had it)
# This file is typically used for local testing or CI/CD pipelines.
resource "local_file" "ingress_manifest" {
  content = templatefile("${path.module}/../kubernetes/ingress.yaml.tpl", {
    ssl_enabled     = false
    certificate_arn = ""
    domain_name     = ""
    namespace       = "job-board"
    alb_sg_id       = aws_security_group.alb.id
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


# Create the ingress resource for routing traffic to frontend and backend services
resource "kubernetes_ingress_v1" "job_board" {
  metadata {
    name      = "job-board-ingress"
    namespace = kubernetes_namespace.job_board.metadata[0].name
    annotations = {
      "alb.ingress.kubernetes.io/scheme"                    = "internet-facing"
      "alb.ingress.kubernetes.io/target-type"               = "ip"
      "alb.ingress.kubernetes.io/load-balancer-name"        = "job-board-alb"
      "alb.ingress.kubernetes.io/security-groups"           = aws_security_group.alb.id
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

    # Route /api/* to the backend service
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

        # Route / (everything else) to the frontend service
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
    kubernetes_namespace.job_board,
    aws_security_group.alb
  ]
}
