provider "google" {
  credentials = file(var.credentialsFile)
  project     = var.projectId
  region      = var.region
}
# creating vpc
resource "google_compute_network" "vpc" {

  name                            = "csye-vpc"
  auto_create_subnetworks         = false
  routing_mode                    = var.routing_mode
  delete_default_routes_on_create = true
}

# creating webapp subnet
resource "google_compute_subnetwork" "webapp_subnet" {

  name          = "csye-webapp-subnet"
  region        = var.region
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = var.webappSubnetCidr
}

# creating db subnet
resource "google_compute_subnetwork" "db_subnet" {

  name          = "csye-db"
  region        = var.region
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = var.dbSubnetCidr
}

# creating webapp route
resource "google_compute_route" "webapp_route" {

  name             = "webapp-route"
  network          = google_compute_network.vpc.self_link
  dest_range       = var.dest_range
  next_hop_gateway = var.next_hop_gateway
  priority         = 1000
  tags             = ["webapp"]
}

resource "google_compute_firewall" "firewall_allow_rule" {
  name    = "firewall-allow-rule"
  network = google_compute_network.vpc.self_link

  allow {
    protocol = "tcp"
    ports    = [var.port]
  }

  priority      = 1000
  direction     = "INGRESS"
  source_ranges = [var.dest_range]
  target_tags   = ["webapp"]
}


# creating firewall
resource "google_compute_firewall" "firewall_deny_rule" {
  name    = "firewall-deny-rule"
  network = google_compute_network.vpc.self_link

  deny {
    protocol = "tcp"
    ports    = ["22"]
  }

  priority      = 1000
  direction     = "INGRESS"
  source_ranges = [var.dest_range]
  target_tags   = ["webapp"]
}

#creating global ip address
#resource "google_compute_global_address" "default" {
#  provider     = google-beta
#  project      = google_compute_network.vpc.project
#  name         = "global-psconnect-ip"
#  address_type = "INTERNAL"
#  purpose      = "PRIVATE_SERVICE_CONNECT"
#  network      = google_compute_network.vpc.id
#  address      = "10.3.0.5"
#}

resource "google_compute_global_address" "private_ip_block" {
  name          = "private-ip-block"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  ip_version    = var.ip_version
  prefix_length = 20
  network       = google_compute_network.vpc.self_link
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc.self_link
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_block.name]
}


#forwarding rule for load balancing
#resource "google_compute_global_forwarding_rule" "default" {
#  provider              = google-beta
#  project               = google_compute_network.vpc.project
#  name                  = "globalrule"
#  target                = "all-apis"
#  network               = google_compute_network.vpc.id
#  ip_address            = google_compute_global_address.default.id
#  load_balancing_scheme = ""
#}

#creating database instance

resource "google_sql_database_instance" "mysql_db_instance" {
  name             = "mysql-db-instance"
  region           = var.region
  database_version = "MYSQL_8_0"
  depends_on       = [google_service_networking_connection.private_vpc_connection]
  #  root_password    = var.root_password
  #  project          = var.projectId
  settings {
    tier              = "db-f1-micro"
    availability_type = var.routing_mode
    disk_type         = "pd-ssd"
    disk_size         = 100
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.vpc.self_link
    }
    backup_configuration {
      enabled            = true
      binary_log_enabled = true
    }
  }
  deletion_protection = false
}

#creating database
resource "google_sql_database" "database" {
  name     = "webapp"
  instance = google_sql_database_instance.mysql_db_instance.name
}

#creating user

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_sql_user" "user" {
  name     = "webapp"
  instance = google_sql_database_instance.mysql_db_instance.name
  password = random_password.password.result
}

# creating vpc instance
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
      #       nat_ip = google_compute_address.default.address
    }
  }

  service_account {
    email  = "packer-buildmi-sa@csye6225-414121.iam.gserviceaccount.com"
    scopes = ["cloud-platform"]
  }

  tags = ["webapp"]

  metadata_startup_script = <<-SCRIPT
#!/bin/bash

sudo bash -c 'cat <<EOF > /opt/unzippedWebapp/Assignment02/.env
DB_USERNAME=webapp
DB_NAME=webapp
DB_PASSWORD=${random_password.password.result}
DB_HOST=${google_sql_database_instance.mysql_db_instance.private_ip_address}
PORT=3000
EOF'
sudo chown -R csye6225:csye6225 /opt/unzippedWebapp/Assignment02
sudo chmod -R 755 /opt/unzippedWebapp/Assignment02
sudo systemctl restart csye6225.service


SCRIPT

}

