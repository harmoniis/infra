# Copyright (c) 2023 George Poenaru
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

variable "domain" {
  type = string
  description = "domain name"
}

variable "class" {
  type = string
  description = "ingress class"
  default = "nginx" 
}