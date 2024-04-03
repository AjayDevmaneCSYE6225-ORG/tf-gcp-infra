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

variable "root_password" {
  default = "Hello@123"
}

variable "name_cloud_function" {
  default = "my_cloud_function"
}

variable "MAILGUN_API_KEY" {
  default = "8122f07832c4275014ebfb69e57188e8-f68a26c9-60050ad1"
}

variable "entry_point" {
  default = "helloPubSub"
}

variable "cloud_function_runtime" {
  default = "nodejs18"
}
variable "cloud_function_available_memory_mb" {
  default = "256M"
}

variable "cloud_function_timeout" {
  default = 540
}

variable "WEBAPP_URL" {
  default = "http://localhost:3000/v1/user/verifyUser"
}