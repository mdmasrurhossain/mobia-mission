resource "google_compute_router" "staging-router" {
  name    = "staging-router"
  region  = "us-central1"
  network = google_compute_network.staging.id
}