#!/usr/bin/env bash
set -euo pipefail

: "${HOST:?Set HOST, for example HOST=Z16}"
: "${DISK:?Set DISK, for example DISK=/dev/disk/by-id/...}"

REPO="${REPO:-github:kadencartwright/nix-install}"
REF="${REF:-main}"
WORKDIR="${WORKDIR:-/tmp/nix-install}"
ROOT="${ROOT:-/mnt}"

case "$DISK" in
    /dev/disk/by-id/*) ;;
    *)
        printf '[install-nixos] error: DISK must use /dev/disk/by-id/...\n' >&2
        exit 1
        ;;
esac

case "$REPO" in
    github:*)
        repo_path="${REPO#github:}"
        repo_url="https://github.com/${repo_path}.git"
        ;;
    https://github.com/*.git)
        repo_url="$REPO"
        ;;
    https://github.com/*)
        repo_url="${REPO}.git"
        ;;
    *)
        printf '[install-nixos] error: REPO must be github:owner/repo or a GitHub URL\n' >&2
        exit 1
        ;;
esac

FLAKE="${WORKDIR}#${HOST}"

git_cmd() {
    if command -v git >/dev/null 2>&1; then
        git "$@"
    else
        nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#git -c git "$@"
    fi
}

printf '[install-nixos] About to erase and install NixOS\n'
printf '[install-nixos] host: %s\n' "$HOST"
printf '[install-nixos] repo: %s\n' "$repo_url"
printf '[install-nixos] ref: %s\n' "$REF"
printf '[install-nixos] disk: %s\n' "$DISK"
printf '[install-nixos] Type ERASE to continue: ' >/dev/tty
read -r confirm </dev/tty

if [[ "$confirm" != "ERASE" ]]; then
    printf '[install-nixos] confirmation mismatch; refusing to continue\n' >&2
    exit 1
fi

rm -rf "$WORKDIR"
git_cmd clone "$repo_url" "$WORKDIR"
git_cmd -C "$WORKDIR" checkout "$REF"

sed -i "s#/dev/disk/by-id/replace-me#${DISK}#" "$WORKDIR/hosts/common/disko.nix"

printf '[install-nixos] formatting and mounting target disk\n'
nix --extra-experimental-features 'nix-command flakes' \
    run github:nix-community/disko/latest -- \
    --mode destroy,format,mount \
    --flake "$FLAKE" \
    --root-mountpoint "$ROOT" \
    --yes-wipe-all-disks \
    --no-deps

printf '[install-nixos] installing NixOS into %s\n' "$ROOT"
nixos-install \
    --root "$ROOT" \
    --flake "$FLAKE" \
    --no-root-passwd \
    --max-jobs 1 \
    --cores 2 \
    --option experimental-features 'nix-command flakes'
