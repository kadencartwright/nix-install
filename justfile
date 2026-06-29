set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

check:
    ./scripts/vm-test.sh --local-store check

dry-build HOST="Z16":
    ./scripts/vm-test.sh --local-store --host {{HOST}} dry-build

build-vm HOST="Z16":
    ./scripts/vm-test.sh --local-store --host {{HOST}} build-vm

run-vm HOST="Z16":
    ./scripts/vm-test.sh --local-store --host {{HOST}} run-vm

install-vm HOST="Z16":
    ./scripts/vm-test.sh --local-store --host {{HOST}} install-vm

switch HOST="Z16":
    sudo nixos-rebuild switch --flake .#{{HOST}}

boot HOST="Z16":
    sudo nixos-rebuild boot --flake .#{{HOST}}

mini:
    ./scripts/vm-test.sh --local-store --host MINI dry-build

z16:
    ./scripts/vm-test.sh --local-store --host Z16 dry-build

t16:
    ./scripts/vm-test.sh --local-store --host T16 dry-build

x1c:
    ./scripts/vm-test.sh --local-store --host X1C dry-build

pi5:
    ./scripts/vm-test.sh --local-store --host pi5 dry-build
