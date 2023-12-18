
terraform {
  required_providers {

    helm = {
      source  = "hashicorp/helm"
      version = "2.11.0"
    }
  }
}

resource "helm_release" "redis" {
  name       = "redis"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "redis"
  version    = var.release
  namespace  = var.namespace

  set {
    name  = "password"
    value = var.redis_password
  }

  set {
    name  = "updateStrategy.type"
    value = "Recreate"
  }

  set {
    name  = "service.type"
    value = "ClusterIP"
  }

  lifecycle {
    ignore_changes = [
      set_sensitive, # This ignores changes to all set_sensitive configurations
    ]
  }
}
