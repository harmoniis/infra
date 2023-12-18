# Define the module inputs.
variable "network_name" {
  type        = string
  description = "The name of the VPC network to create."
}

variable "region" {
  type        = string
  description = "The region to create subnetworks in."
}

variable "cluster_cidr_range" {
  type        = string
  description = "The CIDR block for the subnetwork."
}

variable "project_id" {
  type        = string
  description = "The project ID to create the VPC network in."
}

/* variable "bastion_cidr_range" {
  type        = string
  description = "The IP range for the bastion subnet in CIDR notation."
} */