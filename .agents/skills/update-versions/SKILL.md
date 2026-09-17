---
name: update-versions
description: Update pinned T3 Code, ChatGPT desktop, Codex CLI, and OpenCode versions and source hashes in the nix-install repository. Use when asked to bump these apps to latest or invoke update-versions; includes release discovery, package builds, and reporting apps already current.
---

# Update versions

Update the requested app pins in the repository containing this skill (or the user's specified checkout). Run commands from that repository root. With no app subset specified, check T3 Code, ChatGPT, Codex, and OpenCode. Resolve latest stable releases afresh every run; do not copy versions or hashes from an earlier conversation. Honor an explicit version or prerelease request.

## Locate the active packages

Read applicable `AGENTS.md` instructions and `git status --short`, then inspect the current package definitions and their callers. Preserve existing user changes. These are navigation hints; the checkout is authoritative:

| App | Active pins | Release source |
| --- | --- | --- |
| T3 Code desktop | `packages/t3code.nix` | GitHub `pingdotgg/t3code` |
| T3 CLI (`t3`) | `packages/t3-cli/default.nix`, `package.json`, `package-lock.json` | npm package `t3` |
| ChatGPT desktop | `chatgptVersion` and `src.hash` in `home/cli.nix` | OpenAI's Linux Debian repository |
| Codex CLI | `packages/codex.nix` | GitHub `openai/codex`, tags `rust-v…` |
| OpenCode CLI | `packages/opencode.nix` | GitHub `anomalyco/opencode` |
| OpenCode desktop | `packages/opencode-desktop.nix` | Same OpenCode release |

Treat T3 desktop and CLI as a pair to check, and OpenCode desktop and CLI as a pair to check. `packages/openai-codex-desktop/` is a legacy package: do not update it unless active configuration imports it or the user requests it. CodexBar is a separate app outside the default scope.

## Discover releases and verified hashes

Fetch authoritative release metadata over the network. Independent lookups can run concurrently. Useful endpoints:

- `https://api.github.com/repos/pingdotgg/t3code/releases/latest`
- `https://registry.npmjs.org/t3/latest`
- `https://api.github.com/repos/openai/codex/releases/latest`
- `https://api.github.com/repos/anomalyco/opencode/releases/latest`
- `https://persistent.oaistatic.com/codex-app-prod/linux/deb/dists/stable/main/binary-amd64/Packages`

Use GitHub's latest stable release, not the highest tag including alpha builds. Confirm the expected assets exist. For T3, check npm's version separately; do not assume the desktop release has already been published to npm. Report publication gaps and update only to available releases.

For ChatGPT, select the `Package: chatgpt`, `Architecture: amd64` stanza. Read its `Version`, `Filename`, and `SHA256`. Resolve `Filename` relative to `https://persistent.oaistatic.com/codex-app-prod/linux/deb/`.

GitHub assets can supply a `digest` such as `sha256:HEX`; npm supplies `dist.integrity`. Convert a SHA-256 hex digest to Nix SRI using `nix hash convert --hash-algo sha256 --to sri HEX`. Preserve valid SHA-512 SRI values from npm. If metadata omits a digest, prefetch the exact asset and calculate it. Never invent hashes or leave placeholder hashes in the final changes.

Verify downloads against the expected hashes through Nix builds or:

```sh
nix store prefetch-file --json --hash-type sha256 \
  --expected-hash 'sha256-BASE64' 'EXACT_ASSET_URL'
```

`curl`, `jq`, `node`, and `nix` were available in this checkout's environment; check tools before relying on Python or npm. Fetch current metadata directly if a browser result looks cached or incomplete.

## Update the pins

Only edit apps with an available newer requested release. Report unchanged apps as already current. Update all supported architecture hashes together:

- Codex: package archive and code-mode-host archive for both `x86_64-linux` and `aarch64-linux`. Preserve the bundled host installation and wrapper PATH dependencies; check archive layout if upstream changes packaging.
- OpenCode CLI: x64 and ARM64 archives. Preserve the glibc-loader wrapper and `dontStrip`: Bun standalone binaries contain an ELF trailer that `patchelf` can damage.
- OpenCode and T3 desktop: x86_64 AppImage sources and their existing desktop integration wrappers.
- ChatGPT: version and Debian source hash in the active `overrideAttrs`. The source pin normally suffices; update the packaging flake input only if the new package requires a packaging change.
- T3 CLI: update the tarball version/integrity, obtain the new published package manifest, reconcile any intentional local adjustments, and regenerate its npm lockfile if needed. Keep manifest, lockfile root version, and derivation consistent. Preserve the `importNpmLock` setup and inspect the existing removal of npm `overrides` and custom fetcher names before making changes. Build to verify dependency and native-module compatibility.

Update affected version mentions in `docs/nixos-package-mapping.md` or other directly relevant documentation. Avoid a blanket flake lock update or unrelated dependency upgrades.

## Validate

Run `git diff --check`, evaluate the flake with `nix flake check --no-build`, and build the changed packages without activating the system. Build the packages from the actual Home Manager configuration so overrides are included. For example, on an x86_64 builder, from the repository root:

```sh
nix build --impure --no-link --print-out-paths --expr '
  let
    f = builtins.getFlake (toString ./.);
    ps = f.nixosConfigurations.Z16.config.home-manager.users.k.home.packages;
  in builtins.filter
    (p: builtins.elem (p.pname or "")
      [ "opencode" "opencode-desktop" "chatgpt" ]) ps
'
```

Adapt the host, user, and pname list to the changed packages and actual checkout. Confirm the selected list includes every intended package; an empty list can build successfully without validating anything. For T3/Codex changes include their actual pnames, and rebuild dependent wrappers where relevant.

Check the built OpenCode/Codex CLI with `--version` when changed. Desktop builds verify packaging, not interactive GUI behavior; do not claim GUI testing unless performed.

On x86_64, verify ARM64 source downloads with `nix store prefetch-file --expected-hash`. Building an ARM64 `fetchurl` derivation directly can fail with a platform mismatch even though it only downloads a file. A native ARM64 package build needs a compatible builder; report that distinction accurately.

Inspect the final diff and summarize old/new versions, already-current apps, verification results, and any actual blockers. Include authoritative release links where useful. A version-bump request authorizes editing and building; activate with `nh os switch`, commit, or push only when the user requests those actions. If activation was not requested, give `nh os switch` as the next step and state that the changes are configuration updates.
