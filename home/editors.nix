{ pkgs, pkgsUnstable, ... }:

{
  programs.neovim = {
    enable = true;
    package = pkgsUnstable.neovim-unwrapped;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    extraPackages = with pkgs; [
      gcc
      lua-language-server
      nil
      nixfmt-rfc-style
      stylua
      pkgsUnstable.tree-sitter
    ];
  };
}
