output "gcp_cluster_host" {
  value = module.cluster.gke_host
}

output "gcp_cluster_name" {
  value = module.cluster.gke_name
}

output "region" {
  value = local.cluster.region
}

output "gcp_cluster_project_id" {
  value = module.cluster.gke_cluster_project_id
}

output "do_cluster_id" {
  value = module.cluster.do_cluster_id
}

output "do_cluster_urn" {
  value = module.cluster.do_cluster_urn
}


output "do_cluster_host" {
  value = module.cluster.do_host

}

output "tunnel_deployed" {
   value = length(module.tunnel) > 0 ? true : false
}
