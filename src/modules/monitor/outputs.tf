# Copyright (c) 2023 George Poenaru
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

output "service-name" {
  value = kubernetes_service.health_checker_service.metadata[0].name 
}