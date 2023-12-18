terraform {
  required_providers {

    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.2"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "2.11.0"
    }

    github = {
      source  = "integrations/github"
      version = "5.40.0"
    }
  }
}

locals {
  oci_clone_location = "${path.module}/.gitops/origin-ca"
  prod-issuer        = <<-EOT
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: ${var.issuer_prefix}-prod
    namespace: ${kubernetes_namespace.namespace.metadata[0].name}
  spec:
    acme:
      server: https://acme-v02.api.letsencrypt.org/directory
      email: admin@${var.domain}
      privateKeySecretRef:
        name: ${var.issuer_prefix}-prod
      solvers:
      - http01:
          ingress:
            ingressClassName: ${var.class}
  EOT

  staging-issuer = <<-EOT
  apiVersion: cert-manager.io/v1
  kind: ClusterIssuer
  metadata:
    name: ${var.issuer_prefix}-stage
    namespace: ${kubernetes_namespace.namespace.metadata[0].name}
  spec:
    acme:
      server: https://acme-staging-v02.api.letsencrypt.org/directory
      email: admin@${var.domain}
      privateKeySecretRef:
        name: ${var.issuer_prefix}-stage
      solvers:
      - http01:
          ingress:
            ingressClassName: ${var.class}
  EOT

}

data "github_repository" "origin_ca_issuer" {
  full_name = "cloudflare/origin-ca-issuer"
}


resource "null_resource" "clone_oci" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<EOT
#!/bin/bash

# Define the repository URL and local clone location
repo_url="${data.github_repository.origin_ca_issuer.http_clone_url}"
local_path="${local.oci_clone_location}"

# Check if the repository already exists
if [ -d "$local_path" ]; then
  # If it exists, navigate to the repository directory and pull updates
  cd "$local_path"
  git pull
else
  # If it doesn't exist, clone the repository
  git clone "$repo_url" "$local_path"
fi
EOT

    interpreter = ["bash", "-c"]
  }
}


resource "kubectl_manifest" "prod-issuer" {
  yaml_body = local.prod-issuer

  depends_on = [
    kubernetes_namespace.namespace,
    helm_release.cert_manager,
  ]
}

resource "kubectl_manifest" "staging-issuer" {
  yaml_body = local.staging-issuer

  depends_on = [
    kubernetes_namespace.namespace,
    helm_release.cert_manager,
  ]
}


resource "null_resource" "install_oci_crds" {

  depends_on = [ null_resource.clone_oci]
  provisioner "local-exec" {
    command = "kubectl apply -f ${local.oci_clone_location}/deploy/crds"
  }
}

resource "helm_release" "origin-ca-issuer" {
  depends_on = [
    null_resource.install_oci_crds,
    kubernetes_secret.origin-ca-key,
    helm_release.cert_manager
  ]
  name             = "origin-ca-issuer"
  namespace        = kubernetes_namespace.namespace.metadata[0].name
  chart            = "${local.oci_clone_location}/deploy/charts/origin-ca-issuer/."
  create_namespace = false

  values = [
    <<EOF
    originIssuer:
      name: origin-ca-${var.env}
      namespace: ${kubernetes_namespace.namespace.metadata[0].name}
      spec:
        requestType: OriginECC
        auth:
          serviceKeyRef:
            name: origin-ca-key
            key: key
    EOF
  ]
}

resource "kubernetes_secret" "origin-ca-key" {
  metadata {
    name      = "origin-ca-key"
    namespace = kubernetes_namespace.namespace.metadata[0].name

  }

  data = {
    key = var.origin-ca-key
  }
}



resource "kubernetes_namespace" "namespace" {
  metadata {
    annotations = {
      name = "cert-manager"
    }
    labels = merge(
      {
        App = "cert-manager"
      },
    )
    name = "cert-manager"
  }
}

resource "helm_release" "cert_manager" {

  depends_on = [ null_resource.install_oci_crds, kubernetes_namespace.namespace]

  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = var.chart_version
  namespace  = kubernetes_namespace.namespace.metadata[0].name

  # The set block below are examples, you would adjust or add these to match
  # the specific settings exposed by the chart that you need to configure.
  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "global.leaderElection.namespace"
    value = kubernetes_namespace.namespace.metadata[0].name
  }

  set {
    name  = "prometheus.enabled"
    value = "false"
  }

}
