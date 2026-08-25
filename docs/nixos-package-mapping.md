# NixOS Package Mapping

This maps the Arch package lists at `kadencartwright/arch-install@f01b7ad` to
the current NixOS config. Package names should be validated with `nix search`
before the real hardware install.

## Host Split Notes

- `Z16`, `T16`, and `X1C` are desktop-oriented and import the Hyprland/audio/font/bluetooth/fingerprint stack.
- `MINI` is headless and imports only the base/headless stack, AMD CPU hardware, Tailscale, OpenSSH, and CLI/Home Manager config. It intentionally omits the desktop AMD GPU graphics stack.
- `pi5` is a Raspberry Pi 5 microSD target and does not import the shared x86 encrypted `disko` layout.
- Desktop dotfiles are intentionally excluded from `MINI`; it only links shell/editor/CLI dotfiles.

## `packages/wm.txt`

| Arch package | NixOS destination | Nixpkgs/module candidate | Status |
| --- | --- | --- | --- |
| `adw-gtk-theme` | Runtime desktop theme | Home Manager's Omarchy adapter plus Adwaita/Yaru | Omarchy palettes switch supported app colors, GTK light/dark mode, and icon variants; the custom Current System theme restores Atom One Dark for GTK 2/3 while GTK4/libadwaita stays on its supported color-scheme API |
| `alacritty` | Home Manager + system package | `programs.alacritty`, `pkgs.alacritty` | Added |
| `atuin` | Home Manager package | `pkgs.atuin` | Added |
| `bat` | Home Manager package | `pkgs.bat` | Added |
| `bitwarden` | Desktop password manager | `pkgs.bitwarden-desktop` | Added for desktop hosts; its SSH agent socket is intentionally not used |
| `blueman` | Bluetooth service and applet | `services.blueman.enable` | Added for desktop hosts |
| `bluetui` | Desktop user tool | `pkgs.bluetui` | Added for desktop hosts |
| `brightnessctl` | System package | `pkgs.brightnessctl` | Added |
| `btop` | Home Manager/system package | `pkgs.btop` | Added |
| `buildkit` | Container build tool | `pkgs.buildkit` | Added for desktop hosts |
| `chromium` | Desktop user app | `pkgs.chromium` | Added for desktop hosts, excluded from `MINI` |
| `docker` | Container daemon and CLI | `virtualisation.docker.enable` | Added for desktop hosts; Podman remains for Distrobox |
| `docker-buildx` | Docker CLI plugin | bundled by `virtualisation.docker.package` | Added with Docker on desktop hosts |
| `docker-compose` | Docker CLI plugin | bundled by `virtualisation.docker.package` | Added with Docker on desktop hosts |
| `eza` | Home Manager package | `pkgs.eza` | Added |
| `fd` | Home Manager package | `pkgs.fd` | Added |
| `vivaldi` | Desktop user app, unfree | `pkgs.vivaldi` | Still omitted; decide per-host later |
| `fprintd` | Service | `services.fprintd.enable` | Added |
| `fnm` | Home Manager package | `pkgs.fnm` | Added |
| `fzf` | Home Manager package | `pkgs.fzf` | Added |
| `fuzzel` | System/Home Manager package | `pkgs.fuzzel` | Added |
| `gnome-keyring` | Secret Service and PAM-unlocked login keyring | `services.gnome.gnome-keyring.enable` plus Lemurs PAM | Added and login-tested |
| `ghostty` | Removed terminal | — | Removed; current dotfiles select Alacritty |
| `gvfs` | Desktop service integration | `services.gvfs.enable` | Added for desktop hosts |
| `hypridle` | System package | `pkgs.hypridle` | Added |
| `hyprland` | Program module | `programs.hyprland.enable` | Added |
| `hyprlock` | System package | `pkgs.hyprlock` | Added |
| `hyprpaper` | System package | `pkgs.hyprpaper` | Added |
| `hyprpolkitagent` | Desktop session package | `pkgs.hyprpolkitagent` | Added for desktop hosts |
| `hyprpicker` | Desktop system package | `pkgs.hyprpicker` | Added for desktop hosts |
| `hyprshot` | Desktop screenshot tooling | `pkgs.hyprshot`, `grim`, `slurp` | Added for desktop hosts |
| `lemurs` | Login manager | `services.displayManager.lemurs` | Added with GNOME Keyring PAM unlock |
| `libfprint` | Service dependency | via `services.fprintd` | Added |
| `luarocks` | Dev/editor package | `pkgs.luarocks` | Later |
| `network-manager-applet` | System package | `pkgs.networkmanagerapplet` | Added |
| `nwg-displays` | System package | `pkgs.nwg-displays` | Added |
| `nwg-look` | System package | `pkgs.nwg-look` | Added |
| `pavucontrol` | System package | `pkgs.pavucontrol` | Added |
| `pipewire` | Service | `services.pipewire.enable` | Added |
| `pipewire-alsa` | Service | `services.pipewire.alsa.enable` | Added |
| `pipewire-audio` | Service | `services.pipewire` | Added |
| `pipewire-jack` | Service | `services.pipewire.jack.enable` | Added |
| `pipewire-pulse` | Service | `services.pipewire.pulse.enable` | Added |
| `power-profiles-daemon` | Service | `services.power-profiles-daemon.enable` | Added |
| `qpwgraph` | System package | `pkgs.qpwgraph` | Added |
| `qt5-wayland` | Qt Wayland support | Nixpkgs Qt wrappers | Provided per application; no global package needed |
| `qt6-wayland` | Qt Wayland support | Nixpkgs Qt wrappers | Provided per application; no global package needed |
| `rustup` | Dev tool | `pkgs.rustup` or dev shells | Still omitted; prefer project dev shells unless needed globally |
| `swaync` | System package | `pkgs.swaynotificationcenter` | Added |
| `tailscale` | Network service | `services.tailscale.enable` | Added on all hosts |
| `thunar` | System package/service integration | `pkgs.thunar`, `services.gvfs`, `services.tumbler` | Added |
| `thunar-archive-plugin` | Desktop package | `pkgs.xfce.thunar-archive-plugin` | Later |
| `thunar-volman` | Desktop package | `pkgs.xfce.thunar-volman` | Later |
| `tpm2-tools` | Hardware package | `pkgs.tpm2-tools` | Added |
| `tpm2-tss` | Hardware package | `pkgs.tpm2-tss` | Added |
| `ttf-dejavu-nerd` | Font | `pkgs.dejavu_fonts`, Nerd Font variant if needed | Partial |
| `ttf-meslo-nerd` | Font | `pkgs.nerd-fonts.meslo-lg` | Added |
| `tumbler` | Service | `services.tumbler.enable` | Added |
| `waybar` | System/Home Manager package | `pkgs.waybar` | Added |
| `wireplumber` | PipeWire policy manager | `services.pipewire.wireplumber` | Enabled automatically with PipeWire |
| `xdg-desktop-portal-hyprland` | Program module | via `programs.hyprland` | Added |
| `ydotool` | Input automation service and CLI | `programs.ydotool.enable` | Added for desktop hosts |
| `zsh` | Program/user shell | `programs.zsh.enable`, `users.users.k.shell` | Added |
| `zsh-autosuggestions` | Home Manager | `programs.zsh.autosuggestion.enable` | Added |
| `zsh-completions` | Home Manager | `programs.zsh.enableCompletion` | Added |
| `zoxide` | Home Manager package | `pkgs.zoxide` | Added |
| `ripgrep` | Home Manager/system package | `pkgs.ripgrep` | Added |
| `systemd-ukify` | Boot hardening | NixOS UKI/systemd tooling | Later |
| `otf-font-awesome` | Font | `pkgs.font-awesome` | Added |
| `openai-codex` | Home Manager package | `pkgsUnstable.codex` | Added |
| `profile-sync-daemon` | User service | package/module if still wanted | Later |
| `thunderbird` | Desktop user app | `pkgs.thunderbird` | Still omitted; decide per-host later |
| `lazygit` | Home Manager package | `pkgs.lazygit` | Added |

