variable "env_name" {
  type = string
}
variable "region" {
  type = string
}
variable "cluster_name_prefix" {
  type = string
}
variable "network_id" {
  type = string
}
variable "release" {
  type    = string
  default = "1.28.2-do.0"
}
variable "droplet_size" {
  type    = string
  default = "s-2vcpu-4gb"
}
