# NixOS Config

This repository defines NixOS systems named `Z16`, `T16`, `X1C`, `MINI`, and `pi5` using flakes, Home Manager, `disko`, and `sops-nix`.

## Build

```bash
nix flake check
nixos-rebuild build --flake .#Z16
nixos-rebuild build --flake .#T16
nixos-rebuild build --flake .#pi5
```

From the repository root, common checks are wrapped in `just`:

```bash
just check
just mini
just t16
just switch Z16
```

Installed systems also include `nh`; day-to-day rebuilds can use:

```bash
nh os switch
```

Nix garbage collection runs weekly and deletes generations older than 14 days.
Store optimization is enabled automatically.

Avahi/mDNS is enabled, so hosts should be discoverable on the LAN as names like
`Z16.local`, `T16.local`, `MINI.local`, and `pi5.local` when the local network supports it.

`pi5` is an `aarch64-linux` Raspberry Pi 5 configuration. Build it from an
aarch64 machine or a builder that can handle that target.
It currently targets a microSD boot with a plain FAT firmware partition and
plain ext4 root by label; it does not use the shared x86 LUKS/LVM `disko`
layout.

All hosts enable OpenSSH, Mosh, Tailscale, fail2ban, and Avahi/mDNS. SSH password
authentication is disabled, root SSH login is disabled, and user `k` is
authorized from `https://github.com/kadencartwright.keys`.

`MINI` is headless. It uses the headless Home Manager profile, so
GUI/window-manager dotfiles and desktop packages are not installed there.
After first boot, run `sudo tailscale up` once or provision an auth key later.

## VM Test

```bash
scripts/vm-test.sh check
scripts/vm-test.sh dry-build
scripts/vm-test.sh build-vm
scripts/vm-test.sh run-vm
```

For an install-flow test against a disposable VM:

```bash
scripts/vm-test.sh install-vm
```

The harness copies the repository to a temp directory by default so untracked local
files are visible to Nix during development. Use `--no-copy` after committing or
staging everything if you want to evaluate the repository path directly.

By default, temp files and VM disk images live under
`~/.cache/nix-install/vm-test`, which keeps them on `/home` instead of
root-backed `/tmp`. If `/nix` is also out of space, add `--local-store`:

```bash
scripts/vm-test.sh --local-store check
scripts/vm-test.sh --local-store build-vm
```

That uses a chroot Nix store under
`~/.cache/nix-install/vm-test/nix-root`.

## Install From The NixOS ISO

Find the target disk with:

```bash
ls -l /dev/disk/by-id/
```

Then run:

```bash
sudo nix --extra-experimental-features 'nix-command flakes' \
  run github:nix-community/disko/latest#disko-install -- \
  --flake github:kadencartwright/nix-install/main#Z16 \
  --write-efi-boot-entries \
  --disk main /dev/disk/by-id/<explicit-disk-id>
```

The optional wrapper is:

```bash
curl -fsSL https://raw.githubusercontent.com/kadencartwright/nix-install/<pinned-commit>/scripts/install-nixos.sh \
  | sudo HOST=Z16 DISK=/dev/disk/by-id/<explicit-disk-id> REF=<pinned-commit> bash
```

Pin both the raw script URL and `REF` to a commit when installing real hardware.
