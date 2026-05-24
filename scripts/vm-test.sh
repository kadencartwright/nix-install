#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXOS_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

HOST="Z16"
MODE="check"
COPY_WORKTREE=1
KEEP_TMP=0
TMP_DIR=""
WORK_DIR="${VM_TEST_WORK_DIR:-${HOME}/.cache/nix-install/vm-test}"
LOCAL_STORE=0
STORE_ROOT=""

usage() {
    cat <<'USAGE'
Usage: scripts/vm-test.sh [options] [mode]

Modes:
  check         Run nix flake check (default)
  dry-build     Dry-run the NixOS system build
  build-vm      Build the NixOS QEMU VM script
  run-vm        Build and launch the NixOS QEMU VM
  install-vm    Run nixos-anywhere --vm-test against this flake

Options:
  --host <name>       NixOS configuration name (default: Z16)
  --work-dir <path>   Work directory for temp files and VM disks
                      (default: ~/.cache/nix-install/vm-test)
  --local-store       Use a chroot Nix store under the work directory instead
                      of the host /nix store
  --store-root <path> Chroot Nix store root for --local-store
                      (default: <work-dir>/nix-root)
  --no-copy           Evaluate the repository directory directly instead of a temp copy
  --keep-tmp          Keep the temp copy and print its path
  --help              Show this help text

The default temp-copy behavior makes untracked local files visible to Nix
without requiring you to git add them first.
USAGE
}

log() {
    printf '[vm-test] %s\n' "$*"
}

fatal() {
    printf '[vm-test] error: %s\n' "$*" >&2
    exit 1
}

require_cmd() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1 || fatal "Required command not found: $cmd"
}

physical_store_path() {
    local path="$1"
    if (( LOCAL_STORE )) && [[ "$path" == /nix/store/* ]]; then
        printf '%s%s' "$STORE_ROOT" "$path"
    else
        printf '%s' "$path"
    fi
}

cleanup() {
    if [[ -n "$TMP_DIR" && -d "$TMP_DIR" && "$KEEP_TMP" -eq 0 ]]; then
        rm -rf "$TMP_DIR"
    fi
}

trap cleanup EXIT

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)
            HOST="${2:-}"
            shift 2
            ;;
        --work-dir)
            WORK_DIR="${2:-}"
            shift 2
            ;;
        --local-store)
            LOCAL_STORE=1
            shift
            ;;
        --store-root)
            STORE_ROOT="${2:-}"
            LOCAL_STORE=1
            shift 2
            ;;
        --no-copy)
            COPY_WORKTREE=0
            shift
            ;;
        --keep-tmp)
            KEEP_TMP=1
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        check | dry-build | build-vm | run-vm | install-vm)
            MODE="$1"
            shift
            ;;
        *)
            fatal "Unknown option or mode: $1"
            ;;
    esac
done

[[ -n "$HOST" ]] || fatal "Host cannot be empty"
[[ -n "$WORK_DIR" ]] || fatal "Work directory cannot be empty"
require_cmd nix

mkdir -p "$WORK_DIR/tmp" "$WORK_DIR/vm"
export TMPDIR="${WORK_DIR}/tmp"
export NIX_DISK_IMAGE="${NIX_DISK_IMAGE:-${WORK_DIR}/vm/${HOST}.qcow2}"
VM_RESULT_LINK="${WORK_DIR}/result-${HOST}-vm"

if (( LOCAL_STORE )); then
    if [[ -z "$STORE_ROOT" ]]; then
        STORE_ROOT="${WORK_DIR}/nix-root"
    fi
    mkdir -p "$STORE_ROOT"
fi

if (( COPY_WORKTREE )); then
    TMP_DIR="$(mktemp -d "${TMPDIR}/flake.XXXXXXXX")"
    cp -a "${NIXOS_DIR}/." "$TMP_DIR/"
    FLAKE_REF="$TMP_DIR"
    log "Using temp flake copy: $TMP_DIR"
else
    FLAKE_REF="$NIXOS_DIR"
fi

if (( KEEP_TMP )) && [[ -n "$TMP_DIR" ]]; then
    log "Temp copy will be kept: $TMP_DIR"
fi

log "Using work directory: $WORK_DIR"
log "Using VM disk image: $NIX_DISK_IMAGE"

nix_cmd=(
    nix
    --extra-experimental-features
    "nix-command flakes"
)

if (( LOCAL_STORE )); then
    nix_cmd+=(--store "$STORE_ROOT")
    export NIX_REMOTE="$STORE_ROOT"
    log "Using local chroot Nix store: $STORE_ROOT"
fi

case "$MODE" in
    check)
        log "Running flake check for ${HOST}"
        "${nix_cmd[@]}" flake check "$FLAKE_REF"
        ;;
    dry-build)
        log "Dry-running system build for ${HOST}"
        "${nix_cmd[@]}" build --dry-run \
            "${FLAKE_REF}#nixosConfigurations.${HOST}.config.system.build.toplevel"
        ;;
    build-vm)
        log "Building QEMU VM for ${HOST}"
        rm -f "$VM_RESULT_LINK"
        "${nix_cmd[@]}" build \
            --out-link "$VM_RESULT_LINK" \
            "${FLAKE_REF}#nixosConfigurations.${HOST}.config.system.build.vm"
        result_target="$(readlink "$VM_RESULT_LINK")"
        result_path="$(physical_store_path "$result_target")"
        log "VM runner built at ${result_path}/bin"
        ;;
    run-vm)
        log "Building QEMU VM for ${HOST}"
        rm -f "$VM_RESULT_LINK"
        "${nix_cmd[@]}" build \
            --out-link "$VM_RESULT_LINK" \
            "${FLAKE_REF}#nixosConfigurations.${HOST}.config.system.build.vm"
        result_target="$(readlink "$VM_RESULT_LINK")"
        result_path="$(physical_store_path "$result_target")"
        runner="$(find "${result_path}/bin" -maxdepth 1 \( -type f -o -type l \) -name 'run-*-vm' | head -n 1)"
        if [[ -z "$runner" ]]; then
            find "$result_path" -maxdepth 3 -type f -o -type l >&2 || true
            fatal "Could not find VM runner in ${result_path}/bin"
        fi
        if (( LOCAL_STORE )); then
            runner_name="$(basename "$runner")"
            log "Launching ${runner_name} through local chroot store"
            exec "${nix_cmd[@]}" shell \
                "${FLAKE_REF}#nixosConfigurations.${HOST}.config.system.build.vm" \
                --command "$runner_name"
        else
            log "Launching ${runner}"
            exec "$runner"
        fi
        ;;
    install-vm)
        log "Running nixos-anywhere VM install test for ${HOST}"
        "${nix_cmd[@]}" run github:nix-community/nixos-anywhere -- \
            --flake "${FLAKE_REF}#${HOST}" \
            --vm-test
        ;;
    *)
        fatal "Unhandled mode: $MODE"
        ;;
esac
