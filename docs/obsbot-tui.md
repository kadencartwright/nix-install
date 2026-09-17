# OBSBOT AI mode persistence

The upstream TUI's framing command writes camera config offset `0x0d`.
On the Meet SE, this also switches live AI mode to group and persists group
as the boot mode, even when tracking was off. The local package patch blocks
framing changes while AI is off (or camera status is unavailable).

The packaged TUI also applies `~/.config/obsbot-cli/config.toml` at launch,
respecting `XDG_CONFIG_HOME`. This restores the declarative preferences in
`home/desktop.nix`, including AI off, boot AI off, and gesture auto-frame off.
An existing config that fails to apply stops launch with the CLI error;
without a config, the TUI starts normally. TUI edits change camera state,
while the config remains the source of preferences for the next launch.

## Hardware regression check

With the OBSBOT connected and the repository's config installed:

1. Open `obsbot-tui` and check that AI mode and Boot AI mode both show off.
2. Select Framing and press either arrow. It should report that framing
   requires AI mode to be enabled; both AI modes must remain off.
3. Enable group explicitly using AI mode, quit, and reopen the TUI.
   Both AI modes should return to off from the saved config.
4. Sleep and wake using `s` and `w`; verify AI remains off.
5. Quit and run `obsbot-cli status`. Expect `ai_mode: off` and
   `boot_mode: 0x00`.

The package build also runs the upstream Rust workspace tests.
