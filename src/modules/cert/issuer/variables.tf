# Copyright (c) 2023 George Poenaru
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

variable "env" {
  type = string
  default = "stage"
}

variable "namespace" {
  type = string
  default = "default"
}

variable "origin-ca-key" {
  type = string
  description = "Cloudflare Origin CA Key"
}