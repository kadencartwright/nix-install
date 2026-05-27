{ lib, osConfig, ... }:

let
  host = osConfig.networking.hostName;
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = lib.mkAfter ''
      nhos() { nh os switch github:kadencartwright/nix-install#${host} -- --refresh "$@"; }
      nhr() { nhos "$@"; }

      if command -v fnm >/dev/null 2>&1; then
        eval "$(fnm env --use-on-cd --shell zsh)"
      fi
    '';
  };

  programs.starship.enable = true;
  programs.zoxide.enable = true;
}
