# mobia-mission

## Project Description

This project focuses on deploying individual GKE cluster using Terraform and autmating an application deployment
using Github Actions pipeline. This project contains following

- Create GKE cluster
- Helm chart for k8s application deployment
- Python-flask application deployment
- Github Actions Automation


## Requirements

To run this project following should be installed locally:

- Terraform >=v1.3.2
- Google Cloud SDK >=405.0.0
- Git version >=2.38.0
- Python >=3.8.10
- Docker version >=20.10.10, build b485636 (for testing locally)
- Helm >=v3.10.1 (For testing locally)
- GCP
- Github Actions

## Local Development Environment

To deploy the flask application locallay follow the steps:

- Clone the git repo
- Change $PORT in **Dockerfile** to **8080**
- from the repo root run the following command to build the image
    ```
    docker image build -t flask_docker .
    ```
- After the image is built, run the following command to run the application in the background
    ```
    docker run -p 8080:8080 -d flask_docker
    ```
- Run following command to check the output:
    ```
    curl http://localhost:8080
    ```
- The output will show **Hello Mobia!**


## Bringing a GKE cluster UP

gke folder contains 2 seperate modules for deploying gke cluster. One for production and another for staging.

Both of them contains the following configuration files:

- provider.tf
- vpc.tf
- subnets.tf
- router.tf
- nat.tf
- firewall.tf
- kubernetes.tf
- node-pools.tf


provider.tf contains the GCP project information and the GCS bucket that contains the tfstate files. Change the project ID and gcs bucket as required.

```
provider "google" {
    project = "GKE_CLUSTER_PROJECT_ID"
    region  = "us-central1"
}

terraform {
  backend "gcs" {
    bucket = "GKE_CLUSTER_TF_BUCKET"
    prefix = "terraform/env"
  }
  required_providers {
    google = {
        source  = "hashicorp/google"
        version = "~> 4.0"
    }
  }
}
```

vpc.tf, subnets.tf, router.tf, nat.tf, firewall.tf contain the network information for the GKE cluster. Modify it as required.


kubernets.tf and node-pools.tf are responsible for creating the control pane and node pools for the GKE cluster. Change location to deploy the GKE cluster in either region or in a zone.

```
resource "google_container_cluster" "GKE_CLUSTER_NAME" {
  name                     = "GKE_CLUSTER_NAME"
  location                 = "GKE_CLUSTER_REGION"
  remove_default_node_pool = true
  initial_node_count       =   1
  network                  = google_compute_network.main.self_link
  subnetwork               = google_compute_subnetwork.private.self_link
  logging_service          = "logging.googleapis.com/kubernetes"
  monitoring_service       = "monitoring.googleapis.com/kubernetes"
  networking_mode          = "VPC_NATIVE" 

  node_locations = [
    "us-central1-a",
    "us-central1-b"
  ]

  addons_config {
    http_load_balancing {
        disabled = true
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }
  
  release_channel {
    channel = "REGULAR"
  }

  ip_allocation_policy {
    cluster_secondary_range_name  = "k8s-pod-range"
    services_secondary_range_name = "k8s-service-range"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
}
```

node-pools.tf containes the nodes in a cluster. Modify the file as per your requirement of the nodes. It also contains the service account with permission |
for pulling from container registry and communicate with cloud plateform.

```
resource "google_service_account" "kubernetes" {
  account_id = "kubernetes"
}

resource "google_container_node_pool" "general" {
  name       = "general"
  cluster    = google_container_cluster.production.id
  node_count = 2

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = false
    machine_type = "e2-small"

    labels = {
      role = "general"
    }

    service_account = google_service_account.kubernetes.email
    oauth_scopes = [
        "https://www.googleapis.com/auth/cloud-platform",
        "https://www.googleapis.com/auth/devstorage.read_only",

    ]
  }
}
```

To bring a GKE cluster following commands needs to run from the respective gke/prod or gke/staging folder

###### For authenticationg with GCP account
```
gcloud auth application-default login
```

###### Bringing up the GKE cluster
```
terraform apply
```

It will take about 20-30 min to create all the resources and bring the gke cluster up

###### Connecting to GKE cluster
Once terraform creates all resources, you can check the status of a cluster by first connecting to the cluster

```
 gcloud container clusters get-credentials GKE_CLUSTER_NAME --region GKE_CLUSTER_REGION --project GKE_CLUSTER_PROJECT_ID
```

After that run following to get the list of cluster to verify that GKE cluster creation is completed

```
kubectl get nodes
```

## Python-flask application

In the project a simple 'Hello World' python-flask is build and deployed using Github Actions

