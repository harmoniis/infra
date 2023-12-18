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

    helm = {
      source  = "hashicorp/helm"
      version = "2.11.0"
    }
  }
}

resource "kubernetes_deployment" "health_checker_deployment" {
  metadata {
    name = "health-checker-deployment"
    namespace = var.namespace
    labels = {
      app = "health-checker"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "health-checker"
      }
    }

    template {
      metadata {
        labels = {
          app = "health-checker"
        }
      }

      spec {
        container {
          image = "harmoniqpunk/health_checker:latest"
          name  = "health-checker"

          port {
            container_port = 8080
          }
        }
      }
    }
  }
}

resource "kubernetes_service" "health_checker_service" {
  metadata {
    name = "health-checker-service"
    namespace = var.namespace
  }

  spec {
    selector = {
      app = "health-checker"
    }

    port {
      port        = 80
      target_port = 8080
    }

    type = "ClusterIP"
  }
}