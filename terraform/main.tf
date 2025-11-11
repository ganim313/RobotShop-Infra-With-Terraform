# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">= 4.0"
    }
    mongodbatlas = {
      source  = "mongodb/mongodbatlas"
      version = "~> 1.15.0"
    }
    cloudamqp = {
      source  = "cloudamqp/cloudamqp"
      version = "~> 1.20.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "mongodbatlas" {
  public_key  = var.atlas_public_key
  private_key = var.atlas_private_key
}

provider "cloudamqp" {
  apikey = var.cloudamqp_api_key
}

resource "google_project_service" "secretmanager" {
  project = var.project_id
  service = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "robot_shop_repo" {
  project       = var.project_id
  location      = var.region
  repository_id = "robot-shop-repo"
  description   = "Robot Shop container images"
  format        = "DOCKER"
}

module "vpc" {
  source              = "./modules/vpc"
  gcp_project_id      = var.project_id
  gcp_region          = var.region
  vpc_name            = "robot-shop-vpc"
  public_subnet_cidr  = "10.0.1.0/24"
  private_subnet_cidr = "10.0.2.0/24"
}

module "gke" {
  source              = "./modules/gke"
  gcp_project_id      = var.project_id
  gcp_region          = var.region
  vpc_id              = module.vpc.vpc_id
  private_subnet_id   = module.vpc.private_subnet_id
  cluster_name        = "robot-shop-gke"
}

module "databases" {
  source                              = "./modules/databases"
  gcp_project_id                      = var.project_id
  gcp_region                          = var.region
  vpc_id                              = module.vpc.vpc_id
  private_subnet_id                   = module.vpc.private_subnet_id
  private_subnet_cidr                 = module.vpc.private_subnet_cidr
  service_networking_connection_id    = module.vpc.service_networking_connection_id
  shipping_password                   = var.shipping_password
  ratings_password                    = var.ratings_password
}

# --- Bastion Host for secure access ---
resource "google_compute_instance" "bastion-host" {
  project      = var.project_id
  zone         = "${var.region}-a"
  name         = "bastion-host"
  machine_type = "e2-micro"

  boot_disk {
    initialize_params {
      image = "debian-cloud/debian-11"
    }
  }

  network_interface {
    subnetwork = module.vpc.private_subnet_id
  }

  # Use OS Login for managed SSH access or provide a key via variable.
  # This removes the insecure hardcoded SSH key.
  metadata = {
    ssh-keys = "admin:${var.bastion_ssh_pub_key}"
  }

  tags = ["ssh-iap"]
}

# --- Firewall rule to allow SSH via IAP ---
resource "google_compute_firewall" "allow-ssh-iap" {
  project = var.project_id
  name    = "allow-ssh-via-iap"
  network = module.vpc.vpc_id

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["35.235.240.0/20"] # Google's IAP IP range
  target_tags   = ["ssh-iap"]
}

# --- IAM Permission for GKE Nodes to connect to Cloud SQL ---
# This is a critical fix for the database connectivity issue seen in the logs.
# It allows the Cloud SQL Auth Proxy running on GKE nodes to connect to the SQL instance.
resource "google_project_iam_member" "gke_nodes_sql_client" {
  project = var.project_id
  role    = "roles/cloudsql.client"
  member  = "serviceAccount:${module.gke.node_pool_service_account}"
}

# --- IAM Permission for GKE Nodes to pull from Artifact Registry ---
# Allows the GKE nodes to pull container images from the Artifact Registry repo.
resource "google_artifact_registry_repository_iam_member" "gke_nodes_ar_reader" {
  project    = google_artifact_registry_repository.robot_shop_repo.project
  location   = google_artifact_registry_repository.robot_shop_repo.location
  repository = google_artifact_registry_repository.robot_shop_repo.name
  role       = "roles/artifactregistry.reader"
  member     = "serviceAccount:${module.gke.node_pool_service_account}"
}

# --- MongoDB Atlas Cluster ---
# Provisions a free-tier MongoDB cluster on Atlas.
resource "mongodbatlas_cluster" "robot_shop_mongo" {
  project_id   = var.atlas_project_id
  name         = "robot-shop-mongo-cluster"
  provider_name = "TENANT"
  backing_provider_name = "GCP"
  provider_region_name  = "CENTRAL_US"
  provider_instance_size_name = "M0"
}

# --- MongoDB Atlas IP Access List ---
# Allows the GKE cluster (via its NAT gateway) to connect to the MongoDB Atlas cluster.
resource "mongodbatlas_project_ip_access_list" "gke_access" {
  project_id = var.atlas_project_id
  ip_address = module.vpc.nat_gateway_ip
  comment    = "Allow access from GKE cluster NAT gateway"
  depends_on = [module.vpc.nat_gateway]
}