## `packages/aur.txt`

| AUR package | NixOS destination | Nixpkgs/module candidate | Status |
| --- | --- | --- | --- |
| `dracut-ukify` | Boot hardening | NixOS UKI/initrd options | Later |
| `appimagelauncher` | AppImage compatibility | `programs.appimage` | Added with binfmt support |
| `bemoji` | Desktop user package | `pkgs.bemoji` | Added for desktop hosts |
| `bluetuith-bin` | User package | no direct Nixpkgs package | Omitted; `pkgs.bluetui` provides the Bluetooth TUI used on desktop hosts |
| `codexbar` | Quickshell Codex/ChatGPT usage module | Custom package pinned to upstream `v0.6.1` | Added for desktop hosts with wrapped runtime dependencies |
| `hyprwhspr` | System-wide speech-to-text | Custom package pinned to upstream `v1.41.0` | Added for desktop hosts; the Hyprland hotkey and fallback Waybar integration use Nix store paths |
| `openai-chatgpt-desktop` | Desktop user app | `openai-chatgpt-desktop-nix` flake input | Added on supported x86_64 hosts |
| `reflector-simple` | Removed | NixOS uses pinned flake inputs, not mirror ranking for system config | Excluded |
| `slack-desktop` | Desktop user app, unfree | `pkgs.slack` | Added for desktop hosts |
| `t3code` / `t3` | Home Manager packages | In-repo packages pinned to upstream `v0.0.33` | Both added on supported x86_64 Linux hosts |
| `wayle` | Replaced desktop shell and panel | `pkgs.quickshell` | Replaced by the in-repo Quickshell configuration |
| `tmux-sessionizer-bin` | User script/package | custom Home Manager script | Later |
| `ttf-apple-emoji` | Font | possible unfree/custom font package | Later |
| `ttf-segoe-ui-variable` | Font | possible unfree/custom font package | Later |
| `spotify` | Desktop user app, unfree | `pkgs.spotify` | Added for desktop hosts |
