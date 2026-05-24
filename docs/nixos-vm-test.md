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

This tests whether the NixOS configuration can boot as a QEMU VM. It does not test the destructive `disko` install path.

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
- enough RAM and disk space for a NixOS VM build
- Nix sandbox permissions compatible with VM builds

The `install-vm` mode may require whatever `nixos-anywhere --vm-test` needs on the host, including QEMU support.
