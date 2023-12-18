output "host" {
  value = google_container_cluster.cluster.endpoint
}

output "name" {
  value = google_container_cluster.cluster.name
}

output "region" {
  value = google_container_cluster.cluster.location
}

output "cluster_project_id" { 
  value = var.project_id
}
  