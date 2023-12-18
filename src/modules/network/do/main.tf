terraform {
  required_providers {

    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }

  }
}


resource "digitalocean_vpc" "vpc" {
  name = var.network_name
  region      = var.region
  description = "${var.network_name} for K8S Cluster"
}