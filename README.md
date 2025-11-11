GKE Three-Tier Microservices with Terraform

This repository contains the complete infrastructure-as-code (IaC) and application deployment configurations for the "Robot Shop" three-tier microservices application.

The infrastructure is provisioned on Google Cloud Platform (GCP) using Terraform. The application is then deployed to Google Kubernetes Engine (GKE) using a modified Helm chart.

This project is an adaptation of the three-tier-architecture-demo repository. The primary modification is the use of Terraform to provision a secure, private GKE cluster and fully-managed backend services, decoupling the application from in-cluster databases.

🏗️ Architecture

This Terraform plan provisions a secure, private, and scalable architecture:

Networking: A custom VPC (robot-shop-vpc) with private and public subnets. A Cloud NAT gateway provides secure outbound internet access for private resources.

Compute (GKE): A private GKE cluster (robot-shop-gke) with nodes running in the private subnet. The cluster's master endpoint is private, accessible only from within the VPC.

Databases & Messaging (Managed Services):

Cloud SQL (MySQL): A regional, high-availability MySQL 8.0 instance for the shipping and ratings services.

Cloud Memorystore (Redis): A standard HA Redis instance for the user and cart services.

MongoDB Atlas: A managed M0 (free tier) cluster provisioned on GCP for the catalogue and user services.

CloudAMQP (RabbitMQ): A managed "Lemur" plan instance for asynchronous messaging.

Security & Access:

Google Artifact Registry: A private Docker repository (robot-shop-repo) to host the application's container images.

IAM & Service Accounts: The GKE node pool uses a dedicated service account with the minimal required roles (roles/cloudsql.client, roles/artifactregistry.reader).

Bastion Host: A minimal e2-micro VM in the private subnet, accessible via Google's Identity-Aware Proxy (IAP) for secure kubectl access.

Google Secret Manager: All sensitive passwords and credentials for the databases are stored securely.

🚀 Technology Stack

Category

Technology

Infrastructure as Code

Terraform

Cloud Platform

Google Cloud Platform (GCP)

Container Orchestration

Google Kubernetes Engine (GKE)

Container Registry

Google Artifact Registry

Databases

Cloud SQL (MySQL), Cloud Memorystore (Redis), MongoDB Atlas

Messaging

CloudAMQP (RabbitMQ)

Security

Google Secret Manager, IAM, IAP, Private VPC

Application

Docker, Helm, Kubernetes

📋 Prerequisites

Before you begin, ensure you have the following accounts and tools:

Accounts:

GCP Account: With billing enabled.

MongoDB Atlas Account: A free account with a new project created.

CloudAMQP Account: A free "Lemur" plan account.

Tools:

Google Cloud SDK (gcloud)

Terraform (v1.0+)

Helm (v3+)

kubectl

Docker

⚙️ Deployment Guide

This deployment is a four-part process:

Part 1: Provision Infrastructure (with Terraform)

Part 2: Build and Push Container Images (with Docker)

Part 3: Deploy the Application (with Helm)

Part 4: Seed the Databases (with Kubernetes Jobs)

Part 1: Provision Infrastructure (Terraform)

Clone This Repository

git clone <your-github-repo-url>
cd <your-repo-name>


GCP Setup

Authenticate your local gcloud CLI:

gcloud auth login
gcloud auth application-default login


Set your project configuration. Replace YOUR_PROJECT_ID with your GCP Project ID.

gcloud config set project YOUR_PROJECT_ID


Enable the required APIs:

gcloud services enable \
    container.googleapis.com \
    compute.googleapis.com \
    sqladmin.googleapis.com \
    redis.googleapis.com \
    secretmanager.googleapis.com \
    artifactregistry.googleapis.com \
    servicenetworking.googleapis.com \
    iap.googleapis.com


Configure Terraform Variables

Get SaaS API Keys:

MongoDB Atlas: Create an API Key (Public & Private) with "Project Owner" permissions. Get your atlas_project_id.

CloudAMQP: Get your cloudamqp_api_key from the "API Access" section of your account.

Create terraform.tfvars:
In the terraform/ directory, create a file named terraform.tfvars and add the following content, replacing the values with your own.

# terraform/terraform.tfvars

project_id = "YOUR_GCP_PROJECT_ID"
region     = "us-central1"

# --- Database Credentials (Choose your own secure passwords) ---
shipping_password = "REPLACE_WITH_SECURE_PASSWORD"
ratings_password  = "REPLACE_WITH_SECURE_PASSWORD"

# --- Bastion Host SSH Key ---
# (Generate one with `ssh-keygen -t rsa -f ~/.ssh/gcp_bastion` and copy the contents of `~/.ssh/gcp_bastion.pub` here)
bastion_ssh_pub_key = "ssh-rsa AAAA..."

