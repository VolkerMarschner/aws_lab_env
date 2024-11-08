# Global Variables
##############################
variable "region" {
  description = "AWS region"
  default     = "eu-central-1"
}

variable "prefix" {
  type        = string
  default    = "ICL-XX"
  description = "Prefix to be used in resource names"
}

# VPC related Variables
###############################

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR block for the public subnet"
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "CIDR block for the private subnet"
  default     = "10.0.2.0/24"
}

variable "vpc_name" {
  description = "Name tag for the VPC"
  default     = "VPC"
}

# SG related Variables maybe noot needed?
#############################

variable "linux_security_group_id" {
  description = "ID of the existing security group for Linux instances"
  default     = "string"
}

variable "windows_security_group_id" {
  description = "ID of the existing security group for Windows instances"
  default     = "string"
}

# EC2 Workload Instance related Variables
#############################

variable "linux_instance_count" {
  description = "Number of Linux instances to create"
  default     = 1
}

variable "windows_instance_count" {
  description = "Number of Windows instances to create"
  default     = 1
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t2.micro"
}


