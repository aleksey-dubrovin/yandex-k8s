variable "yandex_cloud_token" {
  type = string
  sensitive = true
}

variable "cloud_id" {
  type = string
}

variable "folder_id" {
  type = string
}

variable "vm_name" {
  type    = string
  default = "microk8s"
}

variable "zone" {
  type    = string
  default = "ru-central1-d"
}

variable "public_key_path" {
  type    = string
  default = "~/.ssh/rsa_id.pub"
}

variable "cores" {
  type    = number
  default = 2
}

variable "memory" {
  type    = number
  default = 4
}
variable "fraction" {
  type = number
  default = 50
}
  
variable "disk_size" {
  type    = number
  default = 20
}