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
  }
}

/*
  Annotation example ClusterIssuer ACME LetsEncrypt


  annotations = {
    "cert-manager.io/cluster-issuer"               = "${module.cert.issuer_prefix}-${local.issuer_postfix}"
    "kubernetes.io/ingress.class"                  = "${local.ingress_class}"
    "nginx.ingress.kubernetes.io/ssl-passthrough"  = true
    "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
  }

  Annotation example Issuer Cloudflare Origin CA

  annotations = {
    "cert-manager.io/issuer-group"                 = "cert-manager.k8s.cloudflare.com"
    "cert-manager.io/issuer-kind"                  = "OriginIssuer"
    "cert-manager.io/issuer"                       = "origin-ca-${local.issuer_postfix}"
    "kubernetes.io/ingress.class"                  = "${local.ingress_class}"
    "nginx.ingress.kubernetes.io/ssl-passthrough"  = true
    "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
  }
  
  */


# Create namespace only if it doesn't exist
resource "kubernetes_namespace" "namespace" {
  count = var.create_namespace ? 1 : 0
  metadata {
    name = var.namespace
  }
}

resource "kubernetes_ingress_v1" "ingress" {
  wait_for_load_balancer = true
  metadata {
    name      = "${var.service}-ingress"
    namespace = var.namespace
    annotations = merge(var.annotations, {
      "ingress.kubernetes.io/force-ssl-redirect" = true
    })
  }
  spec {
    ingress_class_name = var.class

    rule {
      host = var.domain
      http {
        path {
          path      = var.path
          path_type = var.path_type
          backend {
            service {
              name = var.service
              port {
                number = var.port
              }
            }
          }
        }
      }
    }
    tls {
      hosts       = [var.domain]
      secret_name = "ingress-tls"
    }
  }
}

