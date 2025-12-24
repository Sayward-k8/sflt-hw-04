terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 0.13"
}

provider "yandex" {
  zone                     = "ru-central1-b"
  cloud_id                 = "b1g7nh3mcrueqtskec04"
  folder_id                = "b1g6pgeslh1op9ug76up"
  service_account_key_file = file("/home/vigonin/.authorized_key.json")
}

resource "yandex_compute_instance" "vm" {
  count       = 2
  name        = "vm${count.index}"
  platform_id = "standard-v1"
  boot_disk {
    initialize_params {
      image_id = "fd817upt6ubkr107osh7"
      size     = 10
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.my_subnet.id
    nat       = true
  }

  resources {
    cores  = 2
    memory = 2
  }

  metadata = {
    user-data = "${file("/home/vigonin/sflt-hw-04/cloud-init.txt")}"
  ssh-keys = "vigonin:${file("/home/vigonin/.ssh/terraform.pub")}" }
}

resource "yandex_vpc_network" "my_network" {
  name = "my_network"
}

resource "yandex_vpc_subnet" "my_subnet" {
  name           = "my_subnet"
  v4_cidr_blocks = ["172.22.15.0/24"]
  network_id     = yandex_vpc_network.my_network.id
}

resource "yandex_lb_network_load_balancer" "my-balancer" {
  name                = "my-balancer"
  deletion_protection = "false"
  listener {
    name = "my-lb"
    port = 80
    external_address_spec {
      ip_version = "ipv4"
    }
  }
  attached_target_group {
    target_group_id = yandex_lb_target_group.target-group.id
    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}

resource "yandex_lb_target_group" "target-group" {
  name = "target-group"

  dynamic "target" {
    for_each = yandex_compute_instance.vm
    content {
      subnet_id = yandex_vpc_subnet.my_subnet.id
      address   = target.value.network_interface.0.ip_address
    }
  }
}

