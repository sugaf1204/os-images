#!/bin/sh
set -eu

drivers="r8169 e1000e igb igc ixgbe alx atlantic tg3 bnx2"
dnf_install_opts="-y --disablerepo=* --setopt=install_weak_deps=False"

is_installed() {
  rpm -q "$1" >/dev/null 2>&1
}

for cmd in cloud-init dnf dracut modinfo rpm sshd sudo; do
  command -v "$cmd" >/dev/null || {
    echo "missing required command in Fedora Cloud image: $cmd" >&2
    exit 1
  }
done

mount_input() {
  mkdir -p /mnt/qcow2-input
  mountpoint -q /mnt/qcow2-input || mount -o ro /dev/sr0 /mnt/qcow2-input
}

keep_abi="$(uname -r)"
had_kernel_modules=0
had_kernel_modules_extra=0
is_installed kernel-modules && had_kernel_modules=1
is_installed kernel-modules-extra && had_kernel_modules_extra=1

mount_input

if ! is_installed microcode_ctl; then
  dnf install $dnf_install_opts /mnt/qcow2-input/microcode_ctl-*.rpm
fi
if ! is_installed realtek-firmware; then
  dnf install $dnf_install_opts /mnt/qcow2-input/linux-firmware-whence-*.rpm /mnt/qcow2-input/realtek-firmware-*.rpm
fi

dnf install $dnf_install_opts \
  /mnt/qcow2-input/kernel-modules-"$keep_abi".rpm \
  /mnt/qcow2-input/kernel-modules-extra-"$keep_abi".rpm

is_installed microcode_ctl || {
  echo "microcode_ctl is not installed" >&2
  exit 1
}
is_installed realtek-firmware || {
  echo "realtek-firmware is not installed" >&2
  exit 1
}

for pkg in \
  amd-gpu-firmware \
  atheros-firmware \
  brcmfmac-firmware \
  cirrus-audio-firmware \
  intel-audio-firmware \
  intel-gpu-firmware \
  iwlegacy-firmware \
  iwlwifi-dvm-firmware \
  iwlwifi-mvm-firmware \
  libertas-firmware \
  linux-firmware \
  mellanox-firmware \
  mrvlprestera-firmware \
  mt7xxx-firmware \
  netronome-firmware \
  nvidia-gpu-firmware \
  qcom-firmware \
  qed-firmware; do
  if is_installed "$pkg"; then
    rpm -e --nodeps "$pkg"
  fi
done

test -e "/boot/vmlinuz-$keep_abi" || {
  echo "missing /boot/vmlinuz-$keep_abi" >&2
  exit 1
}
test -d "/usr/lib/modules/$keep_abi" || {
  echo "missing /usr/lib/modules/$keep_abi" >&2
  exit 1
}

missing_drivers=""
for driver in $drivers; do
  if ! modinfo "$driver" >/dev/null 2>&1; then
    missing_drivers="$missing_drivers $driver"
  fi
done
if [ -n "$missing_drivers" ]; then
  echo "missing consumer wired NIC drivers:$missing_drivers" >&2
  exit 1
fi

if [ "$had_kernel_modules" = 0 ] || [ "$had_kernel_modules_extra" = 0 ]; then
  module_stash="$(mktemp -d)"
  visited_modules=" "

  copy_module_closure() {
    module="$1"
    case "$visited_modules" in
      *" $module "*) return 0 ;;
    esac
    visited_modules="$visited_modules$module "

    module_file="$(modinfo -n "$module" 2>/dev/null || true)"
    if [ -n "$module_file" ] && [ -f "$module_file" ]; then
      module_file="$(readlink -f "$module_file")"
      mkdir -p "$module_stash/$(dirname "$module_file")"
      cp -a "$module_file" "$module_stash/$module_file"
    fi

    module_deps="$(modinfo -F depends "$module" 2>/dev/null | tr ',' ' ' || true)"
    for dep in $module_deps; do
      [ -n "$dep" ] && copy_module_closure "$dep"
    done
  }

  for driver in $drivers; do
    copy_module_closure "$driver"
  done

  remove_modules=""
  [ "$had_kernel_modules_extra" = 0 ] && is_installed kernel-modules-extra && remove_modules="$remove_modules kernel-modules-extra"
  [ "$had_kernel_modules" = 0 ] && is_installed kernel-modules && remove_modules="$remove_modules kernel-modules"
  if [ -n "$remove_modules" ]; then
    # shellcheck disable=SC2086
    rpm -e --nodeps $remove_modules
  fi

  if [ -d "$module_stash/usr" ]; then
    cp -a "$module_stash/usr" /
  fi
  rm -rf "$module_stash"
  depmod "$keep_abi"

  missing_drivers=""
  for driver in $drivers; do
    if ! modinfo "$driver" >/dev/null 2>&1; then
      missing_drivers="$missing_drivers $driver"
    fi
  done
  if [ -n "$missing_drivers" ]; then
    echo "missing consumer wired NIC drivers after module pruning:$missing_drivers" >&2
    exit 1
  fi
fi

if is_installed linux-firmware; then
  echo "forbidden monolithic linux-firmware package is installed" >&2
  exit 1
fi

mkdir -p /etc/cloud/cloud.cfg.d
cat >/etc/cloud/cloud.cfg.d/99_gomi_nocloud.cfg <<'EOF'
datasource_list: [ NoCloud, None ]
ssh_deletekeys: false
EOF

dracut -f --kver "$keep_abi"

rpm -qa 'kernel*' '*firmware*' 'microcode*' | sort
du -sh /boot /usr/lib/modules /usr/lib/firmware /lib/firmware 2>/dev/null || true
