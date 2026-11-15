output "registry_id" {
  value = yandex_container_registry.this.id
}

output "registry_repo" {
  description = "Image repository without tag; the tag is chosen by the pipeline."
  value       = "cr.yandex/${yandex_container_registry.this.id}/${var.name_prefix}"
}

output "build_public_ip" {
  value = module.build.public_ip
}

output "stage_public_ip" {
  value = module.stage.public_ip
}

output "stage_internal_ip" {
  value = module.stage.internal_ip
}

output "ssh_user" {
  value = var.ssh_user
}

output "app_port" {
  value = var.app_port
}

output "app_url" {
  value = "http://${module.stage.public_ip}:${var.app_port}/"
}
