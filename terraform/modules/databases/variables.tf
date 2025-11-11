variable "gcp_project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "gcp_region" {
  description = "The GCP region"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "service_networking_connection_id" {
  description = "The ID of the service networking connection"
  type        = string
}

variable "private_subnet_id" {
  description = "The ID of the private subnetwork"
  type        = string
}

variable "private_subnet_cidr" {
  description = "The CIDR range of the private subnetwork"
  type        = string
}

variable "shipping_password" {
  description = "The password for the shipping database user"
  type        = string
  sensitive   = true
}

variable "ratings_password" {
  description = "The password for the ratings database user"
  type        = string
  sensitive   = true
}