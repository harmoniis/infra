
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

# GCP Cluster
module "gke_cluster" {
  source = "./gcp/"
  count  = var.cloud == "gcp" ? 1 : 0

  project_id          = var.gcp_project_id
  region              = var.region
  cluster_name_prefix = var.cluster_name_prefix

  network    = var.gcp_network
  subnetwork = var.gcp_cluster_subnet
}

# Digital Ocean Cluster
module "do_cluster" {
  source = "./do/"
  count  = var.cloud == "do" ? 1 : 0

  env_name            = var.env_name
  region              = var.region
  cluster_name_prefix = var.cluster_name_prefix
  network_id          = var.do_network_id
}