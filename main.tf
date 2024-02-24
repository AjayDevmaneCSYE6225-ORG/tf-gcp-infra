# provider "google" {
#   credentials = file(var.credentialsFile)
#   project     = var.projectId
#   region      = var.region
# }

# resource "google_compute_network" "vpc" {
#   name                    = "csye-vpc"
#   auto_create_subnetworks = false
#   routing_mode            = "REGIONAL"
#   delete_default_routes_on_create = true
# }

# resource "google_compute_subnetwork" "webapp_subnet" {
#   name          = "webapp"
#   region        = var.region
#   network       = google_compute_network.vpc.self_link
#   ip_cidr_range = var.webappSubnetCidr
# }

# resource "google_compute_subnetwork" "db_subnet" {
#   name          = "db"
#   region        = var.region
#   network       = google_compute_network.vpc.self_link
#   ip_cidr_range = var.dbSubnetCidr
# }

# resource "google_compute_route" "webapp_route" {
#   name                  = "webapp-route"
#   network               = google_compute_network.vpc.self_link
#   dest_range            = "0.0.0.0/0"
#   next_hop_gateway      = "default-internet-gateway"
#   priority              = 1000
#   tags                  = ["webapp"]
# }

provider "google" {
  credentials = file(var.credentialsFile)
  project     = var.projectId
  region      = var.region
}

resource "google_compute_network" "vpc" {

  name                            = "csye-vpc"
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "webapp_subnet" {

  name          = "csye-webapp-subnet"
  region        = var.region
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = var.webappSubnetCidr
}

resource "google_compute_subnetwork" "db_subnet" {

  name          = "csye-db"
  region        = var.region
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = var.dbSubnetCidr
}

resource "google_compute_route" "webapp_route" {

  name             = "webapp-route"
  network          = google_compute_network.vpc.self_link
  dest_range       = var.dest_range
  next_hop_gateway = var.next_hop_gateway
  priority         = 1000
  tags             = ["webapp"]
}

resource "google_compute_address" "default" {
  project      = var.projectId
  name         = "ipv4-address"
  address_type = var.address_type
  ip_version   = var.ip_version
}

resource "google_compute_instance" "default" {
  name         = "csye-instance"
  machine_type = var.machine_type
  zone         = var.zone

  boot_disk {
    initialize_params {
      image = "projects/csye6225-414121/global/images/my-custom-image"
      size  = 100
      type  = "pd-balanced"
    }
  }

  network_interface {
    network    = google_compute_network.vpc.self_link
    subnetwork = google_compute_subnetwork.webapp_subnet.self_link
    access_config {
      nat_ip = google_compute_address.default.address
    }
  }

  service_account {
    email  = "packer-buildmi-sa@csye6225-414121.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }

  tags = ["webapp"]

}

resource "google_compute_firewall" "firewallsRules" {

  name    = "firewall-rule"
  network = google_compute_network.vpc.self_link
  allow {
    protocol = "tcp"
    ports    = [var.port]
  }

  priority  = 1000
  direction = "INGRESS"

  source_ranges = [var.dest_range]
  target_tags   = ["webapp"]
}