# Output the network and subnetwork information for reuse.
output "network" {
  value = data.google_compute_network.network.self_link
}

output "cluster_subnet" {
  value = google_compute_subnetwork.cluster.self_link
}

/* output "bastion_subnet" {
  value = google_compute_subnetwork.bastion.self_link
}*/