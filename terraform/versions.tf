terraform {
  required_version = ">= 1.3"
  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.120"
    }
  }
}

# Auth: either `export YC_TOKEN=$(yc iam create-token)` or sa_key_file.
provider "yandex" {
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
  service_account_key_file = var.sa_key_file == null ? null : pathexpand(var.sa_key_file)
}
