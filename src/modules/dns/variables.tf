variable "cf_zone_id" {
  type = string
}

variable "cf_zone" {
  type    = string
  default = "@"
}

variable "value" {
  type = string
}

variable "proxied" {
  type    = bool
  default = true
}

variable "type" {
  type    = string
  default = "A" 
}
