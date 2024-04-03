provider "google" {
  #  credentials = file(var.credentialsFile)
  project = var.projectId
  region  = var.region
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
    ports    = [var.port, 22]
  }

  priority = 1000
  # direction     = "INGRESS"
  source_ranges = [var.dest_range]
  target_tags   = ["webapp"]
}

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
  length  = 16
  special = false
  # override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "google_sql_user" "user" {
  name     = "webapp"
  instance = google_sql_database_instance.mysql_db_instance.name
  password = random_password.password.result
}

# resource "google_dns_record_set" "a_record" {
#   name         = "ajaydevmane.me."
#   managed_zone = "ajay-devmane-zone"
#   type         = "A"
#   ttl          = 60
#   rrdatas      = [google_compute_instance_template.regional_template.network_interface[0].access_config[0].nat_ip]
# }

#creating service account
resource "google_service_account" "service_account_iam" {
  account_id   = "service-account-iam-id"
  display_name = "Service Account with IAM role"
}

#setting iam role to service account
resource "google_project_iam_binding" "project" {
  project = var.projectId

  role = "roles/logging.admin"
  members = [
    "serviceAccount:${google_service_account.service_account_iam.email}"
  ]
}

resource "google_project_iam_binding" "project_monitoring" {
  project = var.projectId

  role = "roles/monitoring.metricWriter"
  members = [
    "serviceAccount:${google_service_account.service_account_iam.email}"
  ]
}

resource "google_project_iam_binding" "service_account_pub" {
  project = var.projectId
  role    = "roles/pubsub.publisher"
  members = [
    "serviceAccount:${google_service_account.service_account_iam.email}",
  ]
}

resource "google_service_account" "cloudfunction_service_acount" {
  account_id   = "cloudfunction-account-id"
  display_name = "cloudfunction-service-account-dispName"
  depends_on   = [google_pubsub_topic.verify_email]
}

resource "google_project_iam_binding" "cloud-function-invoker" {
  project = var.projectId
  role    = "roles/run.invoker"
  members = ["serviceAccount:${google_service_account.cloudfunction_service_acount.email}"]
}

resource "google_project_iam_binding" "cloud-function-mysqlclient" {
  project = var.projectId
  role    = "roles/cloudsql.client"
  members = ["serviceAccount:${google_service_account.cloudfunction_service_acount.email}"]
}

resource "google_project_iam_binding" "cloud-function-sub" {
  project = var.projectId
  role    = "roles/pubsub.subscriber"
  members = ["serviceAccount:${google_service_account.cloudfunction_service_acount.email}"]
}

resource "google_project_iam_binding" "cf_service_account_vpc_connector" {
  project = var.projectId
  role    = "roles/vpcaccess.user"
  members = ["serviceAccount:${google_service_account.cloudfunction_service_acount.email}"]
}

# creating vm instance
# resource "google_compute_instance" "default" {
#   name         = "csye-instance"
#   machine_type = var.machine_type
#   zone         = var.zone

#   #  allow_stopping_for_update = true
#   depends_on = [google_project_iam_binding.project_monitoring]

#   boot_disk {
#     initialize_params {
#       image = "projects/csye6225-414121/global/images/my-custom-image"
#       size  = 100
#       type  = "pd-balanced"
#     }
#   }

#   network_interface {
#     network    = google_compute_network.vpc.self_link
#     subnetwork = google_compute_subnetwork.webapp_subnet.self_link
#     access_config {
#       #       nat_ip = google_compute_address.default.address
#     }
#   }

#   service_account {

#     email = google_service_account.service_account_iam.email

#     scopes = ["cloud-platform", "pubsub"]
#   }

#   tags = ["webapp"]

#   metadata_startup_script = <<-SCRIPT
# #!/bin/bash

# sudo bash -c 'cat <<EOF > /opt/unzippedWebapp/Assignment02/.env
# DB_USERNAME=webapp
# DB_NAME=webapp
# DB_PASSWORD=${random_password.password.result}
# DB_HOST=${google_sql_database_instance.mysql_db_instance.private_ip_address}
# PORT=3000
# EOF'
# sudo chown -R csye6225:csye6225 /opt/unzippedWebapp/Assignment02
# sudo chmod -R 755 /opt/unzippedWebapp/Assignment02
# sudo systemctl restart csye6225.service


# SCRIPT

# }

// google compute instance template

