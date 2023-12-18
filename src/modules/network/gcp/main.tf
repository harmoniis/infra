# Create the GCP VPC network.
/*resource "google_compute_network" "network" {
  name                    = var.network_name
  auto_create_subnetworks = false
}*/

terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.0.0"
    }
  }
}


data "google_compute_network" "network" {
  name    = var.network_name
  project = var.project_id
}

# Create subnetworks in specified regions.
resource "google_compute_subnetwork" "cluster" {

  name          = "${var.network_name}-cluster-${var.region}"
  ip_cidr_range = var.cluster_cidr_range
  region        = var.region
  network       = data.google_compute_network.network.self_link
}

# Create bastion subnet in bastion region.
/* resource "google_compute_subnetwork" "bastion" {
  name          = "${var.network_name}-bastion"
  ip_cidr_range = var.bastion_cidr_range
  region        = var.region
  network       = google_compute_network.network.self_link
}*/