{ config, inputs, ... }:

let
  dotfiles = inputs.dotfiles;
in
{
  xdg.configFile = {
    "nvim".source = "${dotfiles}/nvim";
    "opencode/agent".source = "${dotfiles}/opencode/agent";
    "opencode/bun.lock".source = "${dotfiles}/opencode/bun.lock";
    "opencode/opencode.json".source = "${dotfiles}/opencode/opencode.jsonc";
    "opencode/opencode.jsonc".source = "${dotfiles}/opencode/opencode.jsonc";
    "opencode/package.json".source = "${dotfiles}/opencode/package.json";
    "opencode/prompts".source = "${dotfiles}/opencode/prompts";
    "opencode/tool".source = "${dotfiles}/opencode/tool";
    "starship".source = "${dotfiles}/starship";
    "tmux".source = "${dotfiles}/tmux";
    "vim/.vimrc".source = "${dotfiles}/vim/.vimrc";
  };

  programs.zsh = {
    dotDir = "${config.xdg.configHome}/zsh";
    envExtra = builtins.readFile "${dotfiles}/zsh/.zshenv";
    initContent = builtins.readFile "${dotfiles}/zsh/.zshrc";
  };
}
