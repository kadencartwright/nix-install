{
  config,
  inputs,
  isDesktop ? false,
  pkgsUnstable,
  ...
}:

let
  dotfiles = inputs.dotfiles;
  hyprwhspr = if isDesktop then pkgsUnstable.callPackage ../packages/hyprwhspr.nix { } else null;
  hyprwhsprRoot = if isDesktop then "${hyprwhspr}/lib/hyprwhspr" else "/usr/lib/hyprwhspr";
  onedarkWallpapers = inputs.onedark-wallpapers;
  zshInit =
    builtins.replaceStrings
      [ ''source "$HOME/.cargo/env"'' ]
      [ ''[ -r "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"'' ]
      (builtins.readFile "${dotfiles}/zsh/.zshrc");
  waybarConfig =
    if isDesktop then
      builtins.readFile "${dotfiles}/waybar/config.jsonc"
    else
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
  waybarModule =
    builtins.replaceStrings
      [ "/usr/lib/hyprwhspr" ]
      [ hyprwhsprRoot ]
      (builtins.readFile "${dotfiles}/waybar/hyprwhspr-module.jsonc");
  waybarStyle =
    builtins.replaceStrings
      [ "/usr/lib/hyprwhspr" ]
      [ (if isDesktop then hyprwhsprRoot else "") ]
      (builtins.readFile "${dotfiles}/waybar/style.css");
  hyprlandConfig =
    builtins.replaceStrings
      [
        "/usr/lib/hyprwhspr"
        ''hl.env("SSH_AUTH_SOCK", home .. "/.bitwarden-ssh-agent.sock")''
        ''hl.env("QT_QPA_PLATFORMTHEME", "adwaita")''
        ''hl.env("QT_STYLE_OVERRIDE", "adwaita-dark")''
        ''hl.exec_cmd("wayle shell")''
      ]
      [
        hyprwhsprRoot
        ''hl.env("SSH_AUTH_SOCK", (os.getenv("XDG_RUNTIME_DIR") or "") .. "/ssh-agent")''
        ''hl.env("QT_QPA_PLATFORMTHEME", "gtk")''
        ''hl.env("QT_STYLE_OVERRIDE", "gtk2")''
        ''hl.exec_cmd("quickshell")''
      ]
      (builtins.readFile "${dotfiles}/hyprland/hyprland.lua");
in
{
  xdg.configFile = {
    "aerospace".source = "${dotfiles}/aerospace";
    "aerospace-swipe".source = "${dotfiles}/aerospace-swipe";
    "alacritty".source = "${dotfiles}/alacritty";
    "electron-flags.conf".source = "${dotfiles}/electron/electron-flags.conf";
    "fontconfig/fonts.conf".source = "${dotfiles}/fontconfig/fonts.conf";
    "fuzzel".source = "${dotfiles}/fuzzel";
    "hypr/hypridle.conf".source = "${dotfiles}/hyprland/hypridle.conf";
    "hypr/hyprland.lua".text = hyprlandConfig;
    "hypr/hyprlock.conf".source = "${dotfiles}/hyprland/hyprlock.conf";
    "hypr/macchiato.conf".source = "${dotfiles}/hyprland/macchiato.conf";
    "hypr/monitors.conf".source = "${dotfiles}/hyprland/monitors.conf";
    "hypr/monitors.lua".source = "${dotfiles}/hyprland/monitors.lua";
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
    "waybar/hyprwhspr-module.jsonc" = {
      enable = isDesktop;
      text = waybarModule;
    };
    "waybar/style.css".text = waybarStyle;
    "quickshell".source = ./quickshell;
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
    envExtra = builtins.readFile "${dotfiles}/zsh/.zshenv";
    initContent = zshInit;
  };
}
