{ config, inputs, ... }:

let
  dotfiles = inputs.dotfiles;
  zshInit =
    builtins.replaceStrings
      [ ''source "$HOME/.cargo/env"'' ]
      [ ''[ -r "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"'' ]
      (builtins.readFile "${dotfiles}/zsh/.zshrc");
in
{
  xdg.configFile = {
    "nvim".source = "${dotfiles}/nvim";
    "starship".source = "${dotfiles}/starship";
    "tmux".source = "${dotfiles}/tmux";
    "vim/.vimrc".source = "${dotfiles}/vim/.vimrc";
  };

  programs.zsh = {
    dotDir = "${config.xdg.configHome}/zsh";
    envExtra = builtins.readFile "${dotfiles}/zsh/.zshenv";
    initContent = zshInit;
  };
}
