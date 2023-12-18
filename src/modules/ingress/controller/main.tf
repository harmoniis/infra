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

# Create a namespace for the Ingress controller
resource "kubernetes_namespace" "ingress-nginx" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "ingress-nginx" {

  name = "ingress-nginx"

  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"

  namespace = kubernetes_namespace.ingress-nginx.metadata[0].name

  set {
    name  = "rbac.create"
    value = "true"
  }

  set {
    name  = "controller.admissionWebhooks.certManager.enabled"
    value = "true"
  }

  set {
    name  = "controller.ingressClassResource.controllerValue"
    value = "k8s.io/ingress-nginx"
  }
  set {
    name  = "controller.ingressClassResource.enabled"
    value = true
  }
  set {
    name  = "controller.ingressClassResource.name"
    value = "nginx"
  }

  set {
    name  = "controller.ingressClassResource.default"
    value = true
  }
  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
  set {
    name  = "controller.config.large-client-header-buffers"
    value = "4 8k"
  }

  set {
    name  = "controller.config.keepalive_requests"
    value = "1000"
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "ingress-nginx"
  }

  set {
    name  = "controller.serviceAccount.create"
    value = true
  }

  timeout = 600

}
