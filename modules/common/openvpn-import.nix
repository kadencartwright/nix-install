{ pkgs, ... }:

let
  importer = pkgs.writeScript "openvpn-import" ''
    #!${pkgs.python3}/bin/python3
    import hashlib
    import json
    import os
    from pathlib import Path
    import re
    import subprocess

    root = Path("/var/lib/openvpn-import")
    state_file = Path("/var/lib/openvpn-import-state/state.json")
    state = json.loads(state_file.read_text()) if state_file.exists() else {}

    def nm(*args):
        return subprocess.check_output(
            ["${pkgs.networkmanager}/bin/nmcli", *args],
            text=True, stderr=subprocess.STDOUT,
            env={**os.environ, "LC_ALL": "C"},
        ).strip()

    def save():
        temporary = state_file.with_suffix(".tmp")
        temporary.write_text(json.dumps(state))
        temporary.replace(state_file)

    # Include supporting files so replacing a certificate/key triggers an import.
    digest = hashlib.sha256(b"ignore-vpn-dns-v1\0")
    for path in sorted(root.rglob("*")):
        if path.is_file():
            digest.update(str(path.relative_to(root)).encode())
            digest.update(b"\0")
            digest.update(path.read_bytes())
    fingerprint = digest.hexdigest()
    known = set(nm("-g", "UUID", "connection", "show").splitlines())
    profiles = {p.name: p for p in root.glob("*.ovpn") if p.is_file()}
    failed = False

    for name, path in sorted(profiles.items()):
        previous = state.get(name)
        if previous and previous["hash"] == fingerprint and previous["uuid"] in known:
            continue
        try:
            # Import first: a malformed replacement must not remove the old profile.
            output = nm("connection", "import", "type", "openvpn", "file", str(path))
            match = re.search(r"\(([0-9a-f-]{36})\)", output)
            if not match:
                raise RuntimeError("Could not identify imported connection: " + output)
            connection = match.group(1)
            try:
                nm("connection", "modify", "uuid", connection,
                   "connection.id", "VPN: " + path.stem,
                   "connection.autoconnect", "no",
                   "ipv4.ignore-auto-dns", "yes", "ipv6.ignore-auto-dns", "yes",
                   "ipv4.dns", "", "ipv6.dns", "",
                   "ipv4.dns-search", "", "ipv6.dns-search", "")
                if previous and previous["uuid"] in known:
                    nm("connection", "delete", "uuid", previous["uuid"])
            except Exception:
                nm("connection", "delete", "uuid", connection)
                raise
            state[name] = {"hash": fingerprint, "uuid": connection}
            save()
            print("Imported " + name, flush=True)
        except Exception as error:
            failed = True
            print("Failed to import " + name + ": " + str(error), flush=True)

    for name in list(state):
        if name not in profiles:
            try:
                if state[name]["uuid"] in known:
                    nm("connection", "delete", "uuid", state[name]["uuid"])
                del state[name]
                save()
            except Exception as error:
                failed = True
                print("Failed to remove " + name + ": " + str(error), flush=True)
    raise SystemExit(1 if failed else 0)
  '';
in
{
  networking.networkmanager.plugins = [ pkgs.networkmanager-openvpn ];

  systemd.tmpfiles.rules = [
    "d /var/lib/openvpn-import 0700 root root -"
  ];

  systemd.services.openvpn-import = {
    description = "Import host-local OpenVPN profiles into NetworkManager";
    wants = [ "NetworkManager.service" ];
    after = [ "NetworkManager.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = importer;
      WorkingDirectory = "/var/lib/openvpn-import";
      StateDirectory = "openvpn-import-state";
      StateDirectoryMode = "0700";
      UMask = "0077";
    };
  };

  systemd.paths.openvpn-import = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = "/var/lib/openvpn-import";
  };

  # Also retry failed imports, discover nested certificate changes, and scan at boot.
  systemd.timers.openvpn-import = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "1min";
    };
  };
}
