#!/usr/bin/env bash
set -euo pipefail

: "${HOST:?Set HOST, for example HOST=Z16}"
: "${DISK:?Set DISK, for example DISK=/dev/disk/by-id/...}"

REPO="${REPO:-github:kadencartwright/nix-install}"
REF="${REF:-main}"

case "$DISK" in
    /dev/disk/by-id/*) ;;
    *)
        printf '[install-nixos] error: DISK must use /dev/disk/by-id/...\n' >&2
        exit 1
        ;;
esac

FLAKE="${REPO}/${REF}#${HOST}"

printf '[install-nixos] About to erase and install NixOS\n'
printf '[install-nixos] host: %s\n' "$HOST"
printf '[install-nixos] flake: %s\n' "$FLAKE"
printf '[install-nixos] disk: %s\n' "$DISK"
printf '[install-nixos] Type ERASE to continue: '
read -r confirm

if [[ "$confirm" != "ERASE" ]]; then
    printf '[install-nixos] confirmation mismatch; refusing to continue\n' >&2
    exit 1
fi

exec nix --extra-experimental-features 'nix-command flakes' \
    run github:nix-community/disko/latest#disko-install -- \
    --flake "$FLAKE" \
    --write-efi-boot-entries \
    --disk main "$DISK"
