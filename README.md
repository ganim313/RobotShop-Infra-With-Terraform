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

This repository provides complete Infrastructure-as-Code for the **Robot Shop** three-tier microservices demo app.

- **Terraform** provisions all GCP infrastructure.
- **Helm** deploys the Kubernetes application on GKE.
- **All data services**: Fully managed external (SaaS) backends.
- **Security-first**: Private networks, IAM, Secrets.

_Adapted from [three-tier-architecture-demo](https://github.com/GoogleCloudPlatform/three-tier-architecture-demo) and [instana/robot-shop](https://github.com/instana/robot-shop)._

---

## 📸 Live Screens and Example Output

### MongoDB Products (`catalogue.products`)
_Image 1: MongoDB Atlas Data Viewer_
![MongoDB Atlas - catalogue.products](screenshots/mongodb-products.png)

### Kubernetes Pods Overview
_Image 2: Output from `kubectl get pods` (bastion host)_
![Kubernetes Pods Terminal](screenshots/kubectl-get-pods.png)

### Running Application Homepage
_Image 3: Stan's Robot Shop UI (browser)_
![Robot Shop Web Home](screenshots/robot-shop-home.png)

---

## :art: Architecture

This deployment provisions a secure, private, and scalable GCP architecture:

- **Networking**: Custom VPC, public/private subnets, Cloud NAT for safe egress, all traffic secured.
- **Compute**: GKE cluster (private, no public endpoint), node pool in private subnet.
- **Backends**:
  - ![MySQL](https://img.shields.io/badge/MySQL-4479A1?logo=mysql&logoColor=white) Cloud SQL MySQL (shipping, ratings)
  - ![Redis](https://img.shields.io/badge/Redis-DC382D?logo=redis&logoColor=white) Memorystore Redis (user, cart)
  - ![MongoDB](https://img.shields.io/badge/MongoDB-47A248?logo=mongodb&logoColor=white) Atlas MongoDB (catalogue, user)
  - ![RabbitMQ](https://img.shields.io/badge/RabbitMQ-FF6600?logo=rabbitmq&logoColor=white) CloudAMQP RabbitMQ
- **Security**: Artifact Registry (private), GKE node SA with least privilege, all DB credentials in Secret Manager, kubectl bastion locked behind IAP.

---

## :rocket: Quick Start

<details>
<summary>Show prerequisites & setup steps</summary>

### Requirements: 

#### Accounts
- [GCP account](https://cloud.google.com/)
- [MongoDB Atlas account](https://www.mongodb.com/cloud/atlas)
- [CloudAMQP free account](https://www.cloudamqp.com/)

#### Tools
- [Google Cloud SDK](https://cloud.google.com/sdk/docs/install)
- [Terraform (v1.0+)](https://www.terraform.io/downloads.html)
- [Helm (v3+)](https://helm.sh/docs/intro/install/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Docker](https://docs.docker.com/get-docker/)

---

## 1. Provision Infrastructure (Terraform)

```sh
git clone https://github.com/ganim313/RobotShop-Infra-With-Terraform.git
cd RobotShop-Infra-With-Terraform

gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID

gcloud services enable \
    container.googleapis.com compute.googleapis.com sqladmin.googleapis.com \
    redis.googleapis.com secretmanager.googleapis.com artifactregistry.googleapis.com \
    servicenetworking.googleapis.com iap.googleapis.com
```

Edit `terraform/terraform.tfvars` with your sensitive values & API keys.

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

Then:

```sh
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```

---

## 2. Build & Push Application Images

Authenticate Docker to Artifact Registry:

```sh
gcloud auth configure-docker us-central1-docker.pkg.dev
```

Export these for convenience:

```sh
export GCP_PROJECT="YOUR_GCP_PROJECT_ID"
export GCP_REGION="us-central1"
export AR_REPO="robot-shop-repo"
export APP_SOURCE_DIR="../three-tier-architecture-demo-master"
export IMAGE_REPO_PATH="${GCP_REGION}-docker.pkg.dev/${GCP_PROJECT}/${AR_REPO}"
```

Build & push:

```sh
SERVICES="cart catalogue dispatch mysql mongo payment ratings shipping user web"
for SERVICE in $SERVICES; do
  docker build -t "${IMAGE_REPO_PATH}/${SERVICE}:latest" "${APP_SOURCE_DIR}/${SERVICE}"
  docker push "${IMAGE_REPO_PATH}/${SERVICE}:latest"
done
```

---

## 3. Deploy the Application (Helm)

- Collect outputs from `terraform output` (in `terraform/`)
- Compose `my-values.yaml` as shown below:

```yaml
image:
  repo: "us-central1-docker.pkg.dev/YOUR_PROJECT_ID/robot-shop-repo"
mongodb:
  url: "mongodb+srv://..."    # From terraform output 'mongodb_srv_address'
rabbitmq:
  host: "amqps://..."         # From terraform output 'rabbitmq_url'
redis:
  host: "10.x.x.x"            # From 'redis_host'
mysql:
  connectionName: "YOUR_PROJECT_ID:us-central1:mysql-instance"
  shippingPassword: "..."
  ratingsPassword:  "..."
create:
  mongodb: false
  mysql: false
  rabbitmq: false
  redis: false
```

**Accessing the GKE Cluster**

```sh
# SSH to bastion host via IAP
gcloud compute ssh bastion-host --project ${GCP_PROJECT} --zone ${GCP_REGION}-a

# inside bastion:
gcloud container clusters get-credentials robot-shop-gke --region ${GCP_REGION} --project ${GCP_PROJECT} --internal-ip
kubectl get nodes
```

**Deploy with Helm** (from within bastion):

```sh
helm install robot-shop ./three-tier-architecture-demo-master/GKE/helm \
  -f ./my-values.yaml \
  --namespace robot-shop \
  --create-namespace
```

**Access your app:**

```sh
kubectl get services -o wide  # Wait until ADDRESS column has external IP
```
Go to: `http://<EXTERNAL-IP>:8080`  
_Example site (see above Image 3)!_

---

</details>

---

## :sparkles: Key Modifications from Upstream

- All infra resources (VPC, GKE, DBs, networking) provisioned via Terraform.
- All backends (MySQL, Redis, Mongo, RabbitMQ) use managed SaaS; in-cluster DBs disabled.
- Secure private GKE + Artifact Registry.
- Helm charts adapted for external data services, Cloud SQL proxy injected via sidecar for MySQL.

---

## :bulb: Improvements and Tips

- **Project badges and logos**: Added at the top for instant visual context.
- **Architecture section clarity**: Key GCP services use recognizable icons for fast reference.
- **Screenshots with context**: Visual cues for Kubernetes, MongoDB, and the running web app included.
- **Expandable details**: For setup steps and prerequisites, so your README is clean for newcomers.
- **Security best practices**: Secrets and IAM info highlighted, default DB deployment disabled.
- **Accessible documentation**: Full cross-linking and references to upstream sources.
- **Usage clarity**: Step-by-step guide with commands, placeholders, and practical variables.
- **Encouraged contributions**: Noted at the bottom for issues and PRs.

---

## :book: References & Credits

- [instana/robot-shop](https://github.com/instana/robot-shop) (upstream application)
- [GoogleCloudPlatform/three-tier-architecture-demo](https://github.com/GoogleCloudPlatform/three-tier-architecture-demo) (original GKE configs)
- Custom infrastructure and SaaS adaptation in this repo.

---

## :page_facing_up: License

This project is licensed under the Apache License 2.0. See [LICENSE](./LICENSE).

---

*For issues or suggestions, open a pull request or GitHub issue. Screenshots in this README are for demonstration and onboarding reference.*
