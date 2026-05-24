# VM Manual Verification (libvirt + virt-manager)

This workflow creates a libvirt VM for Arch ISO testing with:

- UEFI boot (OVMF)
- TPM 2.0 emulation (swtpm)
- SPICE graphics for use in virt-manager
- virtiofs repo sharing so the repo can be cloned to `/root/nix-install`

Manual takeover occurs once the repo clone to `/root/nix-install` is complete.

## Host prerequisites

Required host tools/services:

- `libvirtd` running
- `virt-install`
- `virt-manager`
- `swtpm`
- OVMF firmware

Networking note:

- The default script connection is `qemu:///system`, which expects a libvirt network named `default`.
- If you use `qemu:///session`, the script auto-uses user-mode networking and does not require libvirt `default`.

On Arch Linux, install and start prerequisites:

```bash
sudo pacman -S --needed qemu-full libvirt virt-install virt-manager swtpm edk2-ovmf
sudo systemctl enable --now libvirtd
```

## 1) Create and start the VM

From repo root:

```bash
scripts/vm-libvirt-create.sh
```

Useful options:

```bash
scripts/vm-libvirt-create.sh \
  --name nix-install-test \
  --iso "$HOME/Downloads/archlinux-2026.02.01-x86_64.iso" \
  --disk ./.vm/nix-install-test.qcow2 \
  --disk-size 120 \
  --memory 8192 \
  --cpus 4 \
  --repo "$(pwd)"
```

## 2) Open in virt-manager

Open `virt-manager`, select `nix-install-test`, and connect to the SPICE console.
Boot into the Arch live environment.

## 3) Mount shared repo and clone to `/root/nix-install`

In the Arch ISO shell:

```bash
mkdir -p /root/host-repo
mount -t virtiofs hostrepo /root/host-repo
git clone /root/host-repo /root/nix-install
cd /root/nix-install
```

Manual takeover starts here.

## 4) Run installer via user-driven path

Run interactively so real prompts are exercised:

```bash
./install.sh
```

Then manually:

- choose the target disk from the prompt
- type destructive confirmation text
- enter LUKS/root/user credentials in prompts

This matches your normal operator path.

## 5) TPM/LUKS verification focus

After install completes:

1. Reboot VM.
2. Confirm expected TPM-backed LUKS unlock behavior (no unexpected manual unlock prompt).
3. Validate in the installed system as needed (for example with `journalctl` and `systemd-cryptenroll` tooling).

## Reset for a fresh test

To remove VM definition and disk:

```bash
scripts/vm-libvirt-clean.sh --purge-nvram
```

If you want to keep NVRAM state, omit `--purge-nvram`.
