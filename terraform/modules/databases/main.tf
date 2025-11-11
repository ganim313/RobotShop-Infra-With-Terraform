terraform {
  required_providers {
    cloudamqp = {
      source  = "cloudamqp/cloudamqp"
      version = "~> 1.20.0"
    }
  }
}

resource "google_sql_database_instance" "mysql" {
  project          = var.gcp_project_id
  name             = "mysql-instance"
  database_version = "MYSQL_8_0"
  region           = var.gcp_region

  settings {
    tier              = "db-n1-standard-1"
    availability_type = "REGIONAL"
    ip_configuration {
      ipv4_enabled    = false
      private_network = var.vpc_id
    }
    backup_configuration {
      enabled            = true
      binary_log_enabled = true
    }
  }
  deletion_protection = false
}

resource "google_sql_user" "shipping_user" {
  project  = var.gcp_project_id
  instance = google_sql_database_instance.mysql.name
  name     = "shipping"
  password = var.shipping_password
}

resource "google_secret_manager_secret" "shipping_password_secret" {
  project = var.gcp_project_id
  secret_id = "shipping-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "shipping_password_version" {
  secret = google_secret_manager_secret.shipping_password_secret.id
  secret_data = var.shipping_password
}

resource "google_redis_instance" "redis" {
  project            = var.gcp_project_id
  name               = "redis-instance"
  tier               = "STANDARD_HA"
  memory_size_gb     = 1
  region             = var.gcp_region
  authorized_network = var.vpc_id
  connect_mode       = "PRIVATE_SERVICE_ACCESS"
}

resource "google_sql_user" "ratings_user" {
  project  = var.gcp_project_id
  instance = google_sql_database_instance.mysql.name
  name     = "ratings"
  password = var.ratings_password
}

resource "google_secret_manager_secret" "ratings_password_secret" {
  project = var.gcp_project_id
  secret_id = "ratings-password"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "ratings_password_version" {
  secret = google_secret_manager_secret.ratings_password_secret.id
  secret_data = var.ratings_password
}

resource "cloudamqp_instance" "rabbitmq" {
  name   = "robot-shop-rabbitmq"
  plan   = "lemur"
  region = "google-compute-engine::us-central1"
  tags   = ["robot-shop"]
}

resource "google_secret_manager_secret" "rabbitmq_password_secret" {
  project = var.gcp_project_id
  secret_id = "rabbitmq-password"

  replication {
    auto {}
  }
}

locals {
  rabbitmq_user_pass = split("@", split("//", cloudamqp_instance.rabbitmq.url)[1])[0]
  rabbitmq_password = split(":", local.rabbitmq_user_pass)[1]
}

resource "google_secret_manager_secret_version" "rabbitmq_password_version" {
  secret = google_secret_manager_secret.rabbitmq_password_secret.id
  secret_data = local.rabbitmq_password
}