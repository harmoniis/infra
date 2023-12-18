output "do_cluster_id" {
  value = length(module.do_cluster) > 0 ? module.do_cluster[0].cluster_id : null
}

output "do_cluster_urn" {
  value = length(module.do_cluster) > 0 ? module.do_cluster[0].cluster_urn : null
}

output "do_host" {

  value = length(module.do_cluster) > 0 ? module.do_cluster[0].host : null

}

output "gke_host" {

  value = length(module.gke_cluster) > 0 ? module.gke_cluster[0].host : null
}

output "gke_name" {

  value = length(module.gke_cluster) > 0 ? module.gke_cluster[0].name : null

}

output "gke_region" {
  value = length(module.gke_cluster) > 0 ? module.gke_cluster[0].region : null
}

output "gke_cluster_project_id" {
  value = length(module.gke_cluster) > 0 ? module.gke_cluster[0].cluster_project_id : null
}

