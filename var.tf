variable "credentialsFile" {
  default = "csye6225-414121-ab8b9119fcca.json"
}

variable "projectId" {
  default = "csye6225-414121"
}

variable "region" {
  default = "us-west2"
}

variable "zone" {
  default = "us-west2-a"
}

variable "webappSubnetCidr" {
  default = "10.0.0.0/24"
}

variable "dbSubnetCidr" {
  default = "10.0.1.0/24"
}

variable "num_vpcs" {
  description = "Number of VPCs to create"
  default     = "1"
}

variable "num_webapp_subnets_per_vpc" {
  description = "Number of subnets to create per VPC"
  default     = "1"
}

variable "num_db_subnets_per_vpc" {
  description = "Number of subnets to create per VPC"
  default     = "1"
}

variable "port" {
  description = "Port Number"
  default     = "3000"
}

variable "routing_mode" {
  description = "Routing Mode"
  default     = "REGIONAL"
}

variable "dest_range" {
  description = "Destination range"
  default     = "0.0.0.0/0"
}

variable "next_hop_gateway" {
  default = "default-internet-gateway"
}

variable "address_type" {
  default = "EXTERNAL"
}

variable "ip_version" {
  default = "IPV4"
}

variable "machine_type" {
  default = "n2-standard-2"
}