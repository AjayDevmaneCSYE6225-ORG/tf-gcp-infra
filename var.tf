variable "credentialsFile" {
  default = "csye6225-414121-ab8b9119fcca.json"
}

variable "projectId" {
  default = "csye6225-414121"
}

variable "region" {
  default     = "us-west2"
}

variable "webappSubnetCidr" {
  default     = "10.0.0.0/24"
}

variable "dbSubnetCidr" {
   default     = "10.0.1.0/24"
}

variable "num_vpcs" {
  description = "Number of VPCs to create"
  default="1"
}

variable "num_webapp_subnets_per_vpc" {
  description = "Number of subnets to create per VPC"
  default="1"
}

variable "num_db_subnets_per_vpc" {
  description = "Number of subnets to create per VPC"
  default="1"
}
