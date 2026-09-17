{ pkgs, upstream }:

upstream.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./obsbot-tui-framing.patch ];
  nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.makeWrapper ];

  # The upstream TUI only reads camera state; apply our desired state first.
  postFixup = (old.postFixup or "") + ''
    wrapProgram "$out/bin/obsbot-tui" \
      --run 'config="''${XDG_CONFIG_HOME:-$HOME/.config}/obsbot-cli/config.toml"; if [ -f "$config" ]; then "'"$out"'/bin/obsbot-cli" --config "$config" apply || exit $?; fi'
  '';
})
