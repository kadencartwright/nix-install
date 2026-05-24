# NixOS Migration Implementation Plan

This plan replaces the current Arch installer with a one-phase NixOS migration. The goal is not to put Nix on top of Arch first; the goal is to turn this repository into a Git-driven NixOS installer/configuration using flakes, Home Manager, `disko`, and either `disko-install` or `nixos-anywhere`.

The current repository is an Arch installer with Bash scripts for LUKS on LVM, ext4 root, systemd-boot, dracut, TPM2 enrollment, package installation, AUR setup, and dotfile installation. The new implementation should translate those responsibilities into NixOS modules instead of preserving them as long-term installation scripts.

## Goals

- Replace Arch with NixOS from a pinned Git flake.
- Manage the OS, users, services, bootloader, packages, and user environment declaratively.
- Reuse the current installer's proven choices where they still make sense: LUKS, LVM, ext4 root, systemd-boot, Chicago timezone, user `k`, Hyprland-oriented desktop packages, and explicit disk confirmation.
- Use Home Manager as a NixOS module for shell, editor, Git, terminal, and dotfile configuration.
- Use `disko` for declarative disk partitioning and formatting.
- Support both local ISO installs with `disko-install` and remote/semi-remote installs with `nixos-anywhere`.
- Keep destructive disk operations explicit, pinned, and hard to trigger accidentally.

## Non-Goals

- Do not build an intermediate Arch + Nix/Home Manager setup.
- Do not translate the old Bash scripts line-for-line.
- Do not use `nix-env` or imperative package installation.
- Do not auto-detect and wipe disks.
- Do not put plaintext secrets into Nix files or the Nix store.
- Do not add Secure Boot, impermanence, remote builders, custom binary caches, or complex overlays until the basic NixOS install works.

## Target Architecture

```text
nixos-config/
  flake.nix
  flake.lock

  hosts/
    common/
      default.nix
      disko.nix
      home.nix
    Z16/
      default.nix
      hardware-configuration.nix
    X1C/
      default.nix
      hardware-configuration.nix
    MINI/
      default.nix
      hardware-configuration.nix
    pi5/
      default.nix
      hardware-configuration.nix

  modules/
    common/
      base.nix
      boot.nix
      users.nix
      nix.nix
      networking.nix
      security.nix
    desktop/
      hyprland.nix
      audio.nix
      fonts.nix
      portals.nix
    hardware/
      bluetooth.nix
      fingerprint.nix
      power.nix
      tpm.nix

  home/
    cli.nix
    git.nix
    shell.nix
    editors.nix
    terminals.nix
    desktop.nix

  secrets/
    secrets.yaml
    secrets.nix

  scripts/
    install-nixos.sh
```

This can either become the root of this repository or live under a new top-level `nixos/` directory while the old Arch scripts remain temporarily for reference. Once the NixOS path is proven, archive or remove the Arch installer scripts.

## Implementation Steps

### 1. Audit And Translate Existing Arch Behavior

Capture what the current scripts do and assign each item to a NixOS destination.

| Existing Arch responsibility | Current source | NixOS destination |
| --- | --- | --- |
| Disk wipe, EFI, LUKS, LVM, ext4 | `install.sh` | `hosts/common/disko.nix` |
| Mount/install handoff | `install.sh` | `disko-install` or `nixos-anywhere` |
| Timezone and locale | `chrooted.sh` | `time.timeZone`, `i18n.defaultLocale`, `i18n.supportedLocales` |
| User `k`, wheel access, shell | `chrooted.sh` | `users.users.k`, `programs.zsh.enable` |
| Password setup | `chrooted.sh` | Manual first boot password, hashed password, or encrypted secret |
| systemd-boot | `chrooted.sh` | `boot.loader.systemd-boot.*`, `boot.loader.efi.*` |
| dracut/systemd UKI logic | `chrooted.sh`, hooks | NixOS boot/initrd options; postpone UKI customization until base boot works |
| TPM2 LUKS enrollment | `chrooted.sh` | Later hardware/security module after basic LUKS boot works |
| `packages/wm.txt` | package list | `environment.systemPackages`, service options, Home Manager packages |
| `packages/aur.txt` | package list | Nixpkgs equivalents, overlays, or manual exclusions |
| Dotfile install | `install-dotfiles.sh` | Home Manager `programs.*`, `home.file`, `xdg.configFile` |
| AUR helper | `install-yay.sh` | Usually removed; use Nixpkgs/overlays instead |

Deliverable:

- Add `docs/nixos-package-mapping.md` with Arch/AUR package names, Nixpkgs replacements, and ownership: system, Home Manager, exclude, or later.

### 2. Create The NixOS Flake

Add `flake.nix` and commit `flake.lock`.

Use these inputs:

- `nixpkgs`
- `home-manager`
- `disko`
- `sops-nix` or `agenix`
- optionally `nixos-hardware`

