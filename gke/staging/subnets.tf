resource "google_compute_subnetwork" "staging" {
  name                    = "staging"
  ip_cidr_range           = "10.10.1.0/24"
  region                  = "us-central1"
  network                 = google_compute_network.staging.id
  private_ip_google_access = true
  
  secondary_ip_range {
    range_name    = "staging-pod-range"
    ip_cidr_range = "10.1.0.0/20"
  }

  secondary_ip_range {
    range_name    = "staging-service-range"
    ip_cidr_range = "10.2.0.0/20"
  }
}