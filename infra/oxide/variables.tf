variable "project_name" {
  description = "Oxide project name"
  type        = string
}

variable "vpc_name" {
  type        = string
  description = "Name of the VPC"
}

variable "vpc_dns_name" {
  type        = string
  description = "DNS name for the VPC"
}

variable "vpc_description" {
  type        = string
  description = "Description of the VPC"
}

variable "instance_count" {
  type        = number
  description = "Number of nodes in the k3s cluster"
  default     = 3
}

variable "memory" {
  type        = number
  description = "Memory in bytes per node"
  default     = 4294967296
}

variable "ncpus" {
  type        = number
  description = "CPU count per node"
  default     = 2
}

variable "disk_size" {
  type        = number
  description = "Disk size in bytes"
  default     = 34359738368
}

variable "ubuntu_image_id" {
  type        = string
  description = "UUID of the Ubuntu image in Oxide"
}

variable "public_ssh_key" {
  type        = string
  description = "Public SSH key for Ansible provisioning"
}

variable "ansible_user" {
  type        = string
  default     = "ubuntu"
}

variable "k3s_version" {
  type        = string
  default     = "v1.30.2+k3s1"
}

variable "k3s_token" {
  type        = string
  default     = "changeme!"
}

variable "server_count" {
  description = "Number of nodes to treat as servers"
  type        = number
  default     = 3
}
