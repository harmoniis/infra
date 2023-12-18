# Copyright (c) 2023 George Poenaru
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

variable "namespace" {
  description = "The namespace in which to deploy Redis."
  type        = string
  default = "database"
}

variable "redis_password" {
  description = "The password for the Redis instance."
  type        = string
  sensitive = true
}

variable "fdb_storage_size" {
  description = "The size of the FoundationDB database"
  type        = string
}

variable "datacenters" {
  description = "The datacenters for data distribution."
  type        = list(string)
}