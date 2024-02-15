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

locals {
  vpc_names = [for i in range(var.num_vpcs) : "csye-vpc-${i}"]
}

resource "google_compute_network" "vpc" {
  count                   = var.num_vpcs
  name                    = local.vpc_names[count.index]
  auto_create_subnetworks = false
  routing_mode            = "REGIONAL"
  delete_default_routes_on_create = true
}

resource "google_compute_subnetwork" "webapp_subnet" {
  count         = var.num_vpcs * var.num_webapp_subnets_per_vpc
  name          = "webapp-${count.index}"
  region        = var.region
  network       = google_compute_network.vpc[floor(count.index / var.num_webapp_subnets_per_vpc)].self_link
  ip_cidr_range = "10.${count.index}.0.0/24"
}

resource "google_compute_subnetwork" "db_subnet" {
  count         = var.num_vpcs * var.num_db_subnets_per_vpc
  name          = "db-${count.index}"
  region        = var.region
  network       = google_compute_network.vpc[floor(count.index / var.num_db_subnets_per_vpc)].self_link
  ip_cidr_range = "10.${count.index + 100}.0.0/24"
}

resource "google_compute_route" "webapp_route" {
  count                 = var.num_vpcs
  name                  = "webapp-route-${count.index}"
  network               = google_compute_network.vpc[count.index].self_link
  dest_range            = "0.0.0.0/0"
  next_hop_gateway      = "default-internet-gateway"
  priority              = 1000
  tags                  = ["webapp"]
}
