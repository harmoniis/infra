variable "namespace" {
  description = "The namespace in which to deploy Redis."
  type        = string
}

variable "release" {

  type    = string
  default = "18.1.2"

}

variable "redis_password" {
  description = "The password for the Redis instance."
  type        = string
  sensitive = true
}
