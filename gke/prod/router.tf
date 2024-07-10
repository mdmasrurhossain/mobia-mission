resource "google_compute_router" "prod-router" {
  name    = "prod-router"
  region  = "us-central1"
  network = google_compute_network.prod.id
}