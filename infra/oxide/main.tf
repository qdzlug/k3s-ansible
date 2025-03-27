terraform {
  required_version = ">= 1.0"
  required_providers {
    oxide = {
      source  = "oxidecomputer/oxide"
      version = "0.5.0"
    }
  }
}

provider "oxide" {}

data "oxide_project" "k3s" {
  name = var.project_name
}

resource "oxide_ssh_key" "k3s" {
  name        = "k3s-key"
  description = "SSH key for k3s Ansible provisioning"
  public_key  = var.public_ssh_key
}

resource "oxide_vpc" "k3s" {
  name        = var.vpc_name
  dns_name    = var.vpc_dns_name
  description = var.vpc_description
  project_id  = data.oxide_project.k3s.id
}

data "oxide_vpc_subnet" "default" {
  project_name = data.oxide_project.k3s.name
  vpc_name     = oxide_vpc.k3s.name
  name         = "default"
}

resource "oxide_disk" "nodes" {
  for_each = { for i in range(var.instance_count) : i => "k3s-node-${i + 1}" }

  name            = each.value
  project_id      = data.oxide_project.k3s.id
  description     = "Disk for ${each.value}"
  size            = var.disk_size
  source_image_id = var.ubuntu_image_id
}

resource "oxide_instance" "nodes" {
  for_each = oxide_disk.nodes

  name             = each.value.name # Use the disk name (e.g., "k3s-node-1")
  project_id       = data.oxide_project.k3s.id
  boot_disk_id     = each.value.id
  description      = "K3s node ${each.value.name}"
  memory           = var.memory
  ncpus            = var.ncpus
  disk_attachments = [each.value.id]
  ssh_public_keys  = [oxide_ssh_key.k3s.id]
  start_on_create  = true
  host_name        = each.value.name # Ensure host_name also starts with a letter

  external_ips = [{
    type = "ephemeral"
  }]

  network_interfaces = [{
    name        = "nic-${each.value.name}"
    description = "Primary NIC"
    vpc_id      = data.oxide_vpc_subnet.default.vpc_id
    subnet_id   = data.oxide_vpc_subnet.default.id
  }]

  user_data = base64encode(<<-EOF
#!/bin/bash
echo "ubuntu ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ubuntu
chmod 0440 /etc/sudoers.d/ubuntu
EOF
  )
}


data "oxide_instance_external_ips" "nodes" {
  for_each    = oxide_instance.nodes
  instance_id = each.value.id
}

resource "local_file" "inventory_yaml" {
  filename = "${path.root}/../../inventory.yml"
  content = templatefile("${path.root}/templates/inventory.yml.tpl", {
    node_ips = [for i in data.oxide_instance_external_ips.nodes : i.external_ips[0].ip]
  })
}