Minimal flake shape:

```nix
{
  description = "NixOS systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

    disko.url = "github:nix-community/disko/latest";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager/release-25.11";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };

  outputs = inputs@{ nixpkgs, disko, home-manager, sops-nix, nixos-hardware, ... }: {
    nixosConfigurations.Z16 = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        sops-nix.nixosModules.sops

        ./hosts/Z16/default.nix
        ./hosts/common/disko.nix
        ./hosts/Z16/hardware-configuration.nix
      ];
    };
  };
}
```

Acceptance criteria:

- `nix flake check` evaluates.
- `nixosConfigurations.Z16` exists.
- `flake.lock` is committed.

### 3. Build The Minimal Host

Create `hosts/Z16/default.nix` with only the settings required to boot and log in.

Initial scope:

- Hostname.
- Timezone `America/Chicago`.
- Locale `en_US.UTF-8`.
- User `k` with wheel access.
- Zsh as the default shell.
- NetworkManager.
- systemd-boot.
- Flakes enabled.
- Basic packages: `git`, `curl`, `vim` or `neovim`, `ripgrep`, `btop`.
- Home Manager enabled, but initially small.

Postpone:

- TPM2 auto-unlock.
- UKI/dracut parity.
- NVIDIA or special GPU tuning unless required.
- Fingerprint unlock.
- Printing.
- Gaming/proprietary apps.
- Secrets beyond the scaffolding.

Acceptance criteria:

- `nixos-rebuild build --flake .#Z16` succeeds.
- The config is understandable and boring enough to debug.

### 4. Add Home Manager As A NixOS Module

Move user-level config into `home/` modules.

Start with:

- Shell: zsh, completions, autosuggestions, syntax highlighting.
- Git: user name, email, aliases, signing preferences if applicable.
- Editor: Neovim config and dependencies.
- Terminal: Alacritty config.
- CLI tools: `bat`, `btop`, `eza`, `fd`, `fzf`, `gh`, `git`, `jq`, `lazygit`, `neovim`, `ripgrep`, `tmux`, `zoxide`.
- XDG configs that are stable and not frequently rewritten by apps.

Example host wiring:

```nix
{
  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.k = import ./home.nix;
}
```

Acceptance criteria:

- User-level config builds as part of `nixos-rebuild`.
- Existing dotfiles are represented by Home Manager modules or `xdg.configFile`.
- Mutable app state is not force-linked unless it has been tested.

### 5. Translate Packages And Services

Convert `packages/wm.txt` and `packages/aur.txt`.

System/service candidates:

- Hyprland and portals.
- PipeWire stack.
- NetworkManager applet.
- Power profiles daemon.
- Fingerprint support.
- Thunar and desktop integration.
- Fonts.

Home Manager candidates:

- Shell tools.
- Terminal/editor configs.
- Waybar config.
- Fuzzel config.
- Hyprland user config, if preferred at user level.

Likely exclusions or later decisions:

- AUR-only fonts.
- Spotify/Vivaldi if Nixpkgs licensing or binary availability is awkward.
- TPM/UKI tooling until boot is stable.
- Anything that depends on a mutable external login/session state.

Acceptance criteria:

- Every package in `packages/wm.txt` and `packages/aur.txt` has a NixOS decision.
- The NixOS config contains the first useful desktop package set.
- Exclusions are documented with rationale.

### 6. Add Declarative Disk Layout With `disko`

Create `hosts/common/disko.nix` matching the current installer:

- GPT.
- EFI system partition.
- LUKS container.
- LVM volume group.
- ext4 root filesystem containing `/home`.

Use an abstract disk name such as `main`. The concrete disk must be supplied at install time:

```bash
--disk main /dev/disk/by-id/<explicit-disk-id>
```

Safety rules:

- Never guess the disk.
- Prefer `/dev/disk/by-id/...` over `/dev/sdX` or `/dev/nvmeXnY`.
- Require a typed destructive confirmation in any wrapper script.

Acceptance criteria:

- `disko.nix` evaluates.
- The layout matches the current installer's intent.
- The install command requires an explicit disk path.

### 7. Add Secrets Strategy

Choose one:

- `sops-nix`: more flexible, good for YAML and multiple secret backends.
- `agenix`: simpler age-based secrets.

Initial secrets scope:

- Do not automate secrets on the first boot unless needed.
- Add the module and folder structure.
- Document how passwords, Wi-Fi secrets, tokens, SSH keys, and API credentials will be handled.

Acceptance criteria:

- No cleartext secrets are committed.
- The repo has a documented secret workflow.
- Any secret used during activation is decrypted outside plaintext Nix expressions.

### 8. Test In A VM

Before real hardware, test both evaluation and boot behavior.

Commands:

