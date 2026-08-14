#!/usr/bin/env bash
set -euo pipefail

REPO="${REPO:-github:kadencartwright/nix-install}"
REF="${REF:-main}"
ROOT="${ROOT:-/mnt}"
RAW_REPO="${RAW_REPO:-https://raw.githubusercontent.com/kadencartwright/nix-install}"
DISKO_FLAKE="${DISKO_FLAKE:-github:nix-community/disko/de5708739256238fb912c62f03988815db89ec9a}"

TTY_DEVICE=/dev/tty
WORKDIR=""
LUKS_KEY_FILE=""

log() {
    printf '[install-nixos] %s\n' "$*"
}

fatal() {
    printf '[install-nixos] error: %s\n' "$*" >&2
    exit 1
}

remove_luks_key() {
    if [[ -n "$LUKS_KEY_FILE" \
        && "$LUKS_KEY_FILE" == /run/nix-install-luks-key.* \
        && ( -e "$LUKS_KEY_FILE" || -L "$LUKS_KEY_FILE" ) ]]; then
        rm -f -- "$LUKS_KEY_FILE"
    fi
    LUKS_KEY_FILE=""
}

cleanup() {
    remove_luks_key
    if [[ -n "$WORKDIR" && "$WORKDIR" == /tmp/nix-install.* && -d "$WORKDIR" ]]; then
        rm -rf -- "$WORKDIR"
    fi
}

trap cleanup EXIT

prompt() {
    local message="$1"
    local answer
    printf '%s' "$message" >"$TTY_DEVICE"
    IFS= read -r answer <"$TTY_DEVICE"
    printf '%s' "$answer"
}

prompt_secret() {
    local message="$1"
    printf '%s' "$message" >"$TTY_DEVICE"
    IFS= read -r -s REPLY <"$TTY_DEVICE"
    printf '\n' >"$TTY_DEVICE"
}

collect_luks_passphrase() {
    local first second REPLY

    while true; do
        prompt_secret 'New LUKS passphrase: '
        first="$REPLY"
        if [[ -z "$first" ]]; then
            printf 'The LUKS passphrase cannot be empty.\n' >"$TTY_DEVICE"
            continue
        fi

        prompt_secret 'Confirm LUKS passphrase: '
        second="$REPLY"
        if [[ "$first" != "$second" ]]; then
            printf 'Passphrases did not match; try again.\n' >"$TTY_DEVICE"
            continue
        fi
        break
    done

    LUKS_KEY_FILE="$(mktemp /run/nix-install-luks-key.XXXXXXXX)"
    chmod 600 "$LUKS_KEY_FILE"
    printf '%s' "$first" >"$LUKS_KEY_FILE"
    unset first second REPLY
}

choose_host() {
    local choice

    printf '\nSelect the machine profile:\n\n' >"$TTY_DEVICE"
    printf '  1) Z16   Lenovo ThinkPad Z16 desktop profile\n' >"$TTY_DEVICE"
    printf '  2) T16   Lenovo ThinkPad T16 desktop profile\n' >"$TTY_DEVICE"
    printf '  3) X1C   Lenovo ThinkPad X1 Carbon desktop profile\n' >"$TTY_DEVICE"
    printf '  4) MINI  Headless mini-PC profile\n\n' >"$TTY_DEVICE"

    while true; do
        choice="$(prompt 'Host [1-4]: ')"
        case "$choice" in
            1 | Z16 | z16)
                HOST=Z16
                return
                ;;
            2 | T16 | t16)
                HOST=T16
                return
                ;;
            3 | X1C | x1c)
                HOST=X1C
                return
                ;;
            4 | MINI | mini)
                HOST=MINI
                return
                ;;
            *) printf 'Choose 1, 2, 3, or 4.\n' >"$TTY_DEVICE" ;;
        esac
    done
}

stable_id_for_device() {
    local device="$1"
    local resolved candidate basename rank

    resolved="$(readlink -f "$device")"
    for candidate in /dev/disk/by-id/*; do
        [[ -L "$candidate" ]] || continue
        basename="${candidate##*/}"
        [[ "$basename" != *-part* ]] || continue
        [[ "$(readlink -f "$candidate")" == "$resolved" ]] || continue

        case "$basename" in
            ata-* | nvme-*) rank=10 ;;
            scsi-* | usb-*) rank=20 ;;
            wwn-*) rank=30 ;;
            *) rank=40 ;;
        esac
        printf '%02d\t%s\n' "$rank" "$candidate"
    done | sort -k1,1n -k2,2 | sed -n '1s/^[^	]*\t//p'
}

