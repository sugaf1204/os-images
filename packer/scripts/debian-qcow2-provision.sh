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

. /etc/os-release
codename="${VERSION_CODENAME:?missing VERSION_CODENAME}"

if ! grep -Rqs "non-free-firmware" /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null; then
  cat >/etc/apt/sources.list.d/consumer-wired-firmware.sources <<EOF
Types: deb
URIs: http://deb.debian.org/debian
Suites: $codename ${codename}-updates
Components: non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
fi

apt-get update

keep_abi="$(uname -r)"
keep_kernel="linux-image-$keep_abi"

install_if_missing ca-certificates cloud-init curl kmod openssh-server sudo systemd-sysv
install_if_available amd64-microcode firmware-realtek intel-microcode

if is_available firmware-realtek; then
  is_installed firmware-realtek || {
    echo "firmware-realtek is available but not installed" >&2
    exit 1
  }
fi

purge_packages="$(
  dpkg-query -W -f='${Package}\n' 2>/dev/null | awk -v keep_kernel="$keep_kernel" '
    /^firmware-/ && $0 != "firmware-realtek" { print; next }
    /^linux-headers-/ { print; next }
    /^linux-image-[0-9].*/ && $0 != keep_kernel { print; next }
    /^linux-tools-/ { print; next }
    $0 == "linux-image-amd64" { print; next }
    $0 == "linux-headers-amd64" { print; next }
    $0 == "bpftool" { print; next }
    $0 == "bpfcc-tools" { print; next }
    $0 == "bpftrace" { print; next }
  '
)"

if [ -n "$purge_packages" ]; then
  # shellcheck disable=SC2086
  apt-get purge -y $purge_packages
fi

apt-get autoremove -y --purge

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

if is_installed firmware-linux || is_installed firmware-misc-nonfree; then
  echo "forbidden broad Debian firmware package is installed" >&2
  exit 1
fi

mkdir -p /etc/cloud/cloud.cfg.d
cat >/etc/cloud/cloud.cfg.d/99_gomi_nocloud.cfg <<'EOF'
datasource_list: [ NoCloud, None ]
ssh_deletekeys: false
EOF

update-initramfs -u -k "$keep_abi"

dpkg-query -W -f='${db:Status-Abbrev} ${Package} ${Version}\n' 'linux-*' 'firmware-*' '*microcode' 2>/dev/null |
  awk '$1 ~ /^ii/ { print $2, $3 }' |
  sort
du -sh /boot /usr/lib/modules /usr/lib/firmware /lib/firmware 2>/dev/null || true
