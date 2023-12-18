output "gcp_network_name" {
  value = length(module.gcp_network) > 0 ? module.gcp_network[0].network : null
}

output "gcp_cluster_subnet" {
  value = length(module.gcp_network) > 0 ? module.gcp_network[0].cluster_subnet : null
}

output "do_network_id" {
  value = length(module.do_network) > 0 ? module.do_network[0].id : null
}

output "do_network_urn" {
  value = length(module.do_network) > 0 ? module.do_network[0].urn : null
}