choose_disk() {
    local -a disk_ids=()
    local -a disk_devices=()
    local device disk_id details choice index

    printf '\nAvailable whole disks with stable IDs:\n\n' >"$TTY_DEVICE"

    while IFS= read -r device; do
        [[ -n "$device" ]] || continue
        disk_id="$(stable_id_for_device "$device")"
        [[ -n "$disk_id" ]] || continue
        disk_devices+=("$device")
        disk_ids+=("$disk_id")
        details="$(lsblk -dn -o SIZE,MODEL,SERIAL,TRAN "$device" | sed 's/[[:space:]]*$//')"
        printf '  %d) %-28s %s\n     %s\n' \
            "${#disk_ids[@]}" "$device" "$details" "$disk_id" >"$TTY_DEVICE"
    done < <(lsblk -dnpo NAME,TYPE | awk '$2 == "disk" { print $1 }')

    if ((${#disk_ids[@]} == 0)); then
        fatal 'No whole disks with /dev/disk/by-id names were found'
    fi

    printf '\nThe selected disk will be completely erased.\n\n' >"$TTY_DEVICE"
    while true; do
        choice="$(prompt "Disk [1-${#disk_ids[@]}]: ")"
        if [[ "$choice" =~ ^[0-9]+$ ]] \
            && ((choice >= 1 && choice <= ${#disk_ids[@]})); then
            index=$((choice - 1))
            DISK="${disk_ids[$index]}"
            TARGET_DEVICE="${disk_devices[$index]}"
            return
        fi
        printf 'Choose a disk number from the list.\n' >"$TTY_DEVICE"
    done
}

validate_host() {
    case "$HOST" in
        Z16 | T16 | X1C | MINI) ;;
        *) fatal "HOST must be Z16, T16, X1C, or MINI (got: $HOST)" ;;
    esac
}

validate_disk() {
    local resolved mounted

    case "$DISK" in
        /dev/disk/by-id/*) ;;
        *) fatal 'DISK must use a stable /dev/disk/by-id/... whole-disk path' ;;
    esac

    [[ "${DISK##*/}" != *-part* ]] || fatal 'DISK must refer to a whole disk, not a partition'
    [[ -b "$DISK" ]] || fatal "DISK is not a block device: $DISK"

    resolved="$(readlink -f "$DISK")"
    [[ "$(lsblk -dnro TYPE "$resolved")" == disk ]] \
        || fatal "DISK does not resolve to a whole disk: $DISK"
    TARGET_DEVICE="$resolved"

    mounted="$(lsblk -nrpo MOUNTPOINT "$resolved" | awk 'NF { print }')"
    if [[ -n "$mounted" ]]; then
        printf '%s\n' "$mounted" >&2
        fatal 'The selected disk or one of its partitions is mounted; unmount it before installing'
    fi
}

repo_url_for() {
    case "$REPO" in
        github:*) printf 'https://github.com/%s.git' "${REPO#github:}" ;;
        https://github.com/*.git) printf '%s' "$REPO" ;;
        https://github.com/*) printf '%s.git' "$REPO" ;;
        *) fatal 'REPO must be github:owner/repo or a GitHub URL' ;;
    esac
}

git_cmd() {
    if command -v git >/dev/null 2>&1; then
        git "$@"
    else
        nix --extra-experimental-features 'nix-command flakes' shell nixpkgs#git -c git "$@"
    fi
}

if ((EUID != 0)); then
    command -v sudo >/dev/null 2>&1 || fatal 'sudo is required to install NixOS'
    printf '[install-nixos] requesting administrator access...\n'
    sudo -v

    elevated_env=(
        env
        "REPO=$REPO"
        "REF=$REF"
        "ROOT=$ROOT"
        "RAW_REPO=$RAW_REPO"
        "DISKO_FLAKE=$DISKO_FLAKE"
    )
    if [[ -n "${HOST:-}" ]]; then
        elevated_env+=("HOST=$HOST")
    fi
    if [[ -n "${DISK:-}" ]]; then
        elevated_env+=("DISK=$DISK")
    fi

    if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
        exec sudo "${elevated_env[@]}" bash "${BASH_SOURCE[0]}"
    fi

    curl -fsSL "${RAW_REPO}/${REF}/scripts/install-nixos.sh" \
        | sudo "${elevated_env[@]}" bash
    exit 0
fi

[[ -r "$TTY_DEVICE" && -w "$TTY_DEVICE" ]] \
    || fatal 'This installer needs an interactive terminal for prompts'
[[ -d /sys/firmware/efi ]] \
    || fatal 'The live ISO was not booted in UEFI mode; reboot it using the UEFI boot entry'

for command in nix nixos-install lsblk readlink awk sed sort; do
    command -v "$command" >/dev/null 2>&1 || fatal "Required command not found: $command"
done

printf '\nNixOS guided installer\n' >"$TTY_DEVICE"
printf '======================\n' >"$TTY_DEVICE"
printf 'This installs one of the nix-install host profiles using Disko.\n' >"$TTY_DEVICE"
printf 'The selected disk will be irreversibly erased.\n' >"$TTY_DEVICE"

if [[ -z "${HOST:-}" ]]; then
    choose_host
fi
validate_host

if [[ -z "${DISK:-}" ]]; then
    choose_disk
fi

validate_disk
repo_url="$(repo_url_for)"
details="$(lsblk -dn -o SIZE,MODEL,SERIAL,TRAN "$TARGET_DEVICE" | sed 's/[[:space:]]*$//')"

printf '\nInstall plan\n' >"$TTY_DEVICE"
printf '%s\n' '------------' >"$TTY_DEVICE"
printf 'Host profile:  %s\n' "$HOST" >"$TTY_DEVICE"
printf 'Repository:    %s\n' "$repo_url" >"$TTY_DEVICE"
printf 'Git reference: %s\n' "$REF" >"$TTY_DEVICE"
printf 'Target disk:   %s\n' "$DISK" >"$TTY_DEVICE"
printf 'Disk details:  %s\n' "$details" >"$TTY_DEVICE"
printf 'Mount target:  %s\n' "$ROOT" >"$TTY_DEVICE"
printf '\nDisk layout:\n' >"$TTY_DEVICE"
printf '  - GPT partition table\n' >"$TTY_DEVICE"
printf '  - 1 GiB FAT32 EFI system partition mounted at /boot\n' >"$TTY_DEVICE"
printf '  - Remaining space: LUKS encryption -> LVM -> ext4 root\n' >"$TTY_DEVICE"
printf '\nAfter confirmation, the installer will securely ask for the new LUKS passphrase.\n' >"$TTY_DEVICE"

confirmation="$(prompt "\nType ERASE ${HOST} to erase ${TARGET_DEVICE} and continue: ")"
if [[ "$confirmation" != "ERASE $HOST" ]]; then
    fatal 'Confirmation did not match; nothing was changed'
fi

collect_luks_passphrase

WORKDIR="$(mktemp -d /tmp/nix-install.XXXXXXXX)"
FLAKE="${WORKDIR}#${HOST}"

log "cloning $repo_url at $REF"
git_cmd clone --filter=blob:none "$repo_url" "$WORKDIR"
git_cmd -C "$WORKDIR" checkout "$REF"

sed -i "s#/dev/disk/by-id/replace-me#${DISK}#" "$WORKDIR/hosts/common/disko.nix"
sed -i "s#/tmp/secret.key#${LUKS_KEY_FILE}#" "$WORKDIR/hosts/common/disko.nix"
if grep -q '/dev/disk/by-id/replace-me' "$WORKDIR/hosts/common/disko.nix"; then
    fatal 'Failed to set the target disk in the temporary Disko configuration'
fi
if grep -q '/tmp/secret.key' "$WORKDIR/hosts/common/disko.nix"; then
    fatal 'Failed to set the temporary LUKS key file in the Disko configuration'
fi

log 'formatting and mounting the target disk'
nix --extra-experimental-features 'nix-command flakes' \
    run "$DISKO_FLAKE" -- \
    --mode destroy,format,mount \
    --flake "$FLAKE" \
    --root-mountpoint "$ROOT" \
    --yes-wipe-all-disks \
    --no-deps
remove_luks_key

log "installing NixOS into $ROOT"
nixos-install \
    --root "$ROOT" \
    --flake "$FLAKE" \
    --no-root-passwd \
    --max-jobs 1 \
    --cores 2 \
    --option experimental-features 'nix-command flakes'

printf '\nInstallation complete.\n' >"$TTY_DEVICE"
printf 'Reboot, remove the ISO, and unlock the disk with your LUKS passphrase.\n' >"$TTY_DEVICE"
printf 'At Lemurs, log in as k with the bootstrap password: nixos\n' >"$TTY_DEVICE"
printf 'Immediately run passwd after login; PAM will update the login keyring too.\n' >"$TTY_DEVICE"
printf 'Then run hyprwhspr setup and sudo tailscale up as needed.\n\n' >"$TTY_DEVICE"
printf 'Reboot now? [y/N]: ' >"$TTY_DEVICE"
IFS= read -r reboot_answer <"$TTY_DEVICE"
case "$reboot_answer" in
    y | Y | yes | YES) systemctl reboot ;;
    *) log 'leaving the installed system mounted at /mnt' ;;
esac
