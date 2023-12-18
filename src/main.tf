# Define the required Terraform providers and their versions
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "4.16.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "5.0.0"
    }
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    kubectl = {
      source  = "alekc/kubectl"
      version = ">= 2.0.2"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.23.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "2.11.0"
    }
    github = {
      source  = "integrations/github"
      version = "5.40.0"
    }
  }
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.gcp_project_id
}

# Configure the DigitalOcean Provider
provider "digitalocean" {
  token = var.do_token
}


# Configure the Kubectl Provider
provider "kubectl" {
  config_path    = "~/.kube/config"
  config_context = "${var.cloud}-${var.region}"
}

# Configure the Kubernetes Provider
provider "kubernetes" {
  config_path    = "~/.kube/config"
  config_context = "${var.cloud}-${var.region}"
}

# Configure the Helm Provider
provider "helm" {
  kubernetes {
    config_path    = "~/.kube/config"
    config_context = "${var.cloud}-${var.region}"
  }
}

# Configure the Cloudflare Provider
provider "cloudflare" {
  api_token = var.cf_token
}

# Configure the GitHub Provider
provider "github" {
  token = var.github_token
}

locals {

  lb_name         = var.env == "prod" ? var.domain : "${var.env}.${var.domain}"
  origins         = jsondecode("${var.origins}")
  origins_keys    = sort(keys(local.origins))
  origins_domains = [for origin in flatten(values(local.origins)) : format("%s-${var.env}.${var.domain}", origin)]
  workspaces      = concat(flatten(values(local.origins)), ["global"])
}

# Define data source for Terraform remote state
data "terraform_remote_state" "state" {
  for_each = toset(local.workspaces)

  backend = "gcs"
  config = {
    bucket    = "${var.project_name}-tf-state"
    prefix    = "${var.env}/${var.project_name}.tfstate"
  }
  workspace = each.value
}


resource "google_compute_network" "vpc" {
  count = var.cloud == "gcp" ? 1 : 0

  name                    = "vpc-${var.env}"
  auto_create_subnetworks = false
}

data "cloudflare_record" "lookup" {
  for_each = terraform.workspace == "global" ? toset(local.origins_domains) : []

  zone_id  = var.cf_zone_id
  hostname = each.value
}


module "region" {
  source = "./modules/region/"
  count  = terraform.workspace != "global" ? 1 : 0

  env                         = var.env
  region                      = var.region
  cloud                       = var.cloud
  domain                      = var.domain
  gcp_project_id              = var.gcp_project_id
  deployment_service_account  = var.deployment_service_account
  cluster_name_prefix         = var.cluster_name_prefix
  cf_account_id               = var.cf_account_id
  cf_zone_id                  = var.cf_zone_id
  cf_token                    = var.cf_token
  cf_origin_ca_key            = var.cf_origin_ca_key
  github_token                = var.github_token
  argocd_admin_password       = var.argocd_admin_password
  argocd_admin_pass_hash      = var.argocd_admin_pass_hash
  argocd_github_shared_secret = var.argocd_github_shared_secret
  do_token                    = var.do_token
  redis_password              = var.redis_password
  fdb_storage_size            = var.fdb_storage_size
  tunnel_id = var.tunnel_id
  tunnel_name = var.tunnel_name
  tunnel_secret = var.tunnel_secret
  origins = flatten(values(local.origins))

  depends_on = [google_compute_network.vpc]
}


resource "cloudflare_load_balancer_monitor" "default" {
  count = terraform.workspace == "global" ? 1 : 0

  account_id     = var.cf_account_id
  type           = "https"
  expected_body  = "alive"
  expected_codes = "2xx"
  method         = "GET"
  timeout        = 7
  path           = "/health"
  interval       = 60
  retries        = 5
  description    = "${var.domain} https load balancer"
  header {
    header = "Host"
    values = [var.domain]
  }
  allow_insecure   = false
  follow_redirects = true
  probe_zone       = var.domain
}


resource "cloudflare_load_balancer_pool" "default" {
  for_each = terraform.workspace == "global" ? local.origins : {}

  account_id = var.cf_account_id
  name       = "${each.key}-${var.env}-pool"
  dynamic "origins" {
    for_each = each.value
    content {
      name    = "${origins.value}-${var.env}"
      address = data.cloudflare_record.lookup["${origins.value}-${var.env}.${var.domain}"].value
      enabled = true
      header {
        header = "Host"
        values = ["${origins.value}-${var.env}.${var.domain}"]
      }
    }
  }

  notification_email = "admin@${var.domain}"
  minimum_origins    = 1
  monitor            = cloudflare_load_balancer_monitor.default[0].id


  check_regions = [each.key]
  origin_steering {
    policy = "random"
  }
}

resource "cloudflare_load_balancer" "lb" {
  count = terraform.workspace == "global" ? 1 : 0

  zone_id          = var.cf_zone_id
  name             = local.lb_name
  fallback_pool_id = cloudflare_load_balancer_pool.default[local.origins_keys[0]].id
  default_pool_ids = [for key in local.origins_keys : cloudflare_load_balancer_pool.default[key].id]
  description      = "${var.project_name} load balancer for ${var.env} environment"
  proxied          = true
  steering_policy  = "geo"
  session_affinity = "ip_cookie"

  # If you use geo steering, you must specify a region pool for each region.
  dynamic "region_pools" {
    for_each = local.origins_keys
    content {
      region   = region_pools.value
      pool_ids = [cloudflare_load_balancer_pool.default[region_pools.value].id]
    }

  }
}

# Create the tunnel for inter cluster communication
resource "cloudflare_tunnel" "tunnel" {
  count = terraform.workspace == "global" ? 1 : 0

  account_id = var.cf_account_id
  name       = "${terraform.workspace}-${var.project_name}-${var.env}"
  secret     = base64encode(var.tunnel_secret)
}

/*
# Create databases 
module "database" {
  source = "./modules/database/"

  redis_password   = var.redis_password
  fdb_storage_size = var.fdb_storage_size

  depends_on = [module.cluster]
}

# Creat a namespace for the DNS placeholder service and ingress
resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
  depends_on = [module.cluster]
}


*/
