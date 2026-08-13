# NixOS VM Test Harness

The old VM harness in `scripts/vm-libvirt-create.sh` is for the Arch ISO installer. The NixOS config has a separate harness:

```bash
scripts/vm-test.sh
```

## Quick Checks

From the repository root:

```bash
scripts/vm-test.sh check
scripts/vm-test.sh dry-build
```

These verify that the flake evaluates and that the NixOS system can be built.

## Boot The NixOS VM

Build the VM runner:

```bash
scripts/vm-test.sh build-vm
```

Launch it:

```bash
scripts/vm-test.sh run-vm
```

This tests whether the NixOS configuration can boot as a QEMU VM. When
`/dev/dri/renderD128` is available, the harness enables QEMU's accelerated
virtio GPU so Hyprland can render normally. Set `QEMU_OPTS` yourself to override
the graphical defaults. This mode does not test the destructive `disko` install
path.

For a headless QEMU run that exposes VNC on port 5901, the dependency-free
helper can capture the display or send pointer and keyboard input:

```bash
QEMU_OPTS='-device virtio-vga-gl,xres=1440,yres=900 -display egl-headless,rendernode=/dev/dri/renderD128 -vnc 127.0.0.1:1' \
  scripts/vm-test.sh run-vm

scripts/vm-vnc.py screenshot /tmp/vm.png
scripts/vm-vnc.py click 960 22
scripts/vm-vnc.py type 'hello'
scripts/vm-vnc.py key return
scripts/vm-vnc.py chord ctrl+shift+e
```

The graphical VM is also suitable for testing the complete Lemurs-to-GNOME
Keyring path. Log in through Lemurs, then use `secret-tool` in Alacritty to
store and retrieve a disposable value. Log out and back in through Lemurs and
retrieve it again; a successful lookup without an unlock prompt proves that PAM
re-unlocked the persisted login keyring. Seahorse is installed for inspecting
or repairing a login keyring whose password no longer matches the account.

Lemurs password authentication is intentional: fingerprint-only login cannot
unlock an encrypted keyring because PAM never receives its decryption password.
Fingerprint support remains available to other configured PAM services.

## Test The Install Flow

Run the `nixos-anywhere` VM test:

```bash
scripts/vm-test.sh install-vm
```

This is the closer pre-metal test because it evaluates the flake as an installer target and exercises the `disko`-backed install flow against a disposable VM.

## Useful Options

```bash
scripts/vm-test.sh --host Z16 check
scripts/vm-test.sh --keep-tmp check
scripts/vm-test.sh --no-copy check
```

By default, the harness copies `nixos/` to a temporary directory before evaluation. That avoids Nix's Git flake behavior where untracked files are invisible. Once the config is committed, `--no-copy` is fine.

## Keeping VM Work Off `/`

The harness defaults to:

```text
~/.cache/nix-install/vm-test
```

It places temp flake copies, temporary build spillover, and the default QEMU disk image there:

```text
~/.cache/nix-install/vm-test/tmp
~/.cache/nix-install/vm-test/vm/Z16.qcow2
```

Use a different location with:

```bash
scripts/vm-test.sh --work-dir /home/k/vm-work build-vm
```

If `/nix` itself is the full filesystem, use a chroot Nix store under `/home`:

```bash
scripts/vm-test.sh --local-store check
scripts/vm-test.sh --local-store dry-build
scripts/vm-test.sh --local-store build-vm
```

The default local store root is:

```text
~/.cache/nix-install/vm-test/nix-root
```

You can override it:

```bash
scripts/vm-test.sh --local-store --store-root /home/k/nix-vm-store build-vm
```

This local-store mode avoids writing build outputs to `/nix/store`. It may need user namespaces enabled because Nix implements it as a chroot store.

## Host Requirements

The quick checks require:

- `nix`
- network access to fetch flake inputs when the lock file is not already cached

The VM modes may require:

- QEMU/KVM support
- an accessible `/dev/dri/renderD128` render node for the interactive Hyprland VM
- enough RAM and disk space for a NixOS VM build
- Nix sandbox permissions compatible with VM builds

The `install-vm` mode may require whatever `nixos-anywhere --vm-test` needs on the host, including QEMU support.
