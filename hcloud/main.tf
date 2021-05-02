terraform {
  required_providers {
    hcloud = {
      source = "hetznercloud/hcloud"
      version = "1.26.0"
    }
  }
}

variable "hcloud_token" {}
variable "server_type" {}

provider "hcloud" {
  # Configuration options
  token = "${var.hcloud_token}"
}

resource "hcloud_ssh_key" "default" {
  name = "ssh key"
  public_key = file("~/.ssh/id_rsa.pub")
}

# add firewall
resource "hcloud_firewall" "firewall1" {
  name = "firewall1"
  rule {
   direction = "in"
   protocol = "tcp"
   source_ips = [
      "0.0.0.0/0",
      "::/0"
   ]
   port = "22"
  }
  rule {
   direction = "in"
   protocol = "tcp"
   source_ips = [
      "0.0.0.0/0",
      "::/0"
   ]
   port = "5000"
  }
  rule {
   direction = "in"
   protocol = "tcp"
   source_ips = [
      "0.0.0.0/0",
      "::/0"
   ]
   port = "5001"
  }
}

# Create servers
resource "hcloud_server" "node1" {
  name = "node1"
  image = "ubuntu-20.04"
  server_type = "${var.server_type}"
  backups = true
  ssh_keys = [ hcloud_ssh_key.default.id ]
  firewall_ids = [hcloud_firewall.firewall1.id]
  network {
    network_id = hcloud_network.internal-backplane.id
  }
  depends_on = [
    hcloud_network_subnet.subnet
  ]
  user_data = "${file("../cloud-init.yaml")}"

}
resource "hcloud_server" "node2" {
  name = "node2"
  image = "ubuntu-20.04"
  server_type = "${var.server_type}"
  backups = true
  ssh_keys = [ hcloud_ssh_key.default.id ]
  firewall_ids = [hcloud_firewall.firewall1.id]
  network {
    network_id = hcloud_network.internal-backplane.id
  }
  depends_on = [
    hcloud_network_subnet.subnet
  ]
  user_data = "${file("../cloud-init.yaml")}"
}
resource "hcloud_server" "node3" {
  name = "node3"
  image = "ubuntu-20.04"
  server_type = "${var.server_type}"
  backups = true
  ssh_keys = [ hcloud_ssh_key.default.id ]
  firewall_ids = [hcloud_firewall.firewall1.id]
  network {
    network_id = hcloud_network.internal-backplane.id
  }
  depends_on = [
    hcloud_network_subnet.subnet
  ]
  user_data = "${file("../cloud-init.yaml")}"
}

# reverse dns resources
resource "hcloud_rdns" "node1" {
  server_id = hcloud_server.node1.id
  ip_address = hcloud_server.node1.ipv4_address
  dns_ptr = "node1.local"
}
resource "hcloud_rdns" "node2" {
  server_id = hcloud_server.node2.id
  ip_address = hcloud_server.node2.ipv4_address
  dns_ptr = "node2.local"
}
resource "hcloud_rdns" "node3" {
  server_id = hcloud_server.node3.id
  ip_address = hcloud_server.node3.ipv4_address
  dns_ptr = "node3.local"
}

# configure internal backplane
resource "hcloud_network" "internal-backplane" {
  name = "internal-backplane"
  ip_range = "10.0.0.0/16"
}
resource "hcloud_network_subnet" "subnet" {
  network_id = hcloud_network.internal-backplane.id
  type = "server"
  network_zone = "eu-central"
  ip_range   = "10.0.0.0/24"
}


# add loadbalancer
resource "hcloud_load_balancer" "load_balancer" {
  name       = "lb"
  load_balancer_type = "lb11"
  location   = "nbg1"
  algorithm {
    type = "least_connections"
  }
}
resource "hcloud_load_balancer_network" "internal-backplane" {
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  network_id = hcloud_network.internal-backplane.id
}

resource "hcloud_load_balancer_service" "load_balancer_service_5000" {
    load_balancer_id = hcloud_load_balancer.load_balancer.id
    protocol = "tcp"
    listen_port = 5000
    destination_port = 5000
}

resource "hcloud_load_balancer_service" "load_balancer_service_5001" {
    load_balancer_id = hcloud_load_balancer.load_balancer.id
    protocol = "tcp"
    listen_port = 5001
    destination_port = 5001
}

resource "hcloud_load_balancer_target" "load_balancer_target_node1" {
  type = "server"
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  server_id = hcloud_server.node1.id
}

resource "hcloud_load_balancer_target" "load_balancer_target_node2" {
  type = "server"
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  server_id = hcloud_server.node2.id
}

resource "hcloud_load_balancer_target" "load_balancer_target_node3" {
  type = "server"
  load_balancer_id = hcloud_load_balancer.load_balancer.id
  server_id = hcloud_server.node3.id
}
