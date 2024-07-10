resource "google_compute_router_nat" "staging-nat" {
  name   = "staging-nat"
  router = google_compute_router.staging-router.name
  region = "us-central1"

  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"
  nat_ip_allocate_option             = "MANUAL_ONLY"

  subnetwork {
    name                    = google_compute_subnetwork.staging.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  nat_ips = [google_compute_address.staging-nat.self_link]
}

resource "google_compute_address" "staging-nat" {
  name = "staging-nat"
  network_tier = "PREMIUM"

  depends_on = [
    google_project_service.compute
  ]
}