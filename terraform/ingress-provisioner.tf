# Generate ingress manifest from template
resource "local_file" "ingress_manifest" {
  content = templatefile("${path.module}/../kubernetes/ingress.yaml.tpl", {
    ssl_enabled     = false
    certificate_arn = ""
    domain_name     = ""
  })
  filename = "${path.module}/../kubernetes/ingress-generated.yaml"
}

# Apply the ingress after everything is ready
resource "null_resource" "apply_ingress" {
  triggers = {
    ingress_content = local_file.ingress_manifest.content
  }

  provisioner "local-exec" {
    command = "kubectl apply -f ${path.module}/../kubernetes/ingress-generated.yaml"
  }

  depends_on = [
    local_file.ingress_manifest,
    helm_release.aws_load_balancer_controller
  ]
}
