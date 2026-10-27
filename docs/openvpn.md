# Host-local OpenVPN connections

The shared networking module enables NetworkManager's OpenVPN plugin and watches
`/var/lib/openvpn-import/` on each host. This directory is root-owned, mode 0700,
and is never read during Nix evaluation or copied into the Nix store.

## Add a connection

1. Copy certificates, private keys, and any password files into that directory
   with owner `root:root` and mode 0600. Use only trusted VPN profiles.
2. Ensure the profile's `cert`, `key`, and other file references match the local
   files (relative paths resolve from the import directory).
3. Copy the `.ovpn` file into the directory **last**, also with mode 0600.

Top-level `.ovpn` files become NetworkManager connections named `VPN: <filename
without extension>`. Inline CA certificates are supported by NetworkManager's
importer. Passwords, if required, can be supplied interactively with `nmcli --ask`;
never embed them in Nix expressions.

Imports run on directory changes, at boot, and every minute. Connections are
**not automatically activated**. Imported connections ignore VPN-provided DNS
for both IPv4 and IPv6; explicit DNS servers and search domains are cleared too.
Your normal Wi-Fi/Ethernet DNS remains in use. Private VPN-only names may require
a separate split-DNS setup. Both IP families also set `never-default`, preventing
NetworkManager from choosing this VPN as the default connection. More-specific
server-provided routes are still accepted: this is not a strict destination
allowlist, and broad routes (such as two `/1` routes) can still redirect traffic.
For strict split tunneling, obtain the work-network CIDRs, disable automatic VPN
routes, and configure only those explicit routes. Do not guess private ranges:
they may overlap local networks or other VPNs.

Use the VPN section in Quickshell's network panel or:

```sh
nmcli --ask connection up 'VPN: twi'
nmcli connection down 'VPN: twi'
```

Replacing any file in the directory reimports all managed profiles on the next
scan. This disconnects an active managed VPN; reconnect manually afterward.
Removing an `.ovpn` file removes its managed NetworkManager connection. Unrelated
NetworkManager connections are left alone. Supporting files are not deleted.
Malformed imports retain the previous connection and are retried.

For bulk updates, stop `openvpn-import.path` and `openvpn-import.timer` first,
wait for any running `openvpn-import.service` to finish, replace the files, then
restart the path/timer and start the service.

Check imports with:

```sh
systemctl status openvpn-import.service
journalctl -u openvpn-import.service
```

Importer bookkeeping lives in `/var/lib/openvpn-import-state/`. NetworkManager
stores imported profiles in its root-only system connection directory and may
extract inline certificates into root's local data directory. None of these
files belong in Git. The original downloads remain until you remove them.

## X1C setup

The original TWI profile is installed as `twi.ovpn`. Its certificate and private
key are installed using the `kcartwright.theworshipinitiative.com.*` filenames
referenced by the profile, rather than the differing downloaded filenames.

This module is shared, not tied to X1C: install local VPN files on any other host
to use it there. An empty import directory does nothing.

Hosts' `nhr` aliases rebuild from `origin/main`, so the module changes must be
committed and pushed before a future `nhr` can preserve this setup.
