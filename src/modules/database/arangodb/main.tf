terraform {
  required_providers {

    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.2"
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
  clone_location = "${path.module}/.gitops"
}

data "github_repository" "arangodb-operator" {
  full_name = "arangodb/kube-arangodb"
}

resource "null_resource" "clone_repo" {

  triggers = {
    always_run = "${timestamp()}"
  }

  provisioner "local-exec" {
    command = <<EOT
#!/bin/bash

# Define the repository URL and local clone location
repo_url="${data.github_repository.arangodb-operator.http_clone_url}"
local_path="${local.clone_location}"

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


resource "helm_release" "arangodb-operator" {
  name      = "db"
  namespace = var.namespace 
  chart     = "${local.clone_location}/chart/kube-arangodb"

  depends_on = [helm_release.arangodb-crd]
}

resource "helm_release" "arangodb-crd" {
  name      = "crd"
  chart     = "${local.clone_location}/chart/kube-arangodb-crd"
  namespace = "default"

  depends_on = [null_resource.clone_repo]
} 


resource "kubectl_manifest" "cluster" {
  yaml_body = file("${local.clone_location}/examples/production-cluster.yaml")

  depends_on = [helm_release.arangodb-operator]
}