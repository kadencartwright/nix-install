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

Desktop hosts include Slack and Bluetui, run the ydotool daemon, and enable
Docker with BuildKit, Buildx, and Compose. Podman remains installed for
Distrobox, while headless hosts retain the lightweight Podman-backed `docker`
compatibility command.

Desktop configuration follows the pinned `kadencartwright/dotfiles` input.
Alacritty is the active terminal; Ghostty is not installed or managed. Wayle's
full config, schemas, styles, themes, and scripts are linked from that input.
Its Codex/ChatGPT usage module is backed by the packaged `codexbar` command and
the existing Codex CLI login; left-click shows the usage notification and
right-click opens the web usage page.

SSH authentication uses Home Manager's standard OpenSSH agent and regular key
files. Bitwarden remains installed as a password manager, but the dotfiles'
Bitwarden `SSH_AUTH_SOCK` override is removed from the generated Hyprland config.

Lemurs authenticates graphical logins through PAM and unlocks the GNOME login
keyring with the same password. The keyring remains the desktop Secret Service;
it does not replace the separate OpenSSH agent. If the login password changes,
run `passwd` as the logged-in user so PAM can update the `Login` keyring too.
Lemurs intentionally requires the account password instead of a fingerprint,
because fingerprint authentication cannot supply a keyring decryption password.
Use Seahorse to repair an already mismatched keyring. The `passwd` PAM control
override uses NixOS's experimental `security.pam.services.*.rules` interface;
recheck the generated PAM stack after major nixpkgs upgrades.

Atom One Dark is installed as the GTK 2/3 and icon theme, including the Murrine
engine it requires. Qt 5/6 uses its GTK integration so it follows the same
theme; GTK4/libadwaita stays in supported dark mode. The current dotfiles carry
the matching One Dark palettes for Wayle, Alacritty, Kitty, Neovim, and KDE,
and Hyprpaper uses the pinned One Dark NixOS wallpaper.

`hyprwhspr` is also installed on desktop hosts. After the first rebuild, run
`hyprwhspr setup` once: enable its Hyprland and systemd choices, but skip
Waybar (Wayle is the active panel) and the imperative permissions step (ydotool
is configured by NixOS). The existing `Alt+G` binding toggles dictation.

## VM Test

```bash
scripts/vm-test.sh check
scripts/vm-test.sh dry-build
scripts/vm-test.sh build-vm
scripts/vm-test.sh run-vm
```

`run-vm` uses QEMU's accelerated virtio GPU when `/dev/dri/renderD128` is
available, which current Hyprland requires for a reliable graphical session.
Set `QEMU_OPTS` to override those graphical defaults. The headless VNC and
screenshot/input workflow is documented in `docs/nixos-vm-test.md`.

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

Boot the [NixOS 26.05 graphical ISO](https://channels.nixos.org/nixos-26.05/latest-nixos-graphical-x86_64-linux.iso)
in UEFI mode and connect to the network (`nmtui` works for Wi-Fi). The installed
system and Home Manager inputs are pinned to their matching 26.05 release
branches. Each x86 host has a dedicated guided entry point suitable for a short
link. These commands run as the live user and request elevation themselves:

```bash
curl -fsSL https://raw.githubusercontent.com/kadencartwright/nix-install/main/scripts/install-z16.sh | bash
curl -fsSL https://raw.githubusercontent.com/kadencartwright/nix-install/main/scripts/install-t16.sh | bash
curl -fsSL https://raw.githubusercontent.com/kadencartwright/nix-install/main/scripts/install-x1c.sh | bash
curl -fsSL https://raw.githubusercontent.com/kadencartwright/nix-install/main/scripts/install-mini.sh | bash
```

Each script fixes its host profile, requests administrator access with `sudo`,
and then guides you through disk selection, LUKS setup, installation, and
reboot. The general installer still supports choosing a host interactively:

```bash
curl -fsSL https://raw.githubusercontent.com/kadencartwright/nix-install/main/scripts/install-nixos.sh \
  | bash
```

`pi5` remains deliberately separate. Its profile expects Raspberry Pi firmware
on a FAT microSD partition and does not import the encrypted x86 Disko layout.
`scripts/install-pi5.sh` therefore exits without touching a disk until this
flake exports and tests a bootable Pi 5 SD image.

It guides you through choosing the host and target disk, displays the complete
destructive install plan, and requires you to type a host-specific erase
confirmation. The target must have a stable `/dev/disk/by-id` name. Advanced or
repeatable installs can still preselect values:

```bash
curl -fsSL https://raw.githubusercontent.com/kadencartwright/nix-install/main/scripts/install-nixos.sh \
  | env HOST=T16 DISK=/dev/disk/by-id/<explicit-disk-id> REF=main bash
```

The installer then uses a staged flow that works from the ISO:

- clones this repo to a temporary `/tmp/nix-install.*` directory
- collects the LUKS passphrase without echoing it and writes it to a temporary
  mode-0600 file in `/run`; it is removed as soon as formatting finishes
- patches the temporary `disko` config to use `DISK` and that one-time key file
- runs `disko` to wipe, format, and mount the target disk at `/mnt`
- creates up to 8 GiB of temporary swap inside the encrypted target filesystem
  so package builds do not depend solely on the live ISO's RAM-backed overlay;
  the swap file is disabled and removed when installation finishes
- runs `nixos-install` so the full system builds into `/mnt/nix/store` on the
  target disk instead of the ISO's RAM-backed `/nix/store`

Pin both the raw script URL and `REF` to a commit when installing real hardware.

Manual fallback:

```bash
git clone https://github.com/kadencartwright/nix-install /tmp/nix-install
cd /tmp/nix-install
HOST=X1C
DISK=/dev/disk/by-id/<explicit-disk-id>
LUKS_KEY_FILE="$(sudo mktemp /run/nix-install-luks-key.XXXXXXXX)"
read -r -s -p 'New LUKS passphrase: ' LUKS_PASSPHRASE
printf '\n'
printf '%s' "$LUKS_PASSPHRASE" | sudo tee "$LUKS_KEY_FILE" >/dev/null
sudo chmod 600 "$LUKS_KEY_FILE"
unset LUKS_PASSPHRASE
sudo sed -i "s#/dev/disk/by-id/replace-me#${DISK}#" hosts/common/disko.nix
sudo sed -i "s#/tmp/secret.key#${LUKS_KEY_FILE}#" hosts/common/disko.nix

sudo nix --extra-experimental-features 'nix-command flakes' \
  run github:nix-community/disko/de5708739256238fb912c62f03988815db89ec9a -- \
  --mode destroy,format,mount \
  --flake /tmp/nix-install#${HOST} \
  --root-mountpoint /mnt \
  --yes-wipe-all-disks \
  --no-deps

sudo rm -f -- "$LUKS_KEY_FILE"
unset LUKS_KEY_FILE LUKS_PASSPHRASE

sudo nixos-install \
  --flake /tmp/nix-install#${HOST} \
  --no-root-passwd \
  --max-jobs 1 \
  --cores 2 \
  --option experimental-features 'nix-command flakes'
```

The LUKS password is supplied to `disko` through the temporary key file. User
`k` is provisioned by the flake config; after first boot, use your SSH key or
console login path for that host.
