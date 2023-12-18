variable "chart_version" {
  type = string
  description = "cert-manager helm chart version"
  default = "v1.13.1"
  
}

variable "oci_chart_version" {

  type = string
  description = "origin-ca-issuer helm chart version"
  default = "v0.6.1"
}

variable "issuer_prefix" {
  type = string
  description = "issuer prefix"
  default = "letsencrypt"
}

variable "domain" {
  type = string
  description = "domain name"
}

variable "class" {
  type = string
  description = "ingress class"
  default = "nginx"
  
}

variable "origin-ca-key" {
  type = string
  description = "Cloudflare origin-ca-key"
}

variable "env" {
  type = string
  description = "environment(dev, stage, prod) for the Origin CA issuer"
  
}