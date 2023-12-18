terraform {
  required_providers {

    google = {
      source  = "hashicorp/google"
      version = "5.0.0"
    }

    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }

  }
}

module "gcp_network" {
  source = "./gcp/"
  count  = var.cloud == "gcp" ? 1 : 0

  network_name       = "vpc-${var.env_name}"
  project_id         = var.gcp_project_id
  region             = var.region
  cluster_cidr_range = "10.0.${var.gcp_cluster_cidr_range}.0/24"
}

module "do_network" {
  source = "./do/"
  count  = var.cloud == "do" ? 1 : 0

  network_name = "vpc-${var.env_name}-${var.region}"
  region       = var.region
}
