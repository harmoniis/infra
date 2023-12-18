variable "namespace" {
  type    = string
  default = "database"
}

variable "storage" {
  type = string
}

variable "name" {
  type    = string
  default = "fdb"
}

variable "tag" {
  type    = string
  default = "7.1.26"
}

variable "datacenters" {
  type    = list(string)  
}
