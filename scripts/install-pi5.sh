#!/usr/bin/env bash
set -euo pipefail

cat >&2 <<'MESSAGE'
The pi5 profile is not installable through the x86 live-ISO/Disko workflow.

It requires a bootable Raspberry Pi 5 microSD image with a FAT firmware
partition and an ext4 root partition. The repository does not yet export that
image, so this script intentionally refuses to erase a disk instead of applying
the incompatible encrypted x86 layout.

No disks were changed.
MESSAGE

exit 1
