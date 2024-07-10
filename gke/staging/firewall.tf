resource "google_compute_firewall" "staging-firewall" {
  name    = "staging-firewall"
  network = google_compute_network.staging.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [ "0.0.0.0/0" ]
}