resource "google_compute_region_instance_template" "regional_template" {
  name        = "csye-instance-template"
  description = "Instance Template for CSYE Application"
  region      = var.region

  machine_type = var.machine_type

  disk {
    source_image = "projects/csye6225-414121/global/images/my-final-custom-image"
    disk_size_gb = 100
    disk_type    = "pd-balanced"
  }

  lifecycle {
    create_before_destroy = true
  }

  network_interface {
    network    = google_compute_network.vpc.self_link
    subnetwork = google_compute_subnetwork.webapp_subnet.self_link
    access_config {
      // Leave this blank for ephemeral IP
    }
  }

  service_account {
    email  = google_service_account.service_account_iam.email
    scopes = ["cloud-platform", "pubsub"]
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



resource "google_vpc_access_connector" "my_connector" {
  name          = "my-vpc-connector"
  network       = google_compute_network.vpc.self_link
  ip_cidr_range = "10.8.0.0/28"
}
resource "google_pubsub_topic" "verify_email" {
  name                       = "verify_email"
  message_retention_duration = "604800s"
  message_storage_policy {
    allowed_persistence_regions = [var.region]
  }
}

# resource "google_pubsub_subscription" "verify_email_subscription" {
#   name  = "verify-email-subscription"
#   topic = google_pubsub_topic.verify_email.name
#   push_config {
#     push_endpoint = "https://your-cloud-function-url"
#   }
# }

resource "google_cloudfunctions2_function" "verify_email" {
  name        = var.name_cloud_function
  location    = var.region
  description = "Send verification emails"

  build_config {
    runtime     = var.cloud_function_runtime
    entry_point = var.entry_point
    source {
      storage_source {
        bucket = "cloud_function-bucket"
        object = "FORK_serverless.zip"
      }
    }
  }

  service_config {
    max_instance_count    = 1
    min_instance_count    = 1
    available_cpu         = "1"
    available_memory      = var.cloud_function_available_memory_mb
    timeout_seconds       = var.cloud_function_timeout
    service_account_email = google_service_account.cloudfunction_service_acount.email
    vpc_connector         = google_vpc_access_connector.my_connector.self_link

    environment_variables = {
      MAILGUN_API_KEY = var.MAILGUN_API_KEY
      WEBAPP_URL      = var.WEBAPP_URL
      DB_USERNAME     = google_sql_user.user.name
      DATABASE        = google_sql_database.database.name
      PASSWORD        = random_password.password.result
      HOST            = google_sql_database_instance.mysql_db_instance.private_ip_address
    }

  }

  event_trigger {
    event_type            = "google.cloud.pubsub.topic.v1.messagePublished"
    pubsub_topic          = google_pubsub_topic.verify_email.id
    retry_policy          = "RETRY_POLICY_RETRY"
    trigger_region        = var.region
    service_account_email = google_service_account.cloudfunction_service_acount.email
  }

  depends_on = [google_pubsub_topic.verify_email]
}

//creating health check

# resource "google_compute_health_check" "webapp-health-check" {
#   name               = "webapp-health-check"
#   request_path       = "/healthz"
#   check_interval_sec = 10
#   timeout_sec        = 5
# }

resource "google_compute_health_check" "webapp-health-check" {
  name                = "webapp-health-check"
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 10

  http_health_check {
    request_path = "/healthz"
    port         = var.port
  }
}

//creating instance group manager
# resource "google_compute_instance_group_manager" "myapp-instance-group" {
#   name               = "myapp-instance-group"
#   base_instance_name = "myapp-instance"
#   instance_template  = google_compute_instance_template.myapp-template.self_link
#   target_size        = 2 # Initial number of instances
#   zone               = "us-central1-a"

#   named_port {
#     name = "http"
#     port = 80
#   }

#   auto_healing_policies {
#     initial_delay_sec = 300
#   }

#   update_policy {
#     minimal_action          = "REPLACE"
#     type                    = "PROACTIVE"
#     max_surge_percent       = 50
#     max_unavailable_percent = 50
#   }

#   depends_on = [google_compute_autoscaler.myapp-autoscaler]
# }

resource "google_compute_region_instance_group_manager" "webapp-instance-group" {
  name               = "webapp-instance-group"
  base_instance_name = "webapp"
  region             = var.region

  version {
    instance_template = google_compute_region_instance_template.regional_template.self_link
  }

  # target_pools = [google_compute_target_pool.appserver.id]
  # target_size  = 2

  named_port {
    name = "http"
    port = var.port
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.webapp-health-check.id
    initial_delay_sec = 300
  }
}

//creating region autoscaler
resource "google_compute_region_autoscaler" "webapp-autoscaler" {
  name   = "webapp-autoscaler"
  region = var.region
  target = google_compute_region_instance_group_manager.webapp-instance-group.self_link

  autoscaling_policy {
    max_replicas    = 6
    min_replicas    = 3
    cooldown_period = 60

    cpu_utilization {
      target = 0.05
    }
  }
}

module "gce-lb-http" {
  source      = "terraform-google-modules/lb-http/google"
  version     = "~> 10.0"
  project     = var.projectId
  name        = "group-http-lb"
  target_tags = ["webapp"]

  ssl                             = true
  managed_ssl_certificate_domains = ["ajaydevmane.me"]
  http_forward                    = false
  create_address                  = true
  network                         = google_compute_network.vpc.self_link
  backends = {
    default = {
      port_name   = "http"
      protocol    = "HTTP"
      timeout_sec = 10
      enable_cdn  = false

      health_check = {
        request_path = "/healthz"
        port         = 3000
      }

      log_config = {
        enable      = true
        sample_rate = 1.0
      }

      groups = [
        {
          group = google_compute_region_instance_group_manager.webapp-instance-group.instance_group
        },
      ]

      iap_config = {
        enable = false
      }

      firewall_networks = [google_compute_network.vpc.name]
    }
  }
}
resource "google_dns_record_set" "a_record" {
  name         = "ajaydevmane.me."
  managed_zone = "ajay-devmane-zone"
  type         = "A"
  ttl          = 60
  rrdatas      = [module.gce-lb-http.external_ip]
}