terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
}

#потом вынести в переменные среды
locals {
  cloud_id  = "b1gklhrcrgeagtrkql4a"
  folder_id = "b1gcirasqg53q97lgl7j"
}

provider "yandex" {
  service_account_key_file = "authorized_key.json"
  cloud_id                 = local.cloud_id
  folder_id                = local.folder_id
  zone                     = "ru-central1-a"
}

resource "yandex_vpc_network" "web_network" {
  name = "web-network"
}

resource "yandex_vpc_subnet" "web_subnet" {
  name           = "web-subnet"
  zone           = "ru-central1-a"
  network_id     = yandex_vpc_network.web_network.id
  v4_cidr_blocks = ["10.0.1.0/24"]
}

resource "yandex_vpc_security_group" "web_sg" {
  name       = "web-security-group"
  network_id = yandex_vpc_network.web_network.id

  ingress {
    protocol       = "TCP"
    port           = 80
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 443
    v4_cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol       = "TCP"
    port           = 22
    v4_cidr_blocks = ["0.0.0.0/0"] #лучше было б внести конкретные адреса, но как есть
  }

  egress {
    protocol       = "ANY"
    v4_cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "yandex_compute_instance" "web_instance_1" {
  name        = "web-instance-1"
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd82odtq5h79jo7ffss3"
      size     = 10
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id         = yandex_vpc_subnet.web_subnet.id
    nat               = true
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }

  metadata = {
    user-data = file("cloud-init.yaml")
  }
}

resource "yandex_compute_instance" "web_instance_2" {
  name        = "web-instance-2"
  platform_id = "standard-v3"

  resources {
    cores  = 2
    memory = 2
  }

  boot_disk {
    initialize_params {
      image_id = "fd82odtq5h79jo7ffss3"
      size     = 10
      type     = "network-ssd"
    }
  }

  network_interface {
    subnet_id         = yandex_vpc_subnet.web_subnet.id
    nat               = true
    security_group_ids = [yandex_vpc_security_group.web_sg.id]
  }

  metadata = {
    user-data = file("cloud-init.yaml")
  }
}

resource "yandex_lb_target_group" "web_target_group" {
  name = "web-target-group"

  target {
    subnet_id = yandex_vpc_subnet.web_subnet.id
    address   = yandex_compute_instance.web_instance_1.network_interface.0.ip_address
  }

  target {
    subnet_id = yandex_vpc_subnet.web_subnet.id
    address   = yandex_compute_instance.web_instance_2.network_interface.0.ip_address
  }
}

resource "yandex_lb_network_load_balancer" "web_lb" {
  name = "web-load-balancer"

  listener {
    name        = "http-listener"
    port        = 80
    target_port = 80
    protocol    = "tcp"
  }

  listener {
    name        = "https-listener"
    port        = 443
    target_port = 443
    protocol    = "tcp"
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.web_target_group.id
    healthcheck {
      name = "http"
      http_options {
        port = 80
        path = "/"
      }
    }
  }
}
