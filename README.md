# GKE Three-Tier Microservices with Terraform

<p align="center">
  <img src="https://raw.githubusercontent.com/instana/robot-shop/master/images/robot-shop-logo.png" alt="RobotShop Logo" width="140"/>
</p>

<p align="center">
  <a href="https://cloud.google.com/">
    <img src="https://img.shields.io/badge/GCP-4285f4?logo=google-cloud&logoColor=white"/>
  </a>
  <a href="https://www.terraform.io/">
    <img src="https://img.shields.io/badge/Terraform-7B42BC?logo=terraform&logoColor=white"/>
  </a>
  <a href="https://kubernetes.io/">
    <img src="https://img.shields.io/badge/Kubernetes-326ce5?logo=kubernetes&logoColor=white"/>
  </a>
  <a href="https://helm.sh/">
    <img src="https://img.shields.io/badge/Helm-0f1689?logo=helm&logoColor=white"/>
  </a>
  <a href="https://www.docker.com/">
    <img src="https://img.shields.io/badge/Docker-2496ED?logo=docker&logoColor=white"/>
  </a>
  <a href="https://opensource.org/licenses/Apache-2.0">
    <img src="https://img.shields.io/github/license/ganim313/RobotShop-Infra-With-Terraform" alt="License"/>
  </a>
</p>

---

> **End-to-end IaC for Robot Shop microservices, with secure & managed GCP infrastructure, CI-ready image registry, and GKE-native deployments.**

---

## :house: Overview

This repository contains the complete infrastructure-as-code (IaC) and application deployment configurations for the "Robot Shop" three-tier microservices application.

The infrastructure is provisioned on **Google Cloud Platform (GCP)** using **Terraform**. The application is then deployed to **Google Kubernetes Engine (GKE)** using a modified **Helm** chart.

