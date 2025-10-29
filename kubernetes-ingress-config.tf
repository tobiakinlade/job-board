# ConfigMap for ingress annotations (updated dynamically)
resource "kubernetes_config_map" "ingress_config" {
  metadata {
    name      = "ingress-annotations"
    namespace = "job-board"
  }

  data = {
    certificate_arn = var.domain_name != "" ? aws_acm_certificate.main[0].arn : ""
    domain_name     = var.domain_name
    ssl_enabled     = var.domain_name != "" ? "true" : "false"
  }

  depends_on = [
    module.eks,
    aws_acm_certificate_validation.main
  ]
}