# --- MongoDB Atlas API Credentials ---
atlas_project_id  = "YOUR_ATLAS_PROJECT_ID"
atlas_public_key  = "YOUR_ATLAS_PUBLIC_KEY"
atlas_private_key = "YOUR_ATLAS_PRIVATE_KEY"

# --- CloudAMQP API Key ---
cloudamqp_api_key = "YOUR_CLOUDAMQP_API_KEY"


Run Terraform

cd terraform
terraform init
terraform plan
terraform apply -auto-approve


This will take 10-15 minutes to provision all resources. When finished, copy the output values as you will need them for the next steps.

Part 2: Build and Push Container Images

Terraform created a private Google Artifact Registry repository. You must now build the application's service images and push them to it.

Configure Docker Authentication
Configure Docker to authenticate with your new Artifact Registry.

gcloud auth configure-docker us-central1-docker.pkg.dev


Define Image Variables
Set these shell variables to make the build/push process easier.

# Replace with your GCP Project ID
export GCP_PROJECT="YOUR_GCP_PROJECT_ID"

# This is the region from your terraform.tfvars
export GCP_REGION="us-central1"

# This is the repo_id set in terraform/main.tf
export AR_REPO="robot-shop-repo"

# This is the base directory of the original code
# (Assuming it's in a subfolder named 'three-tier-architecture-demo-master')
export APP_SOURCE_DIR="./three-tier-architecture-demo-master"

# The full path to your new Artifact Registry
export IMAGE_REPO_PATH="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT}/${AR_REPO}"


Build and Push All Images
This script will loop through each microservice directory (including the database seeders), build its Docker image, tag it, and push it to your private registry.

# List of all services that have a Dockerfile
SERVICES="cart catalogue dispatch mysql mongo payment ratings shipping user web"

for SERVICE in $SERVICES; do
  echo "--- Building and Pushing: ${SERVICE} ---"

  # Build the image
  docker build -t "${IMAGE_REPO_PATH}/${SERVICE}:latest" "${APP_SOURCE_DIR}/${SERVICE}"

  # Push the image
  docker push "${IMAGE_REPO_PATH}/${SERVICE}:latest"

  echo "--- Finished: ${SERVICE} ---"
  echo ""
done

echo "All images pushed to ${IMAGE_REPO_PATH}"


Part 3: Deploy the Application (Helm)

Create Your Helm Values File
Create a new file named my-values.yaml in the root of your project. This file will configure the Helm chart to use your new infrastructure.

Copy the template below and replace all placeholder values with the outputs from terraform output (Part 1) and the variables from Part 2.

# my-values.yaml

# --- Image Repository ---
# Point to your new Google Artifact Registry
image:
  # Replace with your IMAGE_REPO_PATH from Part 2
  repo: "us-central1-docker.pkg.dev/YOUR_PROJECT_ID/robot-shop-repo"

# --- Database Connections ---
mongodb:
  # Get from terraform output 'mongodb_srv_address'
  url: "mongodb+srv://..." 

rabbitmq:
  # Get from terraform output 'rabbitmq_url'
  host: "amqps://..."

redis:
  # Get from terraform output 'redis_host'
  host: "10.x.x.x"

mysql:
  # Get from terraform output 'mysql_connection_name'
  connectionName: "YOUR_PROJECT_ID:us-central1:mysql-instance"

  # These passwords MUST match what you put in terraform.tfvars
  shippingPassword: "REPLACE_WITH_SECURE_PASSWORD"
  ratingsPassword:  "REPLACE_WITH_SECURE_PASSWORD"

# --- Disable in-cluster databases (Critical) ---
create:
  mongodb: false
  mysql: false
  rabbitmq: false
  redis: false


Connect to your GKE Cluster
You must run kubectl and helm commands from a machine that can access the cluster's private endpoint. The easiest way is to SSH into your bastion host via IAP.

# 1. SSH into the bastion host (run from your local machine)
gcloud compute ssh bastion-host --project ${GCP_PROJECT} --zone ${GCP_REGION}-a

# --- Run the following commands inside the bastion host ---

# 2. (Inside bastion) Install kubectl and helm if not present
# sudo apt-get update && sudo apt-get install -y gettext-base kubectl
# curl -fsSL -o get_helm.sh [https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3](https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3)
# chmod 700 get_helm.sh && ./get_helm.sh

# 3. (Inside bastion) Get cluster credentials
# Note: Use --internal-ip flag
gcloud container clusters get-credentials robot-shop-gke --region ${GCP_REGION} --project ${GCP_PROJECT} --internal-ip

# 4. (Inside bastion) Verify connection
kubectl get nodes


