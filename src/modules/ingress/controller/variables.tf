# Copyright (c) 2023 George Poenaru
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

variable "issuer_name" {
  type = string
  description = "cert-manager issuer name for root certificate"
}

variable "namespace" {
  type = string
  description = "Nginx Controller namespace"
  default = "ingress-nginx"
}