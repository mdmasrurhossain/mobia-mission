resource "google_compute_subnetwork" "prod" {
  name                    = "prod"
  ip_cidr_range           = "10.10.2.0/24"
  region                  = "us-central1"
  network                 = google_compute_network.prod.id
  private_ip_google_access = true
  
  secondary_ip_range {
    range_name    = "prod-pod-range"
    ip_cidr_range = "10.3.0.0/20"
  }

  secondary_ip_range {
    range_name    = "prod-service-range"
    ip_cidr_range = "10.4.0.0/20"
  }
}