This project is an adaptation of the [three-tier-architecture-demo repository](https://github.com/GoogleCloudPlatform/three-tier-architecture-demo). The primary modification is a shift to managed, secure, and scalable GCP resources using Terraform, with integration to modern managed backends.

---

## 📸 Live Screens and Example Output

### MongoDB Products (`catalogue.products`)
![MongoDB Atlas - catalogue.products](screenshots/mongodb-products.png)
_Image 1: MongoDB Atlas Data Viewer_

### Kubernetes Pods Overview
![Kubernetes Pods Terminal](screenshots/kubectl-get-pods.png)
_Image 2: Output from `kubectl get pods`_

### Running Application Homepage
![Robot Shop Web Home](screenshots/robot-shop-home.png)
_Image 3: Stan's Robot Shop UI (browser)_

---

## Architecture

This deployment provisions a secure, private, and scalable architecture:

  * **Networking**: 
    - A custom VPC (`robot-shop-vpc`) with private and public subnets.
    - Cloud NAT gateway provides secure outbound internet access for private resources.
  * **Compute (GKE)**:
    - Private GKE cluster (`robot-shop-gke`) with nodes running in the private subnet.
    - Cluster's master endpoint is private, accessible only from within the VPC.
  * **Databases & Messaging (Managed Services)**:
      - ![MySQL](https://img.shields.io/badge/MySQL-4479A1?logo=mysql&logoColor=white) **Cloud SQL (MySQL)**: High-availability MySQL 8.0 for the `shipping` and `ratings` services.
      - ![Redis](https://img.shields.io/badge/Redis-DC382D?logo=redis&logoColor=white) **Cloud Memorystore (Redis)**: Standard HA Redis for the `user` and `cart` services.
      - ![MongoDB](https://img.shields.io/badge/MongoDB-47A248?logo=mongodb&logoColor=white) **MongoDB Atlas**: Managed M0 cluster on GCP for the `catalogue` and `user` services.
      - ![RabbitMQ](https://img.shields.io/badge/RabbitMQ-FF6600?logo=rabbitmq&logoColor=white) **CloudAMQP (RabbitMQ)**: Managed instance for asynchronous messaging.
  * **Security & Access**:
      - **Google Artifact Registry**: Private Docker repository (`robot-shop-repo`) for container images.
      - **IAM & Service Accounts**: Dedicated GKE Service Account (minimal required roles).
      - **Bastion Host**: `e2-micro` VM in private subnet, IAP-secured for `kubectl` access.
      - **Google Secret Manager**: All sensitive passwords and credentials stored securely.

---

## Prerequisites

Before you begin, ensure you have the following accounts and tools:

### Accounts

  * **GCP Account** (with billing enabled)
  * **MongoDB Atlas Account** (free project)
  * **CloudAMQP Account** (free "Lemur" plan)

### Tools

  * [Google Cloud SDK (`gcloud`)](https://cloud.google.com/sdk/docs/install)
  * [Terraform (v1.0+)](https://www.terraform.io/downloads.html)
  * [Helm (v3+)](https://helm.sh/docs/intro/install/)
  * [kubectl](https://kubernetes.io/docs/tasks/tools/)
  * [Docker](https://docs.docker.com/get-docker/)

---

## Deployment Guide

This deployment proceeds in three parts:

1. **Part 1: Provision Infrastructure** (with Terraform)
2. **Part 2: Build and Push Container Images** (with Docker)
3. **Part 3: Deploy the Application** (with Helm)

---

### Part 1: Provision Infrastructure (Terraform)

1. **Clone This Repository**

    ```sh
    git clone https://github.com/ganim313/RobotShop-Infra-With-Terraform.git
    cd RobotShop-Infra-With-Terraform
    ```

2. **GCP Setup**

    - Authenticate your local `gcloud` CLI:
      ```sh
      gcloud auth login
      gcloud auth application-default login
      ```
    - Set your project configuration. Replace `YOUR_PROJECT_ID` with your GCP Project ID.
      ```sh
      gcloud config set project YOUR_PROJECT_ID
      ```
    - Enable the required APIs:
      ```sh
      gcloud services enable \
          container.googleapis.com \
          compute.googleapis.com \
          sqladmin.googleapis.com \
          redis.googleapis.com \
          secretmanager.googleapis.com \
          artifactregistry.googleapis.com \
          servicenetworking.googleapis.com \
          iap.googleapis.com
      ```

3. **Configure Terraform Variables**
    - **Get SaaS API Keys**:
        - **MongoDB Atlas**: Create an API Key (Project Owner permissions) & get your `atlas_project_id`.
        - **CloudAMQP**: Get your `cloudamqp_api_key` from the "API Access" section.

    - **Create `terraform.tfvars`** in the `terraform/` directory:
      ```hcl
      project_id = "YOUR_GCP_PROJECT_ID"
      region     = "us-central1"
      shipping_password = "REDACTED"
      ratings_password  = "REDACTED"

      bastion_ssh_pub_key = "ssh-rsa ..."

      atlas_project_id  = "YOUR_ATLAS_PROJECT_ID"
      atlas_public_key  = "YOUR_ATLAS_PUBLIC_KEY"
      atlas_private_key = "YOUR_ATLAS_PRIVATE_KEY"

      cloudamqp_api_key = "YOUR_CLOUDAMQP_API_KEY"
      ```

4. **Run Terraform**

    ```sh
    cd terraform
    terraform init
    terraform plan
    terraform apply -auto-approve
    ```

    _Provisioning will take 10–15 minutes._

---

### Part 2: Build and Push Container Images

Terraform creates a private **Google Artifact Registry** for your images.

1. **Configure Docker Authentication**
    ```sh
    gcloud auth configure-docker us-central1-docker.pkg.dev
    ```

2. **Set Shell Variables**

    ```sh
    export GCP_PROJECT="YOUR_GCP_PROJECT_ID"
    export GCP_REGION="us-central1"
    export AR_REPO="robot-shop-repo"
    export APP_SOURCE_DIR="../three-tier-architecture-demo-master"
    export IMAGE_REPO_PATH="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT}/${AR_REPO}"
    ```

3. **Build and Push All Images**

    ```sh
    SERVICES="cart catalogue dispatch mysql mongo payment ratings shipping user web"
    for SERVICE in $SERVICES; do
      echo "--- Building and Pushing: ${SERVICE} ---"
      docker build -t "${IMAGE_REPO_PATH}/${SERVICE}:latest" "${APP_SOURCE_DIR}/${SERVICE}"
      docker push "${IMAGE_REPO_PATH}/${SERVICE}:latest"
      echo "--- Finished: ${SERVICE} ---"
      echo ""
    done

    echo "All images pushed to ${IMAGE_REPO_PATH}"
    ```

---

### Part 3: Deploy the Application (Helm)

1. **Configure Helm Values**

    - **Get Terraform Outputs** for managed services:
      ```sh
      cd ../terraform
      terraform output
      ```
    - **Create `my-values.yaml`** (do not edit `gke-values.yaml`). Copy the following, replace the variables:
      ```yaml
      image:
        repo: "us-central1-docker.pkg.dev/YOUR_PROJECT_ID/robot-shop-repo"
      mongodb:
        url: "<MONGODB_SRV_ADDRESS>"     # From terraform output
      rabbitmq:
        host: "<RABBITMQ_URL>"           # From terraform output
      redis:
        host: "<REDIS_HOST>"             # From terraform output
      mysql:
        connectionName: "YOUR_PROJECT_ID:us-central1:mysql-instance"
        shippingPassword: "<MATCHED_PASSWORD>"
        ratingsPassword:  "<MATCHED_PASSWORD>"
      create:
        mongodb: false
        mysql: false
        rabbitmq: false
        redis: false
      ```

2. **Connect to your GKE Cluster**

    - SSH into the bastion host via IAP:
      ```sh
      gcloud compute ssh bastion-host --project ${GCP_PROJECT} --zone ${GCP_REGION}-a
      gcloud container clusters get-credentials robot-shop-gke --region ${GCP_REGION} --project ${GCP_PROJECT} --internal-ip
      kubectl get nodes
      ```
      _Note: Inside the bastion, install Helm and kubectl if not present._

3. **Deploy the Helm Chart**

    ```sh
    helm install robot-shop ./three-tier-architecture-demo-master/GKE/helm \
      -f ./my-values.yaml \
      --namespace robot-shop \
      --create-namespace
    ```

4. **Access Your Application**

    ```sh
    kubectl get services -o wide
    ```
    Once the external `ADDRESS` appears, visit it in your browser.  
    _Example: `http://136.119.249.71:8080` (see Screenshot 3 above)._

---

## Key Modifications from Original Repo

This project is a functional fork, adapted for secure, scalable managed GCP architecture:

- **Terraform-Managed Infrastructure**: All infra (VPC, GKE, DBs) is declarative code.
- **Externalized Backends**: Helm charts connect to _external managed_ services, not in-cluster DBs.
- **Cloud SQL Proxy Sidecar**: Helm patch provides secure IAM-based MySQL access.
- **GKE-Native Ingress**: Provisions Google Cloud Load Balancer via Kubernetes Ingress.
- **Private Image Registry**: Containers sourced from Artifact Registry, not public Docker Hub.

---

## Acknowledgements

- **Application**: [instana/robot-shop](https://github.com/instana/robot-shop)
- **GKE Helm Base**: [GoogleCloudPlatform/three-tier-architecture-demo](https://github.com/GoogleCloudPlatform/three-tier-architecture-demo)
- **Screenshots**: See `/screenshots/` folder for outputs referenced in this README.

---

## License

Apache 2.0. See [LICENSE](./LICENSE).

---

*For issues, contributions, or suggestions, open a pull request or GitHub issue!*
