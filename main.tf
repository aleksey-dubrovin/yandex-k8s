terraform {
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = "~> 0.108"
    }
  }
}

provider "yandex" {
  token     = var.yandex_cloud_token
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

resource "yandex_vpc_network" "k8s" {
  name = var.vm_name
}

resource "yandex_vpc_subnet" "k8s" {
  name           = var.vm_name
  zone           = var.zone
  network_id     = yandex_vpc_network.k8s.id
  v4_cidr_blocks = ["192.168.72.0/24"]
}

resource "yandex_vpc_security_group" "k8s" {
  name       = var.vm_name
  network_id = yandex_vpc_network.k8s.id

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 22
    description    = "SSH"
  }

  ingress {
    protocol       = "TCP"
    description    = "HTTP for Load Balancer"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 80
  }

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    port           = 16443
    description    = "Kubernetes API"
  }

  ingress {
    protocol       = "TCP"
    v4_cidr_blocks = ["0.0.0.0/0"]
    from_port      = 30000
    to_port        = 32767
    description    = "Kubernetes NodePorts"
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
    description    = "Allow all outgoing"
  }
}

# 1. Целевая группа
resource "yandex_lb_target_group" "k8s" {
  name      = "${var.vm_name}-tg"
  region_id = "ru-central1"

  target {
    subnet_id = yandex_vpc_subnet.k8s.id
    address   = yandex_compute_instance.k8s.network_interface[0].ip_address
  }
}

# 2. Сетевой балансировщик
resource "yandex_lb_network_load_balancer" "k8s" {
  name = "${var.vm_name}-lb"
  region_id = "ru-central1"
  listener {
    name = "http-listener"
    port = 80
    # Внешний балансировщик (для доступа из интернета) [citation:5]
    external_address_spec {
      ip_version = "ipv4"
    }
}

  attached_target_group {
    target_group_id = yandex_lb_target_group.k8s.id

    healthcheck {
      name = "http"
      # Проверка будет выполняться к вашему Ingress-контроллеру [citation:1][citation:2]
      http_options {
        port = 30306
        path = "/"
      }
    }
  }
}

data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

resource "yandex_compute_instance" "k8s" {
  name        = var.vm_name
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores  = var.cores
    memory = var.memory
    core_fraction = var.fraction
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = var.disk_size
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id          = yandex_vpc_subnet.k8s.id
    nat                = true
    security_group_ids = [yandex_vpc_security_group.k8s.id]
  }

  metadata = {
    ssh-keys = "ubuntu:${chomp(file(var.public_key_path))}"
    user-data = "${file("./cloud-init.yaml")}"
  }

  scheduling_policy {
    preemptible = true
  }

}