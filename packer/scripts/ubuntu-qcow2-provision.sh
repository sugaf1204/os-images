#!/bin/sh
set -eu

export DEBIAN_FRONTEND=noninteractive

drivers="r8169 e1000e igb igc ixgbe alx atlantic tg3 bnx2"

is_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "install ok installed"
}

is_available() {
  apt-cache show "$1" >/dev/null 2>&1
}

install_if_missing() {
  missing_packages=""
  for pkg in "$@"; do
    if ! is_installed "$pkg"; then
      missing_packages="$missing_packages $pkg"
    fi
  done
  if [ -n "$missing_packages" ]; then
    # shellcheck disable=SC2086
    apt-get install -y --no-install-recommends $missing_packages
  fi
}

install_if_available() {
  missing_packages=""
  for pkg in "$@"; do
    if is_available "$pkg" && ! is_installed "$pkg"; then
      missing_packages="$missing_packages $pkg"
    fi
  done
  if [ -n "$missing_packages" ]; then
    # shellcheck disable=SC2086
    apt-get install -y --no-install-recommends $missing_packages
  fi
}

apt-get update

keep_abi="$(uname -r)"
keep_kernel="linux-image-$keep_abi"

install_if_missing ca-certificates cloud-init curl kmod netplan.io openssh-server sudo systemd-sysv
install_if_available "linux-modules-extra-$keep_abi" amd64-microcode intel-microcode linux-firmware-realtek

if is_available linux-firmware-realtek; then
  is_installed linux-firmware-realtek || {
    echo "linux-firmware-realtek is available but not installed" >&2
    exit 1
  }
fi

purge_packages="$(
  dpkg-query -W -f='${Package}\n' 2>/dev/null | awk -v keep_kernel="$keep_kernel" -v keep_abi="$keep_abi" '
    $0 == "linux-firmware" { print; next }
    /^linux-firmware-/ && $0 != "linux-firmware-realtek" { print; next }
    /^linux-headers-/ { print; next }
    /^linux-image-[0-9].*-generic/ && $0 != keep_kernel { print; next }
    /^linux-modules-[0-9].*-generic/ && $0 != "linux-modules-" keep_abi { print; next }
    /^linux-modules-extra-[0-9].*-generic/ && $0 != "linux-modules-extra-" keep_abi { print; next }
    /^linux-main-modules-zfs-[0-9].*-generic/ && $0 != "linux-main-modules-zfs-" keep_abi { print; next }
    /^linux-tools-/ { print; next }
    $0 == "linux-generic" { print; next }
    $0 == "linux-headers-generic" { print; next }
    $0 == "linux-image-virtual" { print; next }
    $0 == "linux-image-generic" { print; next }
    $0 == "linux-perf" { print; next }
    $0 == "linux-virtual" { print; next }
    $0 == "linux-headers-virtual" { print; next }
    $0 == "bpftool" { print; next }
    $0 == "bpfcc-tools" { print; next }
    $0 == "bpftrace" { print; next }
    $0 == "ubuntu-kernel-accessories" { print; next }
  '
)"

if [ -n "$purge_packages" ]; then
  # shellcheck disable=SC2086
  apt-get purge -y $purge_packages
fi

apt-get autoremove -y --purge

test -n "$keep_kernel" || { echo "kernel package name not found" >&2; exit 1; }
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

if is_installed linux-firmware; then
  echo "forbidden monolithic linux-firmware package is installed" >&2
  exit 1
fi

mkdir -p /etc/cloud/cloud.cfg.d
cat >/etc/cloud/cloud.cfg.d/99_gomi_nocloud.cfg <<'EOF'
datasource_list: [ NoCloud, None ]
ssh_deletekeys: false
EOF

update-initramfs -u -k "$keep_abi"

dpkg-query -W -f='${db:Status-Abbrev} ${Package} ${Version}\n' 'linux-*' 2>/dev/null |
  awk '$1 ~ /^ii/ { print $2, $3 }' |
  sort
dpkg-query -W -f='${db:Status-Abbrev} ${Package} ${Version}\n' 'linux-firmware*' '*microcode' 2>/dev/null |
  awk '$1 ~ /^ii/ { print $2, $3 }' |
  sort
du -sh /boot /usr/lib/modules /usr/lib/firmware 2>/dev/null || true
