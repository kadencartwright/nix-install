{ pkgs, ... }:

{
  time.timeZone = "America/Chicago";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
  ];

  environment.systemPackages = with pkgs; [
    btop
    curl
    git
    just
    neovim
    ripgrep
    vim
  ];

  programs.zsh.enable = true;
}