```bash
nix flake check
nixos-rebuild build --flake .#Z16
nixos-rebuild build-vm --flake .#Z16
```

Test the install flow in a disposable VM:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake .#Z16 \
  --vm-test
```

Acceptance criteria:

- The flake checks.
- The system builds.
- The VM boots.
- The test install path completes against a disposable target.
- Login works for user `k`.

### 9. Add The One-Command Installer Wrapper

Prefer direct `nix run` commands for real installs, but a tiny wrapper is acceptable if it only dispatches to Nix.

Local ISO install:

```bash
sudo nix --extra-experimental-features 'nix-command flakes' \
  run github:nix-community/disko/latest#disko-install -- \
  --flake github:<owner>/<repo>#Z16 \
  --write-efi-boot-entries \
  --disk main /dev/disk/by-id/<explicit-disk-id>
```

Remote or semi-remote install:

```bash
nix run github:nix-community/nixos-anywhere -- \
  --flake github:<owner>/<repo>#Z16 \
  --target-host root@<target-ip>
```

Optional wrapper:

```bash
curl -fsSL https://raw.githubusercontent.com/<owner>/<repo>/<pinned-commit>/scripts/install-nixos.sh \
  | sudo HOST=Z16 DISK=/dev/disk/by-id/<explicit-disk-id> bash
```

Wrapper requirements:

- Require `HOST`.
- Require `DISK`.
- Print the exact host, repo, flake ref, and disk.
- Require typing `ERASE`.
- Call `nix run ... disko-install`.
- Stay small enough to audit in one screen.
- Pin the raw script to a commit hash in documentation.

Acceptance criteria:

- The install command is documented.
- The wrapper refuses to run without explicit `HOST` and `DISK`.
- The wrapper does not contain custom partitioning logic.

### 10. Real Hardware Install

Checklist:

- Back up the Arch machine.
- Export anything not yet represented in the NixOS repo.
- Record the target disk as `/dev/disk/by-id/...`.
- Boot the NixOS minimal ISO.
- Connect network.
- Verify the flake ref and disk path.
- Run the local `disko-install` command.
- Reboot.
- Confirm login, network, shell, editor, desktop/session, audio, and rebuild.

Post-install rebuild:

```bash
cd ~/src/nixos-config
sudo nixos-rebuild switch --flake .#Z16
```

Optional UX wrapper:

```bash
nh os switch ~/src/nixos-config
```

Acceptance criteria:

- Machine boots into NixOS.
- User `k` can log in.
- Network works.
- `sudo nixos-rebuild switch --flake .#Z16` works.
- Home Manager config is active.
- Boot rollback generations are available.

## Suggested Work Order

1. Add the NixOS flake skeleton.
2. Add `hosts/Z16/default.nix`.
3. Add minimal Home Manager wiring.
4. Create the package mapping document from `packages/wm.txt` and `packages/aur.txt`.
5. Move shell, Git, editor, terminal, and CLI config into Home Manager.
6. Add desktop/audio/font/service modules.
7. Add `hosts/common/disko.nix`.
8. Add placeholder secrets structure and document the chosen tool.
9. Run `nix flake check`.
10. Run `nixos-rebuild build --flake .#Z16`.
11. Run VM boot and VM install tests.
12. Add the tiny install wrapper.
13. Back up the real machine.
14. Install NixOS from the pinned flake.
15. Verify first boot and rebuild.
16. Archive or remove the old Arch installer scripts.

## Risks And Mitigations

| Risk | Mitigation |
| --- | --- |
| Disk wipe targets the wrong device | Require explicit `/dev/disk/by-id/...` and typed `ERASE` confirmation |
| First NixOS config tries to do too much | Boot a minimal system first, then layer desktop/hardware features |
| Package names do not map cleanly from Arch/AUR to Nixpkgs | Document each mapping and postpone awkward packages |
| Desktop session fails on first boot | Keep a TTY-login path and basic tools available |
| GPU/OpenGL/Vulkan issues | Add hardware-specific modules only after base boot works |
| Secrets leak into the Nix store | Use `sops-nix` or `agenix`; never commit cleartext secrets |
| TPM2 or UKI parity delays migration | Treat TPM/UKI as follow-up hardening, not a first-boot blocker |
| Flake inputs drift unexpectedly | Commit `flake.lock` and review lock updates |

## Definition Of Done

The one-phase migration is complete when:

- This repository contains a buildable NixOS flake.
- The package and service mapping from the old Arch installer is documented.
- The NixOS config builds and boots in a VM.
- The `disko` install path works against a disposable VM.
- A real machine can be installed from a pinned flake command using an explicit disk path.
- The installed machine can rebuild itself with `nixos-rebuild switch --flake`.
- Home Manager manages the user's shell, editor, Git, terminal, CLI tools, and stable dotfiles.
- The old Arch installer scripts are removed, archived, or clearly marked as legacy.
