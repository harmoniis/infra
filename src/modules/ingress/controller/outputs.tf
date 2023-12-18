# Copyright (c) 2023 George Poenaru
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

output "ingress_name" {
  value = helm_release.ingress-nginx.name
}

output "namespace" {
  value = kubernetes_namespace.ingress-nginx.metadata[0].name
  
}