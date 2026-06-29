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

Boot the NixOS ISO, connect to the network, then find the target disk:

```bash
ls -l /dev/disk/by-id/
```

Then run the installer wrapper:

```bash
curl -fsSL https://raw.githubusercontent.com/kadencartwright/nix-install/main/scripts/install-nixos.sh \
  | sudo env HOST=T16 DISK=/dev/disk/by-id/<explicit-disk-id> REF=main bash
```

The installer asks you to type `ERASE`, then uses a staged flow that works from
the ISO:

- clones this repo to `/tmp/nix-install`
- patches the temporary `disko` config to use `DISK`
- runs `disko` to wipe, format, and mount the target disk at `/mnt`
- runs `nixos-install` so the full system builds into `/mnt/nix/store` on the
  target disk instead of the ISO's RAM-backed `/nix/store`

Pin both the raw script URL and `REF` to a commit when installing real hardware.

Manual fallback:

```bash
git clone https://github.com/kadencartwright/nix-install /tmp/nix-install
cd /tmp/nix-install
HOST=T16
DISK=/dev/disk/by-id/<explicit-disk-id>
sudo sed -i "s#/dev/disk/by-id/replace-me#${DISK}#" hosts/common/disko.nix

sudo nix --extra-experimental-features 'nix-command flakes' \
  run github:nix-community/disko/latest -- \
  --mode destroy,format,mount \
  --flake /tmp/nix-install#${HOST} \
  --root-mountpoint /mnt \
  --yes-wipe-all-disks \
  --no-deps

sudo nixos-install \
  --flake /tmp/nix-install#${HOST} \
  --no-root-passwd \
  --max-jobs 1 \
  --cores 2 \
  --option experimental-features 'nix-command flakes'
```

The LUKS password is set during the `disko` step. User `k` is provisioned by the
flake config; after first boot, use your SSH key or console login path for that
host.
