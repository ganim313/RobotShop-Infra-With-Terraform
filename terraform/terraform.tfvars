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

project_id = "robot-shop-project"
region     = "us-central1"

# --- Database Credentials (use a secure method like Secret Manager in production) ---
# db_user     = "robotshop" # This variable is not defined
# db_password = "testingabcd" # This variable is not defined
shipping_password = "testingabcd"
ratings_password = "testingabcd"

# --- Bastion Host SSH Key ---
bastion_ssh_pub_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDXbm2RHyF25NpQHjbNV3X50ooaqINqn4wHQd4u9lzk2lG2XxmkX3b4nT9UbFX5CXViyVjbKtHxgZloFj5rwfMkIey95vpKzZBPlMHn4dRB4zxAh7MP5sGnWwGCl+uXDQ4+xAwk+GKXBk0SLaXAZIxGXb7jYEVdnPyGOW7rvLgYGURMz4zA9KUDa6zxjPLZQ87DQ/y9FjPcOdXqXHUgVduElgjLiEPxbRiLuxFWDYqCiv3fDCvqv3j60r5uCfNpUs7bzd9rtTUhoKLtNn69F1sdvVTvZlKEHtnIsy+LiYEE7e9BArpibv2dQBCcTMMiNFsZs3OxHLf1UcNgUUaasKXvK7/alYtlySF23IGVjF8t3gCj/OHlLk2Dc0n72sF98V9tSNjt1/z4Zd8T7tfj6ftcu6oXSiKf0I20fawMCQCGmZFZpoYyKuB0E88sTiYf/lmb8js1veavnhgat9Q/Tt0coIgsypG/E/3p6XqD2y4hK3qSU5459Z97V/AF8tRlz083uMeQUCiw3rWzdaiYZbMq0/H35h0LAnJEepIauhXMJiS9D1XjK0mnk9NAY4+5GZtO4c/URQb9YFUyKEGpRQEJgPC2PrIGdSGeKYyrxH9Z5jfh/B2TfdT346M//44Ullziau1gwb9gU/xC5DKD2gRbrgXs7nJm3o0LZb8Sq9wcsQ== md ganim@Uqaab"

# --- MongoDB Atlas API Credentials ---
atlas_project_id  = "65f3c3f7095bbe5ec88be1c9"
atlas_public_key  = "nujioqeq"
atlas_private_key = "b6e7a168-c156-475b-9d12-b030ba20a46f"

# --- CloudAMQP API Key ---
cloudamqp_api_key = "113910ef-d3e7-4a03-8505-497047676b74"
