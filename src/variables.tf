variable "project_name" {
  type = string
}

variable "env" {
  type = string
}

variable "region" {
  type = string
  default = "none"
}

variable "cloud" {
  type = string
  default = "none"
}

variable "origins" {
  type = string
}

variable "domain" {
  type = string
}

variable "gcp_project_id" {
  type = string
}

variable "deployment_service_account" {
  type = string
}

variable "cluster_name_prefix" {
  type = string
}

variable "cf_account_id" {
  type = string
}

variable "cf_zone_id" {
  type = string
}

variable "cf_token" {
  type = string
}

variable "cf_origin_ca_key" {
  type = string
}

variable "tunnel_id" {
  type = string
  default = "null"
  
}

variable "tunnel_name" {
  type = string
  default = "null"
}

variable "tunnel_secret" {
  type = string
}

variable "github_token" {
  type = string
}

variable "argocd_admin_password" {
  description = "The password for the ArgoCD admin user"
  type        = string
  sensitive   = true
}

variable "argocd_admin_pass_hash" {
  description = "The password for the ArgoCD admin user"
  type        = string
}



variable "argocd_github_shared_secret" {
  description = "The shared secret for the ArgoCD GitHub webhook"
  type        = string
}

variable "do_token" {
  type = string
}

variable "create_gcp" {
  type    = bool
  default = false
}

variable "create_do" {
  type    = bool
  default = false
}


variable "redis_password" {
  description = "The password for the Redis instance."
  type        = string
  sensitive   = true
}

variable "fdb_storage_size" {
  description = "The size of the FoundationDB database"
  type        = string
}

/*
variable "tunnel_id" {
  type = string
}

variable "tunnel_name" {
  type = string
} */