app.py contais the code for application.

```
import os

from flask import Flask

app = Flask(__name__)


@app.route('/')
def hello_world():
    target = os.environ.get('TARGET', 'Mobia')
    return 'Hello {}!\n'.format(target)


if __name__ == "__main__":
    app.run(debug=True, host='0.0.0.0', port=int(os.environ.get('PORT', 8080)))

```


## Github Actions

.github/workflows/build.yaml contains the stages and jobs for the fully automated CICD pipeline.

It contains different stages for Github Actions to go through. Following are the stages:

```
stages:
  - lint_test
  - pytest
  - build
  - deploy_feature
  - test_feature
  - stop_feature
  - deploy_stage
  - test_stage
  - deploy_prod
```

Each stage corresponds to a job in the .github/workflows/build.yaml file. A brief description of the stages are given below.

###### lint_test & pytest stage

Itontains lint_test and pytest job. They are for checking for stylistic or app logic error in the application code.

###### build stage

build stage contain task to dockerize the python-flask application, tag it and push it to GCP contaner registry.

Dockerfile contains the steps for building the application.

```
FROM python:3.8.0-slim
WORKDIR /app
ADD . /app
RUN pip install --upgrade pip
RUN pip install -r requirements.txt
CMD exec gunicorn app:app --bind 0.0.0.0:$PORT
```

###### Deploy feature and automated feature testing

Both of these stages are for deploying application on a temporary environment and testing the feature before it goes to staging and production

###### Stop feature
This a manual step for destroying the temporary environment.  **.github/workflows/build.yaml** contains this stage.

```
name: Build and Test Artifact

on:
  workflow_call:
  workflow_dispatch:
    inputs:
      environmentName:
        description: 'The name of the environment to deploy to. Used for `yarn run static-ENVIRONMENT` command.'
        required: true

env:
  GCP_PROJECT_NAME: mobia-mission
  FEATURE_NAMESPACE: mobia-feature
  GKE_CLUSTER_NAME_STAGING: staging
  IMAGE_REPOSITORY: "mobia-mission"
  IMAGE_APP_NAME: "mobia-flask"
  GKE_LOCATION: us-central1
  USE_GKE_GCLOUD_AUTH_PLUGIN: True  


jobs:
  stop_feature:
    runs-on: ubuntu-latest
    environment:
      name: feature/$GITHUB_REF_SLUG
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Set up Google Cloud SDK
        uses: google-github-actions/setup-gcloud@v1.1.1
        with:
          project_id: ${{ env.GCP_PROJECT_NAME }}
          service_account_key: ${{ secrets.SERVICE_ACCOUNT_KEY }}

      - id: 'auth'
        uses: 'google-github-actions/auth@v1'
        with:
          credentials_json: '${{ secrets.SERVICE_ACCOUNT_KEY }}'

      - id: 'get-credentials'
        uses: 'google-github-actions/get-gke-credentials@v1'
        with:
          cluster_name: '${{ env.GKE_CLUSTER_NAME_STAGING }}'
          location: 'us-central1'

      - name: Setup helm
        run: |
          chmod +x ./get_helm.sh
          ./get_helm.sh
        shell: bash
          
      - name: Authentication with GKE
        run: |
          gcloud components install gke-gcloud-auth-plugin
          gcloud container clusters get-credentials ${{ env.GKE_CLUSTER_NAME_STAGING }} --region us-central1 --project ${{ env.GCP_PROJECT_NAME_STAGING }}

      - name: Stop feature environment
        run: |
          helm uninstall python-flask -n ${{ env.FEATURE_NAMESPACE }}

```

###### Deploy staging and automated testing
In Deploy staging stage a google cloud sdk container is used to authenticate with the staging GKE cluster and use Helm Charts to deploy the python-flask application

```
deploy_stage:
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/staging'
    environment:
      name: staging
    steps:               
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Set up Google Cloud SDK
        uses: google-github-actions/setup-gcloud@v1.1.1
        with:
          project_id: ${{ env.GCP_PROJECT_NAME }}
          service_account_key: ${{ secrets.SERVICE_ACCOUNT_KEY }}

      - id: 'auth'
        uses: 'google-github-actions/auth@v1'
        with:
          credentials_json: '${{ secrets.SERVICE_ACCOUNT_KEY }}'

      - id: 'get-credentials'
        uses: 'google-github-actions/get-gke-credentials@v1'
        with:
          cluster_name: '${{ env.GKE_CLUSTER_NAME_STAGING }}'
          location: 'us-central1'

      - name: Setup helm
        run: |
          chmod +x ./get_helm.sh
          ./get_helm.sh
        shell: bash
          
      - name: Get version SHA
        run: |
          echo "VERSION=$(echo ${{ github.sha }} | cut -c1-8)" >> $GITHUB_ENV

      - name: Kubernetes cluster context change
        run: |
          gcloud components install gke-gcloud-auth-plugin
          gcloud container clusters get-credentials ${{ env.GKE_CLUSTER_NAME_STAGING }} --region us-central1 --project ${{ env.GCP_PROJECT_NAME }}
          sed -i "s/<VERSION>/${{ env.VERSION }}/g" helm/python-deployment/values.yaml

      - name: Apply helm 
        run: |
          helm upgrade --install python-flask -n ${{ env.STAGING_NAMESPACE }} helm/python-deployment
```

