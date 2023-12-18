variable "verbs" {
  description = "List of verbs/actions to be granted by the role."
  type        = list(string)
  default     = ["get", "list", "watch"]  # Default to read-only verbs
}

variable "resources" {
  description = "List of Kubernetes resources the Role should apply to."
  type        = list(string)
  default     = ["pods", "services", "configmaps", "secrets", "deployments", "replicasets", "pvc", "pvs", "endpoints"]  # Default resources
}


variable "namespace" {
  description = "The namespace in which to create the resources."
  type        = string
  default     = "default"
}

variable "sa_name" {
  description = "The name of the Service Account."
  type        = string
  default     = "readonly-user"
}

variable "role_name" {
  description = "The name of the Role."
  type        = string
  default     = "readonly-role"
}

variable "role_binding_name" {
  description = "The name of the RoleBinding."
  type        = string
  default     = "readonly-role-binding"
}

variable "kubeconfig_path" {
  description = "The path where the kubeconfig file will be saved."
  type        = string
  default     = "./readonly-kubeconfig.yaml"
}

variable "cluster_ca_certificate" {
  description = "The CA certificate for the Kubernetes cluster."
  type        = string
}

variable "kube_server" {
  description = "The Kubernetes API server URL."
  type        = string
}

variable "kube_cluster_name" {
  description = "The name of the Kubernetes cluster."
  type        = string
}

variable "kube_context_name" {
  description = "The name of the kubeconfig context."
  type        = string
}
