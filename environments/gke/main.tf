module "defaults" {
  source = "../../modules/defaults"
}

locals {
  dns_enabled      = var.enable_dns
  dns_child_domain = local.dns_enabled ? "${var.dns_child_zone_name}.${var.dns_parent_domain}" : ""
}

# One shared child zone for the entire environment (not per-cluster). This environment only
# ever manages its own cloud's native DNS (Cloud DNS) -- it never reaches into another
# provider. The primary (Route53) zone's NS delegation record pointing at this zone's own
# name servers (output below) is created by the separate, cloud-neutral
# environments/dns-delegation, not here.
resource "google_dns_managed_zone" "child" {
  count       = local.dns_enabled ? 1 : 0
  name        = var.dns_child_zone_name
  dns_name    = "${local.dns_child_domain}."
  description = "Agentic field kit child zone (delegated to from an external Route53 parent)"
}

module "gke" {
  source = "../../modules/gke"
  count  = var.gke_cluster_count

  enable_gke                  = true
  gke_project                 = var.gke_project
  gke_region                  = var.gke_region
  gke_cluster_name            = var.gke_cluster_name
  gke_cluster_index           = count.index + 1
  enable_gke_regional_cluster = false
  gke_node_pool_size          = var.gke_node_pool_size
  gke_node_type               = var.gke_node_type
  enable_gke_hpa              = true
  kubernetes_version          = coalesce(var.kubernetes_version, module.defaults.kubernetes_version)

  gke_release_channel          = var.gke_release_channel
  gke_enable_beta_apis         = var.gke_enable_beta_apis
  gke_enable_workload_identity = var.gke_enable_workload_identity

  gke_disable_filestore_csi         = var.gke_disable_filestore_csi
  gke_node_auto_upgrade             = var.gke_node_auto_upgrade
  gke_restrict_control_plane_access = var.gke_restrict_control_plane_access

  enable_workload_storage        = var.enable_workload_storage
  workload_storage_ksa_namespace = var.workload_storage_ksa_namespace
  workload_storage_ksa_name      = var.workload_storage_ksa_name

  owner   = var.owner
  team    = var.team
  purpose = var.purpose
}
