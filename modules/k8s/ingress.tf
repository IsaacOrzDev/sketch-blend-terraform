resource "kubernetes_ingress_v1" "ingress" {

  metadata {
    name      = "${var.ingress.name}-ingress"
    namespace = var.namespace
    annotations = var.is_aws ? {
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
      "alb.ingress.kubernetes.io/target-type" : "ip"
      } : {
      "kubernetes.io/ingress.class" = "nginx"
    }
  }

  spec {
    ingress_class_name = var.is_aws ? "alb" : "nginx"
    rule {
      http {
        dynamic "path" {
          for_each = var.ingress.paths

          content {
            path      = path.value.path != null ? path.value.path : "/"
            path_type = "Prefix"
            backend {
              service {
                name = path.value.service
                port {
                  number = path.value.port != null ? path.value.port : 80
                }
              }
            }
          }
        }
      }
    }
  }

  count = var.ingress != null ? 1 : 0
}

output "ingress" {
  value = var.ingress != null ? [for i, item in var.ingress.paths : { path = item.path != null ? item.path : "/", service = "${item.service}-service" }] : null

}
