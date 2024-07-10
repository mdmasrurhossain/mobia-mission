resource "google_container_cluster" "staging" {
  name                     = "staging"
  location                 = "us-central1"
  remove_default_node_pool = true
  initial_node_count       =   1
  network                  = google_compute_network.staging.self_link
  subnetwork               = google_compute_subnetwork.staging.self_link
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
    cluster_secondary_range_name  = "staging-pod-range"
    services_secondary_range_name = "staging-service-range"
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }
}