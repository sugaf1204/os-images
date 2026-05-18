packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.4"
    }
  }
}

variable "image_name" {
  type = string
}

variable "source_image" {
  type = string
}

variable "source_checksum" {
  type = string
}

variable "output_directory" {
  type = string
}

variable "vm_name" {
  type = string
}

variable "disk_size" {
  type    = string
  default = "8G"
}

variable "ssh_private_key_file" {
  type = string
}

variable "ssh_public_key_file" {
  type = string
}

variable "provision_script" {
  type = string
}

variable "cd_files" {
  type    = list(string)
  default = []
}

variable "qemu_accelerator" {
  type    = string
  default = "tcg"
}

source "qemu" "cloud" {
  iso_url      = var.source_image
  iso_checksum = var.source_checksum

  disk_image         = true
  disk_size          = var.disk_size
  format             = "qcow2"
  disk_compression   = true
  disk_discard       = "unmap"
  disk_detect_zeroes = "unmap"

  output_directory = var.output_directory
  vm_name          = var.vm_name

  accelerator    = var.qemu_accelerator
  boot_wait      = "5s"
  disk_interface = "virtio"
  headless       = true
  machine_type   = "q35"
  memory         = 2048
  net_device     = "virtio-net"
  ssh_timeout    = "20m"

  shutdown_command = <<-EOF
    sudo /bin/sh -c 'export DEBIAN_FRONTEND=noninteractive; if command -v apt-get >/dev/null 2>&1; then apt-get clean; rm -rf /var/lib/apt/lists/*; fi; if command -v dnf >/dev/null 2>&1; then dnf clean all || true; rm -rf /var/cache/dnf; fi; rm -rf /tmp/* /var/tmp/* /var/lib/cloud/*; rm -f /var/log/cloud-init.log /var/log/cloud-init-output.log /etc/ssh/ssh_host_*_key /etc/ssh/ssh_host_*_key.pub /var/lib/dbus/machine-id; truncate -s 0 /etc/machine-id; userdel -f -r packer >/dev/null 2>&1 || true; fstrim -av || true; sync; poweroff'
  EOF
  shutdown_timeout = "10m"

  ssh_username         = "packer"
  ssh_private_key_file = var.ssh_private_key_file

  cd_label = "cidata"
  cd_files = var.cd_files
  cd_content = {
    "meta-data" = "instance-id: ${var.image_name}\nlocal-hostname: ${var.image_name}\n"
    "user-data" = <<-EOF
      #cloud-config
      ssh_pwauth: false
      disable_root: true
      users:
        - default
        - name: packer
          gecos: Packer
          lock_passwd: true
          shell: /bin/bash
          sudo: ["ALL=(ALL) NOPASSWD:ALL"]
          ssh_authorized_keys:
            - ${trimspace(file(var.ssh_public_key_file))}
      EOF
  }
}

build {
  sources = ["source.qemu.cloud"]

  provisioner "shell" {
    script          = var.provision_script
    execute_command = "sudo -E sh -c '{{ .Vars }} {{ .Path }}'"
    skip_clean      = true
  }
}
