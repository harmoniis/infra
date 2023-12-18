# Copyright (c) 2023 George Poenaru
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

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

resource "kubernetes_namespace" "database" {
  metadata {
    name = var.namespace
  }
}


module "redis" {
  source         = "./redis"
  namespace      = var.namespace
  redis_password = var.redis_password

  depends_on = [kubernetes_namespace.database]
}


module "fdb" {
  source = "./fdb"

  storage    = var.fdb_storage_size
  namespace  = var.namespace
  datacenters = var.datacenters
  depends_on = [kubernetes_namespace.database]

}

/*
module "arangodb" {
  source = "./arangodb"

  namespace  = var.namespace
  depends_on = [kubernetes_namespace.database]

} */
