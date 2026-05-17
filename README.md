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

## Release

Pushing a `v*` tag builds every image on GitHub Actions and attaches these
assets to the GitHub Release:

- `<image>-amd64-rootfs.squashfs`
- `<image>-amd64-manifest.json`
- `<image>-amd64-SHA256SUMS`

The release workflow is guarded so only `sugaf1204` can run the expensive
release/build jobs in `sugaf1204/os-images`. Other actors may create a skipped
workflow run, but no image build job starts. For local `act` checks, pass
`--actor sugaf1204` together with `ACT_LOCAL=true`.
