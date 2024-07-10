resource "google_compute_firewall" "prod-firewall" {
  name    = "prod-firewall"
  network = google_compute_network.prod.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = [ "0.0.0.0/0" ]
}