# GKE Three-Tier Microservices with Terraform

This repository contains the complete infrastructure-as-code (IaC) and application deployment configurations for the "Robot Shop" three-tier microservices application.

The infrastructure is provisioned on **Google Cloud Platform (GCP)** using **Terraform**. The application is then deployed to **Google Kubernetes Engine (GKE)** using a modified **Helm** chart.

This project is an adaptation of the [three-tier-architecture-demo repository](https://www.google.com/search?q=https://github.com/GoogleCloudPlatform/three-tier-architecture-demo). The primary modification is the use of Terraform to provision a secure, private GKE cluster and fully-managed backend services, decoupling the application from in-cluster databases.

## Architecture

This deployment provisions a secure, private, and scalable architecture:

  * **Networking**: A custom VPC (`robot-shop-vpc`) with private and public subnets. A Cloud NAT gateway provides secure outbound internet access for private resources.
  * **Compute (GKE)**: A private GKE cluster (`robot-shop-gke`) with nodes running in the private subnet. The cluster's master endpoint is private, accessible only from within the VPC.
  * **Databases & Messaging (Managed Services)**:
      * **Cloud SQL (MySQL)**: A regional, high-availability MySQL 8.0 instance for the `shipping` and `ratings` services.
      * **Cloud Memorystore (Redis)**: A standard HA Redis instance for the `user` and `cart` services.
      * **MongoDB Atlas**: A managed M0 (free tier) cluster provisioned on GCP for the `catalogue` and `user` services.
      * **CloudAMQP (RabbitMQ)**: A managed "Lemur" plan instance for asynchronous messaging.
  * **Security & Access**:
      * **Google Artifact Registry**: A private Docker repository (`robot-shop-repo`) to host the application's container images.
      * **IAM & Service Accounts**: The GKE node pool uses a dedicated service account with the minimal required roles (`roles/cloudsql.client`, `roles/artifactregistry.reader`).
      * **Bastion Host**: A minimal `e2-micro` VM in the private subnet, accessible via Google's Identity-Aware Proxy (IAP) for secure `kubectl` access.
      * **Google Secret Manager**: All sensitive passwords and credentials for the databases are stored securely.

-----

## Prerequisites

Before you begin, ensure you have the following accounts and tools:

1.  **Accounts**:

      * **GCP Account**: With billing enabled.
      * **MongoDB Atlas Account**: A free account with a new project created.
      * **CloudAMQP Account**: A free "Lemur" plan account.

2.  **Tools**:

      * [Google Cloud SDK (`gcloud`)](https://www.google.com/search?q=%5Bhttps://cloud.google.com/sdk/docs/install%5D\(https://cloud.google.com/sdk/docs/install\))
      * [Terraform (v1.0+)](https://www.terraform.io/downloads.html)
      * [Helm (v3+)](https://helm.sh/docs/intro/install/)
      * [kubectl](https://kubernetes.io/docs/tasks/tools/)
      * [Docker](https://docs.docker.com/get-docker/)

-----

## Deployment Guide

This deployment is a three-part process:

1.  **Part 1: Provision Infrastructure** (with Terraform)
2.  **Part 2: Build and Push Container Images** (with Docker)
3.  **Part 3: Deploy the Application** (with Helm)

### Part 1: Provision Infrastructure (Terraform)

1.  **Clone This Repository**

    ```sh
    git clone <your-github-repo-url>
    cd <your-repo-name>
    ```

2.  **GCP Setup**

      * Authenticate your local `gcloud` CLI:
        ```sh
        gcloud auth login
        gcloud auth application-default login
        ```
      * Set your project configuration. Replace `YOUR_PROJECT_ID` with your GCP Project ID.
        ```sh
        gcloud config set project YOUR_PROJECT_ID
        ```
      * Enable the required APIs:
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

3.  **Configure Terraform Variables**

      * **Get SaaS API Keys**:

          * **MongoDB Atlas**: Create an API Key (Public & Private) with "Project Owner" permissions. Get your `atlas_project_id`.
          * **CloudAMQP**: Get your `cloudamqp_api_key` from the "API Access" section of your account.

      * **Create `terraform.tfvars`**:
        In the `terraform/` directory, create a file named `terraform.tfvars` and add the following content, replacing the values with your own.

        ```hcl
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
        ```

4.  **Run Terraform**

    ```sh
    cd terraform
    terraform init
    terraform plan
    terraform apply -auto-approve
    ```

    This will take 10-15 minutes to provision all resources.

### Part 2: Build and Push Container Images

Terraform created a private **Google Artifact Registry** repository for your images. You now need to build the application's service images and push them to it.

1.  **Configure Docker Authentication**
    Configure Docker to authenticate with your new Artifact Registry.

    ```sh
    gcloud auth configure-docker us-central1-docker.pkg.dev
    ```

2.  **Define Image Variables**
    Set these shell variables to make the build/push process easier.

    ```sh
    # Replace with your GCP Project ID
    export GCP_PROJECT="YOUR_GCP_PROJECT_ID"

    # This is the region from your terraform.tfvars
    export GCP_REGION="us-central1"

    # This is the repo_id set in terraform/main.tf
    export AR_REPO="robot-shop-repo"

    # This is the base directory of the original code
    export APP_SOURCE_DIR="../three-tier-architecture-demo-master"

    # The full path to your new Artifact Registry
    export IMAGE_REPO_PATH="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT}/${AR_REPO}"
    ```

3.  **Build and Push All Images**
    This script will loop through each microservice directory, build its Docker image, tag it, and push it to your private registry.

    ```sh
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
    ```

### Part 3: Deploy the Application (Helm)

1.  **Configure Helm Values**

      * **Get Terraform Outputs**: From your `terraform/` directory, get the connection details for your managed services.

        ```sh
        cd ../terraform
        terraform output
        ```

      * **Create Helm Values File**: Create a new file named `my-values.yaml` (do not edit the `gke-values.yaml` template).

      * **Populate `my-values.yaml`**: Copy the content below and **replace all values** with the outputs from the `terraform output` command and the `IMAGE_REPO_PATH` you defined in the previous step.

        ```yaml
        # my-values.yaml

        # --- Image Repository ---
        # Point to your new Google Artifact Registry
        image:
          repo: "us-central1-docker.pkg.dev/YOUR_PROJECT_ID/robot-shop-repo"
          
        # --- Database Connections ---
        mongodb:
          url: "mongodb+srv://..."  # <-- From terraform output 'mongodb_srv_address'

        rabbitmq:
          host: "amqps://..."     # <-- From terraform output 'rabbitmq_url'

        redis:
          host: "10.x.x.x"       # <-- From terraform output 'redis_host'

        mysql:
          # This must match the Terraform output 'mysql_connection_name'
          connectionName: "YOUR_PROJECT_ID:us-central1:mysql-instance"
          
          # These passwords must match what you put in terraform.tfvars
          shippingPassword: "REPLACE_WITH_SECURE_PASSWORD"
          ratingsPassword:  "REPLACE_WITH_SECURE_PASSWORD"
          
        # --- Disable in-cluster databases ---
        create:
          mongodb: false
          mysql: false
          rabbitmq: false
          redis: false
        ```

2.  **Connect to your GKE Cluster**
    You must run `kubectl` and `helm` commands from a machine that can access the cluster's private endpoint. The easiest way is to **SSH into your bastion host via IAP**.

    ```sh
    # 1. SSH into the bastion host
    gcloud compute ssh bastion-host --project ${GCP_PROJECT} --zone ${GCP_REGION}-a

    # 2. (Inside bastion) Get cluster credentials
    # Note: Use --internal-ip flag
    gcloud container clusters get-credentials robot-shop-gke --region ${GCP_REGION} --project ${GCP_PROJECT} --internal-ip

    # 3. (Inside bastion) Verify connection
    kubectl get nodes
    ```

    *Note: You will need to install `kubectl` and `helm` on the bastion host if they are not already present.*

3.  **Deploy the Helm Chart**
    From the bastion host (or your local machine, if you have a VPN to the VPC), run the helm install command. Make sure `my-values.yaml` and the `three-tier-architecture-demo-master` directory are present.

    ```sh
    # Assuming you are in the directory containing my-values.yaml 
    # and the three-tier-architecture-demo-master folder

    helm install robot-shop ./three-tier-architecture-demo-master/GKE/helm \
      -f ./my-values.yaml \
      --namespace robot-shop \
      --create-namespace
    ```

4.  **Access Your Application**
    It may take a few minutes for the Google Cloud Load Balancer to be provisioned.

    ```sh
    # Run this command until an IP address appears in the "ADDRESS" column
    kubectl get services -o wide
    ```

    You can now access your application by navigating to the `ADDRESS` (e.g., `http://136.119.249.71:8080`) in your web browser.

-----

## Key Modifications from Original Repo

This project is a functional fork, adapted for a specific, secure GCP architecture. The key changes are:

  * **Terraform-Managed Infrastructure**: All infrastructure (VPC, GKE, Databases) is defined as code, not manually created.
  * **Externalized Backends**: The Helm charts in `three-tier-architecture-demo-master/GKE/helm` are modified to connect to external, managed services instead of deploying in-cluster databases.
  * **Cloud SQL Proxy Sidecar**: The file `GKE/helm/fixes.yaml` is used to inject the Cloud SQL Auth Proxy as a sidecar container, enabling secure, IAM-based authentication to the managed MySQL instance.
  * **GKE-Native Ingress**: The configuration uses `GKE/helm/ingress.yaml` and `GKE/helm/gclb.yaml` to provision a Google Cloud Load Balancer directly via a Kubernetes Ingress resource.
  * **Private Image Repository**: The application uses a private Google Artifact Registry for its images, not public Docker Hub images.

## Acknowledgements

This project's application code and Kubernetes Helm charts are based on the **Instana Robot Shop** microservices demo. The `GKE` deployment configurations were adapted from the **three-tier-architecture-demo** repository.

Our work involved building a new Terraform infrastructure to provision all backend services as managed services on GCP and modifying the Helm charts to connect to them.

  * **Original Application Source**: [https://github.com/instana/robot-shop](https://github.com/instana/robot-shop)
  * **Original GKE Deployment Source**: [https://github.com/GoogleCloudPlatform/three-tier-architecture-demo](https://www.google.com/search?q=https://github.com/GoogleCloudPlatform/three-tier-architecture-demo)

The original project is licensed under the Apache License 2.0. A copy of the license should be included in this repository.
