variable "domain" {
  type = string
}
variable "service" {
  type = string
}
variable "namespace" {
  type = string
}

variable "create_namespace" {
  type    = bool
  default = false
} 
variable "path" {
  type    = string
  default = "/"
}
variable "path_type" {
  type    = string
  default = "Prefix"
}

variable "port" {
  default = 80
}

variable "annotations" {
  type    = map(string)
  default = {}
}

variable "class" {
  type = string
}

variable "issuer_name" {
  type = string 
}
