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

variable "project_id" {
  description = "The GCP project ID."
  type        = string
}

variable "region" {
  description = "The GCP region to deploy resources in."
  type        = string
  default     = "us-central1"
}

variable "shipping_password" {
  description = "The password for the shipping database user."
  type        = string
  sensitive   = true
}

variable "ratings_password" {
  description = "The password for the ratings database user."
  type        = string
  sensitive   = true
}

variable "bastion_ssh_pub_key" {
  description = "The public SSH key for the bastion host."
  type        = string
  sensitive   = true
}

# --- MongoDB Atlas Variables ---
variable "atlas_project_id" {
  description = "Your MongoDB Atlas project ID."
  type        = string
}

variable "atlas_public_key" {
  description = "Your MongoDB Atlas public API key."
  type        = string
  sensitive   = true
}

variable "atlas_private_key" {
  description = "Your MongoDB Atlas private API key."
  type        = string
  sensitive   = true
}

# --- CloudAMQP Variables ---
variable "cloudamqp_api_key" {
  description = "Your CloudAMQP API key."
  type        = string
  sensitive   = true
}