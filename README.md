# os-images

Minimal Packer-based qcow2 whole-disk image catalog for GOMI bare-metal deploy.

## Build

```sh
scripts/build-all
```

Each image entry in `images/<image>/source.env` points at an upstream bootable
qcow2 disk image. Packer consumes that qcow2 with the QEMU builder and writes a
GOMI manifest under `dist/<image>/`:

- `root.qcow2`
- `manifest.json`
- `SHA256SUMS`

`ubuntu-24.04-desktop` is a derived Desktop artifact. It starts from the Ubuntu
24.04 server cloud image, expands the qcow2 to `DISK_SIZE`, and installs
`ubuntu-desktop-minimal` before cleaning the image for first boot. This build is
slower and larger than the server artifacts. When registering the artifact in
GOMI, use top-level OSImage `variant: desktop`; the release manifest also
records the variant and package recipe for provenance.

Images:

- `debian-12`
- `debian-13`
- `ubuntu-22.04`
- `ubuntu-24.04`
- `ubuntu-24.04-desktop`
- `ubuntu-26.04`
- `fedora-44`

## Requirements

- Linux x86_64 build host
- `packer`
- `jq`
- QEMU tools for the Packer QEMU builder
- `ssh-keygen`
- `xorriso` or another ISO creation tool supported by Packer `cd_content`
- `sha256sum` and GNU `stat` from `coreutils`

The images are expected to be completed target whole-disk qcow2 artifacts. This
repository does not build or publish separate VM images; VM deployment can use
external cloud images registered directly in GOMI. For artifacts from this
repository, GOMI should not ask curtin to install a replacement kernel, refresh
packages, install a bootloader, or write distro-specific network renderer files.

## Release

Pushing a `v*` tag builds every image on GitHub Actions and attaches these
assets to the GitHub Release:

- `<image>-amd64.qcow2`
- `<image>-amd64-manifest.json`
- `<image>-amd64-SHA256SUMS`

The release workflow is guarded so only the repository owner can run or re-run
the expensive release/build jobs. Other actors may create a skipped workflow
run, but no image build job starts. For local `act` checks, pass an actor that
matches the repository owner together with `ACT_LOCAL=true`.
