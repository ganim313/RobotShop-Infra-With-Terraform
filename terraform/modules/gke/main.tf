
resource "google_service_account" "gke_nodepool_sa" {
  project      = var.gcp_project_id
  account_id   = "gke-nodepool-sa"
  display_name = "GKE Nodepool Service Account"
}

resource "google_project_iam_member" "gke_nodepool_sa_logging" {
  project = var.gcp_project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_nodepool_sa.email}"
}

resource "google_project_iam_member" "gke_nodepool_sa_monitoring" {
  project = var.gcp_project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_nodepool_sa.email}"
}

resource "google_project_iam_member" "gke_nodepool_sa_viewer" {
  project = var.gcp_project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_nodepool_sa.email}"
}

resource "google_container_cluster" "primary" {
  name               = var.cluster_name
  location           = var.gcp_region
  network            = var.vpc_id
  subnetwork         = var.private_subnet_id

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }
  deletion_protection = false

  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "10.0.2.0/24"
      display_name = "Private subnet"
    }
    cidr_blocks {
      cidr_block   = "10.1.0.0/16"
      display_name = "Pods"
    }
    cidr_blocks {
      cidr_block   = "10.2.0.0/20"
      display_name = "Services"
    }
  }

  addons_config {
    gcp_filestore_csi_driver_config {
      enabled = true
    }
    gce_persistent_disk_csi_driver_config {
      enabled = true
    }
  }

  node_pool {
    name       = "default-pool"
    initial_node_count = 1
    autoscaling {
      min_node_count = 1
      max_node_count = 3
    }
    node_config {
      disk_size_gb = 80
      service_account = google_service_account.gke_nodepool_sa.email
      oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform"
      ]
    }
  }
}
