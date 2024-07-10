provider "google" {
    project = "mobia-mission"
    region  = "us-central1"
}

terraform {
  backend "gcs" {
    bucket = "mobia-remotebackend"
    prefix = "terraform/prod"
  }
  required_providers {
    google = {
        source  = "hashicorp/google"
        version = "~> 4.0"
    }
  }
}