terraform {
  required_providers {

    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }

  }
}
/*
resource "digitalocean_project" "playground" {
  name        = "${var.cluster_name_prefix}-${var.env_name}"
  description = "A project to represent development resources."
  purpose     = "Kubernets cluster for ${var.env_name}"
  environment = var.env_name
} */

# Create a new container registry
resource "digitalocean_container_registry" "artifacts" {
  name                   = "${var.cluster_name_prefix}-${var.region}-registry"
  subscription_tier_slug = "basic"
  region = var.region
}
resource "digitalocean_kubernetes_cluster" "cluster" {
  name                 = "${var.cluster_name_prefix}-${var.region}"
  region               = var.region
  version              = var.release
  auto_upgrade         = false
  vpc_uuid             = var.network_id
  registry_integration = true

  node_pool {
    name       = "autoscale-worker-pool"
    size       = var.droplet_size
    auto_scale = true
    min_nodes  = 1
    max_nodes  = 5
  }
}
