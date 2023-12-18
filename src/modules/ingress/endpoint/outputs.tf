# Copyright (c) 2023 George Poenaru
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

output "lb_ip" {
  value = kubernetes_ingress_v1.ingress.status.0.load_balancer.0.ingress.0.ip
  description = "The static IP address associated with the loadbalancer"
}