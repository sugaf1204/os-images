packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "= 1.1.3"
    }
  }
}

variable "source_url" {
  type = string
}

variable "source_checksum" {
  type = string
}

variable "output_directory" {
  type = string
}

variable "ssh_username" {
  type = string
}

variable "ssh_private_key_file" {
  type = string
}

variable "ssh_public_key" {
  type = string
}

variable "ssh_timeout" {
  type    = string
  default = "10m"
}

variable "apt_packages" {
  type    = string
  default = ""
}

variable "apt_install_recommends" {
  type    = string
  default = "true"
}

variable "baremetal_driver_packages" {
  type    = string
  default = ""
}

variable "disk_size" {
  type    = string
  default = "0"
}

variable "vm_memory" {
  type    = string
  default = "2048"
}

variable "vm_cpus" {
  type    = string
  default = "2"
}

variable "qemu_accelerator" {
  type    = string
  default = ""
}

locals {
  user_data                  = <<-EOF
    #cloud-config
    ssh_authorized_keys:
      - ${var.ssh_public_key}
    users:
      - default
    EOF
  gomi_cloud_init            = "datasource_list: [ NoCloud, None ]\ndatasource:\n  NoCloud:\n    seedfrom: file:///var/lib/cloud/seed/nocloud/\n"
  apt_install_recommends_arg = var.apt_install_recommends == "true" ? "" : "--no-install-recommends"
}

source "qemu" "qcow2" {
  iso_url      = var.source_url
  iso_checksum = var.source_checksum

  disk_image       = true
  format           = "qcow2"
  output_directory = var.output_directory
  vm_name          = "root.qcow2"
  accelerator      = var.qemu_accelerator == "" ? null : var.qemu_accelerator
  cpus             = var.vm_cpus
  memory           = var.vm_memory

  efi_boot          = true
  efi_drop_efivars  = true
  efi_firmware_code = "/usr/share/OVMF/OVMF_CODE_4M.fd"
  efi_firmware_vars = "/usr/share/OVMF/OVMF_VARS_4M.fd"

  headless         = true
  skip_compaction  = true
  skip_resize_disk = var.disk_size == "0" || var.disk_size == ""
  disk_size        = var.disk_size
  disk_compression = false
  shutdown_command = "sudo shutdown -P now"
  shutdown_timeout = "5m"

  ssh_username         = var.ssh_username
  ssh_private_key_file = var.ssh_private_key_file
  ssh_timeout          = var.ssh_timeout

  cd_label = "CIDATA"
  cd_content = {
    "meta-data" = "instance-id: gomi-os-images-packer\nlocal-hostname: gomi-os-images-packer\n"
    "user-data" = local.user_data
  }
}

build {
  sources = ["source.qemu.qcow2"]

  provisioner "shell" {
    inline = [
      "sudo cloud-init status --wait || true",
      "if [ -n '${var.baremetal_driver_packages}' ]; then driver_packages=\"$(printf '%s' '${var.baremetal_driver_packages}' | sed \"s/{kernel_release}/$(uname -r)/g\")\"; sudo apt-get update; sudo DEBIAN_FRONTEND=noninteractive apt-get install -y $driver_packages; sudo apt-get clean; sudo rm -rf /var/lib/apt/lists/*; fi",
      "if [ -n '${var.apt_packages}' ]; then sudo apt-get update; sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ${local.apt_install_recommends_arg} ${var.apt_packages}; sudo apt-get clean; sudo rm -rf /var/lib/apt/lists/*; fi",
      "sudo mkdir -p /etc/cloud/cloud.cfg.d",
      "printf '%s' '${local.gomi_cloud_init}' | sudo tee /etc/cloud/cloud.cfg.d/99-gomi-nocloud.cfg >/dev/null",
      "sudo rm -f /home/${var.ssh_username}/.ssh/authorized_keys",
      "sudo rm -f /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub",
      "sudo rm -f /var/lib/dbus/machine-id",
      "sudo truncate -s 0 /etc/machine-id || true",
      "sudo cloud-init clean --logs --seed || true"
    ]
  }
}
