{
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initContent = ''
      nhz() { nh os switch github:kadencartwright/nix-install#Z16 -- --refresh "$@"; }
      nhz16() { nh os switch github:kadencartwright/nix-install#Z16 -- --refresh "$@"; }
      nhx() { nh os switch github:kadencartwright/nix-install#X1C -- --refresh "$@"; }
      nhx1c() { nh os switch github:kadencartwright/nix-install#X1C -- --refresh "$@"; }
      nhm() { nh os switch github:kadencartwright/nix-install#MINI -- --refresh "$@"; }
      nhmini() { nh os switch github:kadencartwright/nix-install#MINI -- --refresh "$@"; }
      nhp() { nh os switch github:kadencartwright/nix-install#pi5 -- --refresh "$@"; }
      nhpi5() { nh os switch github:kadencartwright/nix-install#pi5 -- --refresh "$@"; }
    '';
  };

  programs.starship.enable = true;
  programs.zoxide.enable = true;
}