Deploy the Helm Chart
From the bastion host, you will need access to your Helm charts and your my-values.yaml file. You can either git clone your repo onto the bastion host or use gcloud compute scp to copy the files.

# (Inside bastion)
# Assuming your repo is cloned and you are in the root directory

helm install robot-shop ./three-tier-architecture-demo-master/GKE/helm \
  -f ./my-values.yaml \
  --namespace robot-shop \
  --create-namespace


Part 4: Seed the Databases (Critical)

The application is running, but the databases are empty. You must now run the seeder jobs.

Create seed-dbs-job.yaml
On the bastion host, create a file named seed-dbs-job.yaml with the content below. Update the placeholder values to match your my-values.yaml file.

# seed-dbs-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: seed-mongo-db
  namespace: robot-shop
spec:
  template:
    spec:
      containers:
      - name: mongo-seeder
        image: us-central1-docker.pkg.dev/YOUR_PROJECT_ID/robot-shop-repo/mongo:latest # <-- UPDATE THIS
        env:
        - name: MONGO_URL
          value: "mongodb+srv://..." # <-- UPDATE THIS (from my-values.yaml)
      restartPolicy: Never
  backoffLimit: 4
---
apiVersion: batch/v1
kind: Job
metadata:
  name: seed-mysql-db
  namespace: robot-shop
spec:
  template:
    spec:
      containers:
      - name: mysql-seeder
        image: us-central1-docker.pkg.dev/YOUR_PROJECT_ID/robot-shop-repo/mysql:latest # <-- UPDATE THIS
        env:
        - name: DB_HOST
          value: "127.0.0.1" # Connects to the proxy
        - name: DB_PASSWORD
          value: "YOUR_SHIPPING_PASSWORD" # <-- UPDATE THIS (from my-values.yaml)
      # Cloud SQL Proxy sidecar
      - name: cloud-sql-proxy
        image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:latest
        args:
          - "--private-ip"
          - "--structured-logs"
          - "YOUR_PROJECT_ID:us-central1:mysql-instance" # <-- UPDATE THIS (from my-values.yaml)
        securityContext:
          runAsNonRoot: true
      restartPolicy: Never
  backoffLimit: 4


Apply the Seeder Jobs

# (Inside bastion)
kubectl apply -f seed-dbs-job.yaml


Check Job Status
Wait for the jobs to complete.

kubectl get jobs -n robot-shop -w

# NAME            COMPLETIONS   DURATION   AGE
# seed-mongo-db   1/1           20s        30s
# seed-mysql-db   1/1           25s        30s


Part 5: Access Your Application

Once the pods are running and the databases are seeded, find your Load Balancer's IP address.

Get Ingress IP

# (Inside bastion or local)
# It may take a few minutes for the IP address to appear
kubectl get ingress -n robot-shop

# Example output:
# NAME         CLASS    HOSTS   ADDRESS          PORTS   AGE
# robot-shop   gce      * 34.123.45.67     80      5m


Open in Browser
You can now access your application by navigating to the ADDRESS (e.g., http://34.123.45.67) in your web browser.

✨ Key Modifications

This repository is an adaptation of the original Google Cloud and Instana demo repositories. The key modifications are:

Terraform-Managed Infrastructure: All infrastructure (VPC, GKE, Cloud SQL, Memorystore, Artifact Registry, Bastion Host) is defined as code in the terraform/ directory.

Externalized Backends: The Helm charts in three-tier-architecture-demo-master/GKE/helm are used with a custom my-values.yaml file to connect to the managed services provisioned by Terraform, rather than deploying in-cluster databases.

Cloud SQL Proxy Sidecar: The GKE/helm/fixes.yaml file is used to inject the Cloud SQL Auth Proxy as a sidecar, enabling secure, IAM-based authentication to the managed MySQL instance.

Private Image Repository: The application is configured to build and pull images from a private Google Artifact Registry (IMAGE_REPO_PATH) instead of public Docker Hub images.

Database Seeding Jobs: This README provides Job manifests (seed-dbs-job.yaml) to run the original data-seeding containers against the new managed databases, a critical step that was not automated in the original GKE charts.

🙏 Acknowledgements

This project's application code and Kubernetes Helm charts are based on the Instana Robot Shop microservices demo. The GKE deployment configurations were adapted from the three-tier-architecture-demo repository.

Our work involved building a new Terraform infrastructure to provision all backend services as managed services on GCP and modifying the Helm charts to connect to them.

Original Application Source: https://github.com/instana/robot-shop

Original GKE Deployment Source: https://github.com/GoogleCloudPlatform/three-tier-architecture-demo

The original project is licensed under the Apache License 2.0. A copy of the license should be included in this repository.
