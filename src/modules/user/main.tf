# Copyright (c) 2023 George Poenaru
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

resource "kubernetes_service_account" "user" {
  metadata {
    name      = var.sa_name
    namespace = var.namespace
  }
}

resource "kubernetes_role" "role" {
  metadata {
    name      = var.role_name
    namespace = var.namespace
  }

  rule {
    api_groups = [""]
    resources  = var.resources
    verbs      = var.verbs
  }
}

resource "kubernetes_role_binding" "role_binding" {
  metadata {
    name      = var.role_binding_name
    namespace = var.namespace
  }

  role_ref {
    kind     = "Role"
    name     = kubernetes_role.role.metadata[0].name
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.user.metadata[0].name
    namespace = kubernetes_service_account.user.metadata[0].namespace
  }
}


