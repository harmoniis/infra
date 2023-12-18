output "gcp_cluster_host" {
  value = try(module.region[0].gcp_cluster_host, "null")
}

output "gcp_cluster_name" {
  value = try(module.region[0].gcp_cluster_name, "null")
}

output "region" {
  value = var.region
}

output "gcp_cluster_project_id" {
  value = try(module.region[0].gcp_cluster_project_id, "null")
}

output "do_cluster_id" {
  value = try(module.region[0].do_cluster_id, "null")
}

output "do_cluster_urn" {
  value = try(module.region[0].do_cluster_urn, "null")
}

output "do_cluster_host" {
  value = try(module.region[0].do_cluster_host, "null")
}

output "tunnel_id" {
  value = try(cloudflare_tunnel.tunnel[0].id, "null")
}

output "tunnel_name" {
  value = try(cloudflare_tunnel.tunnel[0].name, "null")
}

output "tunnel_deployed" {
  value = length(cloudflare_tunnel.tunnel) > 0 ? true : false
}