locals {
  count = var.enable_gke ? 1 : 0
}

# Random identifier for cluster name suffix
resource "random_id" "gke_cluster_name_suffix" {
  count = local.count

  byte_length = 6
}

# Get the current workstation public IP
data "http" "workstation_public_ip" {
  count = local.count

  url = "http://ipv4.icanhazip.com"
}

# Get all the available zones for the given region
data "google_compute_zones" "gke_available_zones" {
  count = local.count

  project = var.gke_project
  region  = var.gke_region
  status  = "UP"
}

# Get the latest version available in the computed zone
data "google_container_engine_versions" "gke_current_k8s_version" {
  count = local.count

  project  = var.gke_project
  location = data.google_compute_zones.gke_available_zones[count.index].names[0]
}

locals {
  provider_type       = "gke"
  gke_name_suffix_hex = try(random_id.gke_cluster_name_suffix.0.hex, "")
  # GCP cluster/node-pool names are capped at 40 chars and node_pool_name appends "-node"
  # (5 chars). Reserve room for owner, the random suffix, the index and their hyphens, then
  # truncate only the user-supplied gke_cluster_name to whatever's left.
  gke_name_overhead  = length(var.owner) + length(local.gke_name_suffix_hex) + length(tostring(var.gke_cluster_index)) + 8
  gke_name_budget    = max(40 - local.gke_name_overhead, 6)
  cluster_name       = try(join("-", [format("%v-%v-%v", var.owner, substr(var.gke_cluster_name, 0, local.gke_name_budget), local.gke_name_suffix_hex), var.gke_cluster_index]), "")
  kubeconfig_context = try(format("%v-%v", local.provider_type, local.cluster_name), "")
  node_pool_name     = try(format("%v-node", local.cluster_name), "")
  # GCP service account IDs are capped at 30 chars, cluster_name alone can exceed that.
  gke_service_account_id  = "${trimsuffix(substr(local.cluster_name, 0, 26), "-")}-sa"
  k8s_version             = try(tostring(try(var.kubernetes_version, data.google_container_engine_versions.gke_current_k8s_version.0.release_channel_default_version["STABLE"])), "")
  workstation_public_cidr = try("${chomp(data.http.workstation_public_ip.0.response_body)}/32", "")
  all_service_account_roles = concat(var.gke_serviceaccount_roles, [
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer"
  ])
  labels = merge(
    {
      "provider"   = local.provider_type
      "cluster"    = local.cluster_name
      "owner"      = var.owner
      "team"       = var.team
      "purpose"    = var.purpose
      "managed-by" = "terraform"
    },
    var.extra_labels
  )
  tags = concat([
    "${local.cluster_name}",
    var.owner,
    var.team,
    var.purpose,
    "terraform"
  ], var.extra_tags)
}

resource "google_service_account" "gke_service_account" {
  count = local.count

  project      = var.gke_project
  account_id   = local.gke_service_account_id
  display_name = var.gke_serviceaccount_description
}

resource "google_project_iam_member" "gke_service_account_roles" {
  for_each = var.enable_gke ? toset(local.all_service_account_roles) : []
  project  = var.gke_project
  role     = each.value
  member   = "serviceAccount:${google_service_account.gke_service_account.0.email}"
}

resource "google_container_cluster" "gke_master" {
  count = local.count

  project            = var.gke_project
  name               = local.cluster_name
  location           = var.enable_gke_regional_cluster ? var.gke_region : data.google_compute_zones.gke_available_zones[count.index].names[0]
  min_master_version = local.k8s_version

  # Disposable demo clusters -- the provider's own default (true) would block the
  # provision/destroy cycles this tool is built around.
  deletion_protection = false

  # Remove the default node pool once provisioned since we manage this separately (its version
  # is set on google_container_node_pool.gke_workers below). node_version can't be set here
  # when remove_default_node_pool is true -- there's no default pool left for it to apply to.
  remove_default_node_pool = true
  initial_node_count       = 1

  node_config {
    service_account = try(google_service_account.gke_service_account.0.email, var.gke_serviceaccount)
  }

  release_channel {
    channel = "STABLE"
  }

  addons_config {
    # L7 load balancing (Disabled)
    http_load_balancing {
      disabled = false
    }

    # Enabling horizontal pod autoscaling
    horizontal_pod_autoscaling {
      disabled = !var.enable_gke_hpa
    }
  }

  master_authorized_networks_config {
    cidr_blocks {
      display_name = "gke-admin"
      cidr_block   = local.workstation_public_cidr
    }
  }

  resource_labels = { for key, value in local.labels : lower(key) => lower(value) }

  # node_config only ever describes the throwaway default pool removed above; once it's gone,
  # the API stops reporting it consistently and the provider sees spurious drift that would
  # force a full cluster replacement. Real node pools are managed via gke_workers below.
  lifecycle {
    ignore_changes = [node_config]
  }
}

resource "google_container_node_pool" "gke_workers" {
  count = local.count

  project    = var.gke_project
  name       = local.node_pool_name
  location   = var.enable_gke_regional_cluster ? var.gke_region : data.google_compute_zones.gke_available_zones[count.index].names[0]
  cluster    = google_container_cluster.gke_master[count.index].name
  node_count = var.gke_node_pool_size
  version    = local.k8s_version

  node_config {
    image_type      = var.gke_node_image_type
    preemptible     = var.enable_gke_preemptible
    machine_type    = var.gke_node_type
    service_account = var.gke_serviceaccount

    metadata = {
      disable-legacy-endpoints = "true"
    }

    oauth_scopes = var.gke_oauth_scopes
    tags         = local.tags
    labels       = local.labels
  }
}

data "google_client_config" "gke_config" {}

locals {
  kubeconfig_rendered = local.count > 0 ? templatefile("${path.module}/files/kubeconfig-template.tpl", {
    context                = local.kubeconfig_context
    endpoint               = google_container_cluster.gke_master.0.endpoint
    cluster_ca_certificate = google_container_cluster.gke_master.0.master_auth.0.cluster_ca_certificate
  }) : ""
}

resource "local_file" "kubeconfig_tpl_renderer" {
  count = local.count

  content  = local.kubeconfig_rendered
  filename = "${path.module}/output/kubeconfig-gke-${var.gke_cluster_index}"
}
