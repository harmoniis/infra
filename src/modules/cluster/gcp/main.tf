terraform {
  required_providers {

    google = {
      source  = "hashicorp/google"
      version = "5.0.0"
    }

  }
}

resource "google_container_cluster" "cluster" {
  name     = "${var.cluster_name_prefix}-${var.region}"
  location = var.region
  project  = var.project_id

  enable_autopilot = true

  deletion_protection = false

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = ""
    services_ipv4_cidr_block = ""
  }

  network    = var.network
  subnetwork = var.subnetwork

  master_auth {
    client_certificate_config {
      issue_client_certificate = true
    }
  }
}

/*
  // Spot Node Pool
  node_config {
    spot = true

    taint {
      key    = "cloud.google.com/gke-spot"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }

  initial_node_count       = 1
  remove_default_node_pool = true 
  */


/* 
resource "google_container_node_pool" "preemptible_pool" {
  name       = "preemptible-pool"
  location   = var.region
  cluster    = google_container_cluster.cluster.name
  project    = var.project_id
  node_count = 1

  node_config {
    preemptible = true

    taint {
      key    = "cloud.google.com/gke-preemptible"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }
}

resource "google_container_node_pool" "standard_pool" {
  name       = "standard-pool"
  location   = var.region
  cluster    = google_container_cluster.cluster.name
  project    = var.project_id
  node_count = 1

  node_config {
    machine_type = "e2-standard-2"
  }
}


resource "google_container_node_pool" "gpu_spot_pool" {
  name       = "gpu-spot-pool"
  location   = var.region
  cluster    = google_container_cluster.cluster.name
  project    = var.project_id
  node_count = 1

  node_config {
    machine_type = "n1-standard-4" // Adjust based on your needs

    preemptible = true // This makes the node pool Spot (preemptible)

    guest_accelerator {
      type  = "nvidia-tesla-k80" // Type of GPU
      count = 1                  // Number of GPUs per node
    }

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    // Add necessary taints if you want to reserve this pool only for GPU workloads.
    taint {
      key    = "nvidia.com/gpu"
      value  = "present"
      effect = "NO_SCHEDULE"
    }

    // Add a taint to ensure that GKE doesn't schedule critical workloads onto Spot VMs
    taint {
      key    = "cloud.google.com/gke-preemptible"
      value  = "true"
      effect = "NO_SCHEDULE"
    }
  }
} */



