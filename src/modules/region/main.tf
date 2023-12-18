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

# Define local variables
locals {
  cluster = {
    region         = var.region
    gcp_name       = module.cluster.gke_name
    gcp_host       = module.cluster.gke_host
    gcp_project_id = module.cluster.gke_cluster_project_id
    do_cluster_id  = module.cluster.do_cluster_id
    do_cluster_urn = module.cluster.do_cluster_urn
    do_host        = module.cluster.do_host
  }

  issuer_postfix = var.env == "prod" ? "prod" : "stage"
  ingress_class  = "nginx"
  apex           = var.env == "prod" ? "@" : "${var.env}"
  tunnel_services = [for origin in var.origins : format("fdb-%s-svc", origin)]
}

# Define a random_integer resource for cluster
resource "random_integer" "cluster" {
  min  = 10
  max  = 100
  seed = "${var.region}-${var.env}-cluster"
}

# Network module
module "network" {
  source = "../network/"

  env_name               = var.env
  gcp_cluster_cidr_range = tostring(random_integer.cluster.result)
  gcp_project_id         = var.gcp_project_id
  region                 = var.region
  cloud                  = var.cloud
}

# Cluster module
module "cluster" {
  source = "../cluster/"

  env_name            = var.env
  cluster_name_prefix = var.cluster_name_prefix
  gcp_project_id      = var.gcp_project_id
  gcp_network         = module.network.gcp_network_name
  gcp_cluster_subnet  = module.network.gcp_cluster_subnet
  region              = var.region
  do_network_id       = module.network.do_network_id
  cloud               = var.cloud
}

# Add cluster users. Default read only
data "external" "kubeconfig_data" {
  program = ["bash", "${path.module}/get_kubeconfig_data.sh"]

  depends_on = [module.cluster]
}

module "readonly-user" {
  source = "../user/"

  namespace              = "default"
  sa_name                = "readonly-user"
  role_name              = "readonly-role"
  role_binding_name      = "readonly-role-binding"
  kubeconfig_path        = "./readonly-kubeconfig.yaml"
  cluster_ca_certificate = data.external.kubeconfig_data.result["ca_certificate"]
  kube_server            = data.external.kubeconfig_data.result["api_server"]
  kube_cluster_name      = data.external.kubeconfig_data.result["cluster_name"]
  kube_context_name      = "readonly-context"

  verbs     = ["get", "list"]                                                                                        # Customize verbs here
  resources = ["pods", "services", "configmaps", "secrets", "deployments", "replicasets", "pvc", "pvs", "endpoints"] # Default resources

  depends_on = [module.cluster]
}


# Cert-manager module
module "cert" {
  source = "../cert/"

  domain        = var.domain
  env           = local.issuer_postfix
  origin-ca-key = var.cf_origin_ca_key
  class         = "nginx"
  depends_on    = [module.cluster]
}


# Ingress controller module (Nginx)
module "ingress-controller" {
  source = "../ingress/controller/"

  issuer_name = "${module.cert.issuer_prefix}-${local.issuer_postfix}"
  depends_on  = [module.cert]
}

data "kubernetes_service" "ingress-controller" {
  metadata {
    name      = "${module.ingress-controller.ingress_name}-controller"
    namespace = module.ingress-controller.namespace
  }

  depends_on = [module.ingress-controller]
}

# Continuous Deployment DNS module
module "region-dns-record" {
  source = "../dns/"

  cf_zone_id = var.cf_zone_id
  cf_zone    = "${var.cloud}-${var.region}-${var.env}"
  value      = data.kubernetes_service.ingress-controller.status[0].load_balancer[0].ingress[0].ip

  depends_on = [data.kubernetes_service.ingress-controller]
}


# __________________OPS________________________________

# Ops module (GitOps - ArgoCD and other operations)
module "ops" {
  source = "../ops/"

  name                   = "ops"
  namespace              = "ops"
  argocd_admin_pass_hash = var.argocd_admin_pass_hash
  github_shared_secret   = var.argocd_github_shared_secret

  depends_on = [data.kubernetes_service.ingress-controller]
}

# Deploy Origin CA Issuer in Ops namespace
module "ops-origin-ca-issuer" {
  source = "../cert/issuer/"

  env           = local.issuer_postfix
  namespace     = module.ops.namespace
  origin-ca-key = var.cf_origin_ca_key

  depends_on = [module.ops]
}

# ArgoCD Ingress module
module "argocd-server-ingress" {
  source = "../ingress/endpoint/"

  domain    = "${module.region-dns-record.zone}.${var.domain}"
  service   = module.ops.argocd-service-name
  namespace = module.ops.namespace
  annotations = {
    "cert-manager.io/issuer-group"                 = "cert-manager.k8s.cloudflare.com"
    "cert-manager.io/issuer-kind"                  = "OriginIssuer"
    "cert-manager.io/issuer"                       = "origin-ca-${local.issuer_postfix}"
    "kubernetes.io/ingress.class"                  = "${local.ingress_class}"
    "nginx.ingress.kubernetes.io/ssl-passthrough"  = true
    "nginx.ingress.kubernetes.io/backend-protocol" = "HTTPS"
  }

  class       = local.ingress_class
  issuer_name = "${module.cert.issuer_prefix}-${local.issuer_postfix}"

  depends_on = [module.ops-origin-ca-issuer]
}

# Monitoring health-checker module

module "monitor" {
  source = "../monitor/"

  namespace  = module.ops.namespace
  depends_on = [module.ops]
}

module "monitor-ingress" {
  source = "../ingress/endpoint/"

  domain    = "${module.region-dns-record.zone}.${var.domain}"
  service   = module.monitor.service-name
  namespace = module.ops.namespace
  annotations = {
    "cert-manager.io/issuer-group"                 = "cert-manager.k8s.cloudflare.com"
    "cert-manager.io/issuer-kind"                  = "OriginIssuer"
    "cert-manager.io/issuer"                       = "origin-ca-${local.issuer_postfix}"
    "kubernetes.io/ingress.class"                  = "${local.ingress_class}"
    "nginx.ingress.kubernetes.io/ssl-passthrough"  = true
    "nginx.ingress.kubernetes.io/backend-protocol" = "HTTP"
  }

  path = "/health"

  class       = local.ingress_class
  issuer_name = "${module.cert.issuer_prefix}-${local.issuer_postfix}"

  depends_on = [module.monitor]
}

resource "kubernetes_namespace" "apps" {
  metadata {
    name = "apps"
  }
  depends_on = [module.cluster]
}


# Create databases 
module "database" {
  source = "../database/"

  redis_password   = var.redis_password
  fdb_storage_size = var.fdb_storage_size
  datacenters = var.origins


  depends_on = [module.cluster]
} 

module "tunnel" {
  source = "../network/tunnel/"
  count = var.tunnel_id != "null" ? 1 : 0

  namespace     = "ops"
  cf_account_id = var.cf_account_id
  service      = "fdb-${terraform.workspace}-svc"
  tunnel_name   = var.tunnel_name
  tunnel_id = var.tunnel_id
  tunnel_secret = var.tunnel_secret
  port = "4500"
  hostname = terraform.workspace

  #depends_on    = [module.database]
} 

