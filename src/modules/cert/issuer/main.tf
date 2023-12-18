# Copyright (c) 2023 George Poenaru
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }

    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.2"
    }
  }
}

locals {
  issuer = <<-EOT
  apiVersion: cert-manager.k8s.cloudflare.com/v1
  kind: OriginIssuer
  metadata:
    name: origin-ca-${var.env}
    namespace: ${var.namespace}
  spec:
    requestType: OriginECC
    auth:
      serviceKeyRef:
        name: origin-ca-key
        key: key
  EOT
}
resource "kubectl_manifest" "issuer" {
  yaml_body = local.issuer

  depends_on = [kubernetes_secret.origin-ca-key]
}

resource "kubernetes_secret" "origin-ca-key" {
  metadata {
    name      = "origin-ca-key"
    namespace = var.namespace

  }

  data = {
    key = var.origin-ca-key
  }
}
