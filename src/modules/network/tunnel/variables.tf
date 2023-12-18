# Copyright (c) 2023 George Poenaru
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

variable "cf_account_id" {
  type = string
}

variable "tunnel_id" {
  type = string
}

variable "tunnel_name" {
  type = string
}

variable "tunnel_secret" {
  type = string
}

variable "namespace" {
  type = string
}

variable "service" {
  type = string
}

variable "port" {
  type = string
}

variable "hostname" {
  type = string
}