{ osConfig, ... }:

let
  host = osConfig.networking.hostName;
in
{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      nhos() { nh os switch github:kadencartwright/nix-install#${host} -- --refresh "$@"; }
      nhr() { nhos "$@"; }
    '';
  };

  programs.starship.enable = true;
  programs.zoxide.enable = true;
}
