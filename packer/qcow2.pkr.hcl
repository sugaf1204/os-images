packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = "= 1.1.4"
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

locals {
  user_data = <<-EOF
    #cloud-config
    ssh_authorized_keys:
      - ${var.ssh_public_key}
    users:
      - default
    EOF
  gomi_cloud_init = "datasource_list: [ NoCloud, None ]\ndatasource:\n  NoCloud:\n    seedfrom: file:///var/lib/cloud/seed/nocloud/\n"
}

source "qemu" "qcow2" {
  iso_url      = var.source_url
  iso_checksum = var.source_checksum

  disk_image       = true
  format           = "qcow2"
  output_directory = var.output_directory
  vm_name          = "root.qcow2"

  efi_boot          = true
  efi_drop_efivars  = true
  efi_firmware_code = "/usr/share/OVMF/OVMF_CODE_4M.fd"
  efi_firmware_vars = "/usr/share/OVMF/OVMF_VARS_4M.fd"

  headless          = true
  skip_compaction   = true
  skip_resize_disk  = true
  disk_compression  = false
  shutdown_command  = "sudo shutdown -P now"
  shutdown_timeout  = "5m"

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
