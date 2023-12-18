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

resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace
  }
}

resource "helm_release" "argocd" {

  name       = "${var.name}-argocd"
  chart      = "argo-cd"
  repository = "https://argoproj.github.io/argo-helm"
  namespace  = var.namespace

  values = [
    <<EOF
    configs:
      secret:
        github-shared-secret: ${var.github_shared_secret}
        argocdServerAdminPassword: ${var.argocd_admin_pass_hash}
    controller:
      replicas: 1
    redis:
      resources:
        limits:
          cpu: 200m
          memory: 128Mi
        requests:
          cpu: 100m
          memory: 64Mi
    server:
      replicas: 1
      autoscaling:
        enabled: true
        minReplicas: 1
    repoServer:
      replicas: 1
      autoscaling:
        enabled: true
        minReplicas: 2
    dex:
      resources:
        limits:
          cpu: 50m
          memory: 64Mi
        requests:
          cpu: 10m
          memory: 32Mi
    EOF
  ]
}
