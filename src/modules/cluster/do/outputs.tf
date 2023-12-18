output "cluster_id" {
  value = digitalocean_kubernetes_cluster.cluster.id
}

output "cluster_urn" {
  value = digitalocean_kubernetes_cluster.cluster.urn
}

output "host" {
  value = digitalocean_kubernetes_cluster.cluster.endpoint
}
