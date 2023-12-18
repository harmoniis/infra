output "redis_service_name" {
  description = "The name of the Redis ClusterIP service."
  value       = helm_release.redis.name
}