module "rosa" {
  source = "../../modules/rosa"
  count  = var.rosa_cluster_count

  owner                         = var.owner
  team                          = var.team
  purpose                       = var.purpose
  rosa_region                   = var.rosa_region
  rosa_cluster_name             = var.rosa_cluster_name
  rosa_cluster_index            = count.index + 1
  rosa_openshift_version        = var.rosa_openshift_version
  rosa_compute_machine_type     = var.rosa_compute_machine_type
  rosa_replicas                 = var.rosa_replicas
  rosa_availability_zones_count = var.rosa_availability_zones_count
}
