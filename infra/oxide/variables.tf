variable "project_name" {
  description = "Oxide project name"
  type        = string
}

variable "vpc_name" {
  description = "Name of the VPC"
  type        = string
}

variable "vpc_dns_name" {
  description = "DNS name for the VPC"
  type        = string
}

variable "vpc_description" {
  description = "Description of the VPC"
  type        = string
}

variable "instance_count" {
  description = "Number of nodes in the k3s cluster"
  type        = number
  default     = 3
}

variable "memory" {
  description = "Memory in bytes per node"
  type        = number
  default     = 4294967296
}

variable "ncpus" {
  description = "CPU count per node"
  type        = number
  default     = 2
}

variable "disk_size" {
  description = "Disk size in bytes"
  type        = number
  default     = 34359738368
}

variable "ubuntu_image_id" {
  description = "UUID of the Ubuntu image in Oxide"
  type        = string
}

variable "public_ssh_key" {
  description = "Public SSH key for Ansible provisioning"
  type        = string
}

variable "ansible_user" {
  description = "User for Ansible provisioning"
  type        = string
  default     = "ubuntu"
}

variable "k3s_version" {
  description = "K3s version to install"
  type        = string
  default     = "v1.30.2+k3s1"
}

variable "k3s_token" {
  description = "Token for joining k3s cluster"
  type        = string
  default     = "changeme!"
}

variable "server_count" {
  description = "Number of nodes to treat as servers"
  type        = number
  default     = 1
}
