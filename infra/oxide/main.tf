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

  name             = each.value.name
  project_id       = data.oxide_project.k3s.id
  boot_disk_id     = each.value.id
  description      = "K3s node ${each.value.name}"
  memory           = var.memory
  ncpus            = var.ncpus
  disk_attachments = [each.value.id]
  ssh_public_keys  = [oxide_ssh_key.k3s.id]
  start_on_create  = true
  host_name        = each.value.name

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

resource "oxide_vpc_firewall_rules" "example" {
  vpc_id = oxide_vpc.k3s.id

  rules = [
    {
      action      = "allow"
      description = "Allow inbound TCP traffic on port 6443 (Kubernetes API) from anywhere."
      name        = "allow-k8s-api-6443"
      direction   = "inbound"
      priority    = 50
      status      = "enabled"
      filters = {
        hosts = [
          {
            type  = "ip_net"
            value = "0.0.0.0/0"
          }
        ]
        ports     = ["6443"]
        protocols = ["TCP"]
      }
      targets = [
        {
          type  = "subnet"
          value = data.oxide_vpc_subnet.default.name
        }
      ]
    },
    {
      action      = "allow"
      description = "Allow inbound SSH (TCP port 22) for all instances in the VPC."
      name        = "allow-ssh-22"
      direction   = "inbound"
      priority    = 60
      status      = "enabled"
      filters = {
        hosts = [
          {
            type  = "ip_net"
            value = "0.0.0.0/0"
          }
        ]
        ports     = ["22"]
        protocols = ["TCP"]
      }
      targets = [
        {
          type  = "subnet"
          value = data.oxide_vpc_subnet.default.name
        }
      ]
    },
    {
      action      = "allow"
      description = "Allow inbound ICMP (ping) for all instances in the VPC."
      name        = "allow-icmp"
      direction   = "inbound"
      priority    = 70
      status      = "enabled"
      filters = {
        hosts = [
          {
            type  = "ip_net"
            value = "0.0.0.0/0"
          }
        ]
        protocols = ["ICMP"]
      }
      targets = [
        {
          type  = "subnet"
          value = data.oxide_vpc_subnet.default.name
        }
      ]
    },
    {
      action      = "allow"
      description = "Allow all inbound traffic from other instances within the VPC."
      name        = "allow-internal-vpc"
      direction   = "inbound"
      priority    = 80
      status      = "enabled"
      filters = {
        hosts = [
          {
            type  = "vpc"
            value = oxide_vpc.k3s.name
          }
        ]
      }
      targets = [
        {
          type  = "subnet"
          value = data.oxide_vpc_subnet.default.name
        }
      ]
    }
  ]
}

data "oxide_instance_external_ips" "nodes" {
  for_each    = oxide_instance.nodes
  instance_id = each.value.id
}

locals {
  sorted_instance_keys = sort(keys(oxide_instance.nodes))
  node_ips = [
    for k in local.sorted_instance_keys :
    data.oxide_instance_external_ips.nodes[k].external_ips[0].ip
  ]
  api_endpoint = local.node_ips[0]
}

locals {
  extra_inventory_lines = "\n    api_endpoint: \"{{ hostvars[groups['server'][0]].ansible_default_ipv4.address }}\"\n    extra_server_args: \"--tls-san {{ hostvars[groups['server'][0]].ansible_default_ipv4.address }} --tls-san {{ hostvars[groups['server'][0]]['ansible_host'] | default(groups['server'][0]) }}\""
}

resource "local_file" "inventory_yaml" {
  filename = "${path.root}/../../inventory.yml"
  content  = format(
    "%s%s",
    templatefile("${path.root}/templates/inventory.yml.tpl", {
      node_ips     = local.node_ips
      server_count = var.server_count
    }),
    local.extra_inventory_lines
  )
}

