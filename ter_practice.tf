provider "google" {
  project = "amarinov-terraform-practice"
  zone    = "europe-west2-a"
}

resource "google_compute_network" "nat-marinov" {
  name = "nat-marinov"
  mtu  = 1422
  auto_create_subnetworks = false
  project = "amarinov-terraform-practice"
  routing_mode = "REGIONAL"
}



resource "google_compute_subnetwork" "marinov-subnet" {
  name          = "marinov-subnet"
  ip_cidr_range = "192.124.3.0/24"
  region        = "europe-west2"
  network       = google_compute_network.nat-marinov.id
}



resource "google_compute_firewall" "allow-internal-marinov" {
  name    = "allow-internal-marinov"
  network = google_compute_network.nat-marinov.name

  allow {
    protocol = "icmp"
  }

  allow {
    protocol = "tcp"
    ports    = ["1-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["1-65535"]
  }

  source_ranges = ["192.124.3.0/24"]
  priority = 65530
}



resource "google_compute_firewall" "allow-ssh-iap" {
  name    = "allow-ssh-iap"
  network = google_compute_network.nat-marinov.name
  direction = "INGRESS"

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["10.10.0.0/16"]
  target_tags = ["allow-ssh"]
}



resource "google_compute_instance" "marinov-instance" {
  name         = "marinov-instance"
  machine_type = "n2-standard-4"
  zone         = "europe-west2-a"

  tags = ["no-ip", "allow-ssh"]

  boot_disk {
    initialize_params {
      image = "https://www.googleapis.com/compute/v1/projects/centos-cloud/global/images/centos-7-v20210217"
    }
  }

  network_interface {
    subnetwork = "marinov-subnet"
  }
}



resource "google_compute_instance" "marinov-gateway" {
  name         = "marinov-gateway"
  machine_type = "n2-standard-4"
  zone         = "europe-west2-a"

  can_ip_forward  = true

  tags = ["nat", "allow-ssh"]

  boot_disk {
    initialize_params {
      image = "https://www.googleapis.com/compute/v1/projects/centos-cloud/global/images/centos-7-v20210217"
    }
  }

  network_interface {
    subnetwork = "marinov-subnet"
    access_config {

    }
  }

  metadata = {
  	startup-script = "#! /bin/bash sudo sh -c \"echo 1 > /proc/sys/net/ipv4/ip_forward\" sudo iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE"
  }
}

resource "google_compute_route" "no-ip-internet-route" {
  name        = "no-ip-internet-route"
  dest_range  = "0.0.0.0/0"
  network     = google_compute_network.nat-marinov.name
  
  next_hop_instance = "marinov-gateway"
  next_hop_instance_zone = "europe-west2-a"

  tags = ["no-ip"]

  priority = 800
}
