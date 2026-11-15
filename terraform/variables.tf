variable "cloud_id" {
  description = "Yandex Cloud ID (yc config get cloud-id)."
  type        = string
}

variable "folder_id" {
  description = "Folder ID (yc config get folder-id)."
  type        = string
}

variable "zone" {
  type    = string
  default = "ru-central1-a"
}

variable "sa_key_file" {
  description = "Path to service account JSON key. null = use YC_TOKEN env var."
  type        = string
  default     = null
}

variable "name_prefix" {
  type    = string
  default = "demo"
}

variable "ssh_user" {
  type    = string
  default = "ubuntu"
}

variable "ssh_public_key_path" {
  type    = string
  default = "~/.ssh/id_ed25519.pub"
}

variable "ssh_private_key_path" {
  description = "Private key matching ssh_public_key_path (used by Ansible, not by Terraform)."
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "ssh_allowed_cidrs" {
  description = "CIDRs allowed to SSH in. Set to [\"<your-ip>/32\"]. Terraform itself needs access too."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "app_port" {
  description = "Public port of the application on the stage VM."
  type        = number
  default     = 8080
}

variable "boot_disk_type" {
  description = "Boot disk type of both VMs: network-hdd | network-ssd | network-ssd-nonreplicated."
  type        = string
  default     = "network-hdd"
}

variable "build_vm" {
  description = "Sizing of the build instance (Maven needs >= 4 GB RAM)."
  type = object({
    cores         = number
    memory        = number
    core_fraction = number
    disk_size     = number
    preemptible   = bool
  })
  default = {
    cores         = 2
    memory        = 4
    core_fraction = 50
    disk_size     = 10
    preemptible   = false
  }
}

variable "stage_vm" {
  type = object({
    cores         = number
    memory        = number
    core_fraction = number
    disk_size     = number
    preemptible   = bool
  })
  default = {
    cores         = 2
    memory        = 2
    core_fraction = 50
    disk_size     = 10
    preemptible   = false
  }
}
