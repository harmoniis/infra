terraform {
  required_providers {

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.16.0"
    }
  }
}

# DNS settings 
resource "cloudflare_record" "ingress" {
  zone_id = var.cf_zone_id
  name    = var.cf_zone
  value   = var.value
  type    = var.type
  proxied = var.proxied
}
