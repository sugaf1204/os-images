# os-images

Minimal OS image pipeline for GOMI.

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
- `packer` and QEMU tools for QCOW2 builds

The images intentionally build completed target root filesystems. GOMI should
not ask curtin to install a replacement kernel or refresh packages for these
artifacts.

## QCOW2 Build

```sh
scripts/build-qcow2 ubuntu-26.04
```

QCOW2 artifacts are written under `dist/<image>/`:

- `root.qcow2`
- `manifest.json`
- `SHA256SUMS`
- `qemu-img-info.txt`

`scripts/build-qcow2` supports the same image names as the squashfs builder:
`debian-12`, `debian-13`, `ubuntu-22.04`, `ubuntu-24.04`, `ubuntu-26.04`,
and `fedora-44`.

The QCOW2 path starts from each distribution's official cloud image and
customizes it with Packer's QEMU builder. The resulting image is a single
VM/Machine asset with `bootEnvironments: ["vm", "machine"]` and
`firmwareProfile: "consumer-wired"` in the manifest. It keeps wired consumer
NIC support for common Realtek/Intel/Broadcom/Aquantia adapters, installs
split Realtek firmware and Intel/AMD microcode where the OS exposes narrowly
scoped packages, and avoids wireless, graphics, Mellanox, Netronome, QLogic,
Marvell Prestera, and monolithic firmware packages.

The source image checksum is verified from the official checksum file before
Packer runs. The final QCOW2 must stay within 250 MiB of the official source
image or the build fails.

## Release

Pushing a `v*` tag builds every image on GitHub Actions and attaches these
assets to the GitHub Release:

- `<image>-amd64-rootfs.squashfs`
- `<image>-amd64.qcow2`
- `<image>-amd64-manifest.json`
- `<image>-amd64-SHA256SUMS`
- `<image>-amd64-qemu-img-info.txt`
- `<image>-amd64-rootfs-manifest.json`
- `<image>-amd64-rootfs-SHA256SUMS`

The release workflow is guarded so only the repository owner can run or re-run
the expensive release/build jobs. Other actors may create a skipped workflow
run, but no image build job starts. For local `act` checks, pass an actor that
matches the repository owner together with `ACT_LOCAL=true`.
