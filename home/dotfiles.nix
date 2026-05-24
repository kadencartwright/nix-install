{ config, inputs, pkgs, ... }:

let
  dotfiles = inputs.dotfiles;
  onedarkWallpapers = inputs.onedark-wallpapers;
  zshEnv =
    builtins.replaceStrings
      [ ''. "$HOME/.cargo/env"'' ]
      [ ''[ -r "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"'' ]
      (builtins.readFile "${dotfiles}/zsh/.zshenv");
  waybarConfig =
    builtins.replaceStrings
      [
        "\"tray\",\n        \"custom/hyprwhspr\""
        ",\n    \"include\": [\n        \"/home/k/.config/waybar/hyprwhspr-module.jsonc\"\n    ]"
      ]
      [
        "\"tray\""
        ""
      ]
      (builtins.readFile "${dotfiles}/waybar/config.jsonc");
  waybarStyle =
    builtins.replaceStrings
      [ ''@import "/usr/lib/hyprwhspr/config/waybar/hyprwhspr-style.css";'' ]
      [ "" ]
      (builtins.readFile "${dotfiles}/waybar/style.css");
in
{
  xdg.configFile = {
    "aerospace".source = "${dotfiles}/aerospace";
    "aerospace-swipe".source = "${dotfiles}/aerospace-swipe";
    "alacritty".source = "${dotfiles}/alacritty";
    "electron-flags.conf".source = "${dotfiles}/electron/electron-flags.conf";
    "fontconfig/fonts.conf".source = "${dotfiles}/fontconfig/fonts.conf";
    "fuzzel".source = "${dotfiles}/fuzzel";
    "ghostty/config".text =
      builtins.replaceStrings
        [ "/bin/zsh" ]
        [ "${pkgs.zsh}/bin/zsh" ]
        (builtins.readFile "${dotfiles}/ghostty/config");
    "ghostty/themes".source = "${dotfiles}/ghostty/themes";
    "hypr/hypridle.conf".source = "${dotfiles}/hyprland/hypridle.conf";
    "hypr/hyprland.conf".source = "${dotfiles}/hyprland/hyprland.conf";
    "hypr/hyprlock.conf".source = "${dotfiles}/hyprland/hyprlock.conf";
    "hypr/macchiato.conf".source = "${dotfiles}/hyprland/macchiato.conf";
    "hypr/monitors.conf".source = "${dotfiles}/hyprland/monitors.conf";
    "hypr/workspaces.conf".source = "${dotfiles}/hyprland/workspaces.conf";
    "hypr/xdph.conf".source = "${dotfiles}/hyprland/xdph.conf";
    "karabiner".source = "${dotfiles}/karabiner";
    "kdeglobals".source = "${dotfiles}/kde/kdeglobals";
    "kitty".source = "${dotfiles}/kitty";
    "nvim".source = "${dotfiles}/nvim";
    "opencode/agent".source = "${dotfiles}/opencode/agent";
    "opencode/bun.lock".source = "${dotfiles}/opencode/bun.lock";
    "opencode/opencode.json".source = "${dotfiles}/opencode/opencode.jsonc";
    "opencode/opencode.jsonc".source = "${dotfiles}/opencode/opencode.jsonc";
    "opencode/package.json".source = "${dotfiles}/opencode/package.json";
    "opencode/prompts".source = "${dotfiles}/opencode/prompts";
    "opencode/tool".source = "${dotfiles}/opencode/tool";
    "sketchybar".source = "${dotfiles}/sketchybar";
    "starship".source = "${dotfiles}/starship";
    "sway".source = "${dotfiles}/sway";
    "swaylock".source = "${dotfiles}/swaylock";
    "tmux".source = "${dotfiles}/tmux";
    "vim/.vimrc".source = "${dotfiles}/vim/.vimrc";
    "waybar/config.jsonc".text = waybarConfig;
    "waybar/style.css".text = waybarStyle;
    "hypr/hyprpaper.conf".text = ''
      wallpaper {
          monitor =
          path = ${onedarkWallpapers}/os/od_nixos.png
          fit_mode = cover
      }

      splash = false
      ipc = off
    '';
  };

  programs.zsh = {
    dotDir = "${config.xdg.configHome}/zsh";
    envExtra = zshEnv;
    initContent = builtins.readFile "${dotfiles}/zsh/.zshrc";
  };
}
