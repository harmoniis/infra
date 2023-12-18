# Copyright (c) 2023 George Poenaru
# 
# This software is released under the MIT License.
# https://opensource.org/licenses/MIT

terraform {
  required_providers {

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.16.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "2.11.0"
    }
  }
}

resource "cloudflare_tunnel_config" "tunnel_config" {
  account_id = var.cf_account_id
  tunnel_id  = var.tunnel_id

  config {
    warp_routing {
      enabled = false
    }
    ingress_rule {
      hostname = var.hostname
      service  = "tcp://${var.service}.${var.namespace}:${var.port}"
    }

    ingress_rule {
      service  = "tcp://${var.service}.${var.namespace}:${var.port}"
    }
  }
}


resource "helm_release" "cloudflare-tunnel" {

  name = "cloudflare-tunnel"

  repository = "https://cloudflare.github.io/helm-charts"
  chart      = "cloudflare-tunnel"

  namespace = var.namespace

  values = [<<EOF
cloudflare:
  protocol: http2
  # Your Cloudflare account number.
  account: "${var.cf_account_id}"
  # The name of the tunnel this instance will serve
  tunnelName: "${var.tunnel_name}"
  # The ID of the above tunnel.
  tunnelId: "${var.tunnel_id}"
  # The secret for the tunnel.
  secret: "${var.tunnel_secret}"
  # If true, turn on WARP routing for TCP
  enableWarp: false
  # Define ingress rules for the tunnel. See
  # https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/configuration/configuration-file/ingress
  ingress:
    - hostname: "${var.service}.${var.namespace}"
      service: "tcp://${var.service}.${var.namespace}:${var.port}"
EOF
  ]

}