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

resource "kubernetes_ingress_v1" "ingress" {
  wait_for_load_balancer = true
  metadata {
    name      = "${kubernetes_service.lb-resolve.metadata[0].name}-ingress"
  }
  spec {
    ingress_class_name = var.class

    rule {
      host = var.domain
      http {
        path {
          path      = "/api/v1/config/lb/resolve/"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.lb-resolve.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}

# Create a placeholder service used to fetch the load balancer IP for reserving the DNS record
resource "kubernetes_service" "lb-resolve" {
  metadata {
    name      = "lb-resolve"
  }
  spec {
    port {
      port        = 80
      target_port = 80
    }
  }
}