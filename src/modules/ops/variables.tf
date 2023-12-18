variable "name" {
  description = "The name of the Helm release"
  type        = string
}

variable "namespace" {
  description = "The Kubernetes namespace where the Helm release will be deployed"
  type        = string
}

variable "argocd_admin_pass_hash" {
  description = "The password for the ArgoCD admin user"
  type        = string
}

variable "github_shared_secret" {
  description = "The shared secret for the GitHub webhook"
  type        = string
}
