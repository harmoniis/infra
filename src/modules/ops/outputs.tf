# Copyright (c) 2023 George Poenaru
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

output "argocd-service-name" {
  value = "${var.name}-argocd-server" 
}


output "namespace" {
  value = kubernetes_namespace.namespace.metadata[0].name
}

output "current_argocd_admin_pass_hash" {

  value = var.argocd_admin_pass_hash
  
}