# os-images

Minimal mkosi-based rootfs image pipeline for GOMI.

## Build

```sh
scripts/build-all
```

Artifacts are written under `dist/<image>/`:

- `rootfs.squashfs`
- `manifest.json`
- `SHA256SUMS`

Images:

- `debian-12`
- `debian-13`
- `ubuntu-22.04`
- `ubuntu-24.04`
- `ubuntu-26.04`
- `fedora-44`

## Requirements

- Linux x86_64 build host
- `mkosi`
- `mksquashfs` from `squashfs-tools`
- `bootctl` from `systemd-boot`

The images intentionally build completed target root filesystems. GOMI should
not ask curtin to install a replacement kernel or refresh packages for these
artifacts.
