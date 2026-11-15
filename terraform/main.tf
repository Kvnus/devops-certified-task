locals {
  labels = {
    project = var.name_prefix
    managed = "terraform"
  }
  ssh_public_key = file(pathexpand(var.ssh_public_key_path))

}

# ---------------------------------------------------------------- network
module "network" {
  source            = "./modules/network"
  name              = var.name_prefix
  zone              = var.zone
  ssh_allowed_cidrs = var.ssh_allowed_cidrs
  app_ports         = [var.app_port]
  labels            = local.labels
}

# ----------------------------------------- artifact repository (native)
resource "yandex_container_registry" "this" {
  name      = "${var.name_prefix}-registry"
  folder_id = var.folder_id
  labels    = local.labels
}

resource "yandex_iam_service_account" "build" {
  name = "${var.name_prefix}-build-sa"
}

resource "yandex_iam_service_account" "stage" {
  name = "${var.name_prefix}-stage-sa"
}

resource "yandex_container_registry_iam_binding" "pusher" {
  registry_id = yandex_container_registry.this.id
  role        = "container-registry.images.pusher"
  members     = ["serviceAccount:${yandex_iam_service_account.build.id}"]
}

resource "yandex_container_registry_iam_binding" "puller" {
  registry_id = yandex_container_registry.this.id
  role        = "container-registry.images.puller"
  members     = ["serviceAccount:${yandex_iam_service_account.stage.id}"]
}

# ------------------------------------------------------------ build VM
module "build" {
  source = "./modules/vm"

  name               = "${var.name_prefix}-build"
  zone               = var.zone
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.network.security_group_id]
  cores              = var.build_vm.cores
  memory             = var.build_vm.memory
  core_fraction      = var.build_vm.core_fraction
  boot_disk_size     = var.build_vm.disk_size
  boot_disk_type     = var.boot_disk_type
  preemptible        = var.build_vm.preemptible
  public_ip          = true
  service_account_id = yandex_iam_service_account.build.id
  ssh_user           = var.ssh_user
  ssh_public_key     = local.ssh_public_key
  labels             = merge(local.labels, { role = "build" })

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    role           = "build"
    extra_packages = []
    app_port       = var.app_port
  })
}

# ------------------------------------------------------------- stage VM
resource "yandex_vpc_address" "stage" {
  name = "${var.name_prefix}-stage-ip"
  external_ipv4_address {
    zone_id = var.zone
  }
}

module "stage" {
  source = "./modules/vm"

  name               = "${var.name_prefix}-stage"
  zone               = var.zone
  subnet_id          = module.network.subnet_id
  security_group_ids = [module.network.security_group_id]
  cores              = var.stage_vm.cores
  memory             = var.stage_vm.memory
  core_fraction      = var.stage_vm.core_fraction
  boot_disk_size     = var.stage_vm.disk_size
  boot_disk_type     = var.boot_disk_type
  preemptible        = var.stage_vm.preemptible
  public_ip          = true
  nat_ip_address     = yandex_vpc_address.stage.external_ipv4_address[0].address
  service_account_id = yandex_iam_service_account.stage.id
  ssh_user           = var.ssh_user
  ssh_public_key     = local.ssh_public_key
  labels             = merge(local.labels, { role = "stage" })

  user_data = templatefile("${path.module}/templates/cloud-init.yaml.tpl", {
    role           = "stage"
    extra_packages = []
    app_port       = var.app_port
  })
}
