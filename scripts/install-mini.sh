#!/usr/bin/env bash
set -euo pipefail

REF="${REF:-main}"
RAW_REPO="${RAW_REPO:-https://raw.githubusercontent.com/kadencartwright/nix-install}"
run_as_root=()

if ((EUID != 0)); then
    command -v sudo >/dev/null 2>&1 || {
        printf 'install-mini: sudo is required to install NixOS\n' >&2
        exit 1
    }
    printf 'install-mini: requesting administrator access...\n'
    sudo -v
    run_as_root=(sudo)
fi

curl -fsSL "${RAW_REPO}/${REF}/scripts/install-nixos.sh" \
    | "${run_as_root[@]}" env HOST=MINI REF="$REF" bash