While automated testing stage is used for testing the aopplication after deployment.

```
  test_stage:
    runs-on: ubuntu-latest
    needs: deploy_stage
    if: github.ref == 'refs/heads/staging'
    steps:
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Set up Google Cloud SDK
        uses: google-github-actions/setup-gcloud@v1.1.1
        with:
          project_id: ${{ env.GCP_PROJECT_NAME }}
          service_account_key: ${{ secrets.SERVICE_ACCOUNT_KEY }}

      - id: 'auth'
        uses: 'google-github-actions/auth@v1'
        with:
          credentials_json: '${{ secrets.SERVICE_ACCOUNT_KEY }}'

      - id: 'get-credentials'
        uses: 'google-github-actions/get-gke-credentials@v1'
        with:
          cluster_name: '${{ env.GKE_CLUSTER_NAME_STAGING }}'
          location: 'us-central1'

      - name: Test staging environment
        run: |
          gcloud components install gke-gcloud-auth-plugin
          gcloud container clusters get-credentials ${{ env.GKE_CLUSTER_NAME_STAGING }} --region us-central1 --project ${{ env.GCP_PROJECT_NAME }}
          kubectl get svc -n ${{ env.STAGING_NAMESPACE }} | awk '{print $4}' | grep -v "EXTERNAL-IP" | while read -r line; do curl "http://$line"; done | grep "Hello Mobia!"
```

###### Deploy prod

if all the other stages passed, deploy prod stage is ready to deploy the application on production GKE cluster. A switch has been implemented here to manually deploy
on prodcution cluster

```
  deploy_prod:
    runs-on: ubuntu-latest
    needs: build
    if: github.ref == 'refs/heads/main'
    environment:
      name: prod
    steps:               
      - name: Checkout code
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Set up Google Cloud SDK
        uses: google-github-actions/setup-gcloud@v1.1.1
        with:
          project_id: ${{ env.GCP_PROJECT_NAME }}
          service_account_key: ${{ secrets.SERVICE_ACCOUNT_KEY }}

      - id: 'auth'
        uses: 'google-github-actions/auth@v1'
        with:
          credentials_json: '${{ secrets.SERVICE_ACCOUNT_KEY }}'

      - id: 'get-credentials'
        uses: 'google-github-actions/get-gke-credentials@v1'
        with:
          cluster_name: '${{ env.GKE_CLUSTER_NAME_PROD }}'
          location: 'us-central1'

      - name: Setup helm
        run: |
          chmod +x ./get_helm.sh
          ./get_helm.sh
        shell: bash
          
      - name: Get version SHA
        run: |
          echo "VERSION=$(echo ${{ github.sha }} | cut -c1-8)" >> $GITHUB_ENV

      - name: Kubernetes cluster context change
        run: |
          gcloud components install gke-gcloud-auth-plugin
          gcloud container clusters get-credentials ${{ env.GKE_CLUSTER_NAME_PROD }} --region us-central1 --project ${{ env.GCP_PROJECT_NAME }}
          sed -i "s/<VERSION>/${{ env.VERSION }}/g" helm/python-deployment/values.yaml

      - name: Apply helm 
        run: |
          helm upgrade --install python-flask -n ${{ env.PROD_NAMESPACE }} helm/python-deployment
```
###### HELM Packaging

Helm charts is used to create the k8s template for the application and install the application on the GKE cluster.

```
helm install python-flask -n $GKE_NAMESPACE helm/python-deployment
```

###### Checking  the application

To check the application that are running in GKE cluster. Use following command:

```
kubectl get pods -n GKE_APPLICATION_NAMESPACE
```

You can also use curl to get the content of the application running on the pod

```
curl http://EXTERNAL_IP
```

EXTERNAL_IP can be found from the application service

```
kubectl get svc -n GKE_APPLICATION_NAMESPACE
```
