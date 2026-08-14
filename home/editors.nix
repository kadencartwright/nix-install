{ pkgs, pkgsUnstable, ... }:

{
  programs.neovim = {
    enable = true;
    package = pkgsUnstable.neovim-unwrapped;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    # Preserve the pre-26.05 integrations explicitly across the channel update.
    withPython3 = true;
    withRuby = true;
    extraPackages = with pkgs; [
      gcc
      lua-language-server
      nil
      nixfmt
      stylua
      pkgsUnstable.tree-sitter
    ];
  };
}
