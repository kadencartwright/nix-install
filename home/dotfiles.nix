{
  config,
  inputs,
  isDesktop ? false,
  pkgs,
  pkgsUnstable,
  ...
}:

let
  dotfiles = inputs.dotfiles;
  hyprwhspr = if isDesktop then pkgsUnstable.callPackage ../packages/hyprwhspr.nix { } else null;
  hyprwhsprRoot = if isDesktop then "${hyprwhspr}/lib/hyprwhspr" else "/usr/lib/hyprwhspr";
  omarchyThemeState = "${config.home.homeDirectory}/.local/state/omarchy/current";
  omarchyAlacrittyPalette = "${config.home.homeDirectory}/.local/state/omarchy/alacritty.toml";
  alacrittyPalette = ''
    [colors.bright]
    black = "0x5c6370"
    blue = "0x61afef"
    cyan = "0x56b6c2"
    green = "0x98c379"
    magenta = "0xc678dd"
    red = "0xe06c75"
    white = "0xe6efff"
    yellow = "0xd19a66"

    [colors.dim]
    black = "0x1e2127"
    blue = "0x61afef"
    cyan = "0x56b6c2"
    green = "0x98c379"
    magenta = "0xc678dd"
    red = "0xe06c75"
    white = "0x828791"
    yellow = "0xd19a66"

    [colors.normal]
    black = "0x1e2127"
    blue = "0x61afef"
    cyan = "0x56b6c2"
    green = "0x98c379"
    magenta = "0xc678dd"
    red = "0xe06c75"
    white = "0x828791"
    yellow = "0xd19a66"

    [colors.primary]
    background = "0x1e2127"
    bright_foreground = "0xe6efff"
    foreground = "0xabb2bf"

  '';
  alacrittyConfig = ''
    general.import = [ "${omarchyAlacrittyPalette}" ]
    general.live_config_reload = true

  ''
  +
    builtins.replaceStrings
      [
        alacrittyPalette
        ''
          [window]
          decorations = "full"''
      ]
      [
        ""
        ''
          [window]
          decorations = "full"

          [window.padding]
          x = 4
          y = 4''
      ]
      (builtins.readFile "${dotfiles}/alacritty/alacritty.toml");
  alacrittyDir = pkgs.linkFarm "alacritty-config" [
    {
      name = "alacritty.toml";
      path = pkgs.writeText "alacritty.toml" alacrittyConfig;
    }
  ];
  zshInit =
    builtins.replaceStrings
      [ ''source "$HOME/.cargo/env"'' ]
      [ ''[ -r "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"'' ]
      (builtins.readFile "${dotfiles}/zsh/.zshrc");
  fuzzelConfig =
    builtins.replaceStrings
      [
        ''
          [colors]
          background=1E2127DD
          text=E6EFFFFF
          selection=E6EFFFFF
          selection-text=1E2127DD
          selection-match=d19a66FF
          border=1E2127DD
        ''
        "fuzzy=yes"
      ]
      [
        ''
          include=${omarchyThemeState}/theme/fuzzel.ini
        ''
        "match-mode=fuzzy"
      ]
      (builtins.readFile "${dotfiles}/fuzzel/fuzzel.ini");
  kittyPalette = ''
    # Kitty configuration - converted from alacritty.toml
    # One Dark color scheme

    # Colors - Normal (0-7)
    color0 #1e2127
    color1 #e06c75
    color2 #98c379
    color3 #d19a66
    color4 #61afef
    color5 #c678dd
    color6 #56b6c2
    color7 #828791

    # Colors - Bright (8-15)
    color8 #5c6370
    color9 #e06c75
    color10 #98c379
    color11 #d19a66
    color12 #61afef
    color13 #c678dd
    color14 #56b6c2
    color15 #e6efff

    # Primary colors
    foreground #abb2bf
    background #1e2127

  '';
  kittyConfig =
    builtins.replaceStrings
      [ kittyPalette ]
      [
        ''
          include ${omarchyThemeState}/theme/kitty.conf

        ''
      ]
      (builtins.readFile "${dotfiles}/kitty/kitty.conf");
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
    let
      fixedImports = builtins.replaceStrings
        [ "/usr/lib/hyprwhspr" ]
        [ (if isDesktop then hyprwhsprRoot else "") ]
        (builtins.readFile "${dotfiles}/waybar/style.css");
      fixedPalette = builtins.replaceStrings
        [
          ''@define-color black #1e2127;
@define-color blue #61afef;
@define-color green #98c379;
@define-color magenta #c678dd;
@define-color red #e06c75;
@define-color white #828791;
@define-color bright-white #e6efff;
@define-color yellow #d19a66;
''
        ]
        [ "" ]
        fixedImports;
    in
    ''@import url("${omarchyThemeState}/theme/waybar.css");
'' + fixedPalette;
  hyprlandConfig =
    builtins.replaceStrings
      [
        "/usr/lib/hyprwhspr"
        ''hl.env("SSH_AUTH_SOCK", home .. "/.bitwarden-ssh-agent.sock")''
        ''hl.env("QT_QPA_PLATFORMTHEME", "adwaita")''
        ''hl.env("QT_STYLE_OVERRIDE", "adwaita-dark")''
        ''hl.exec_cmd("wayle shell")''
        ''hl.exec_cmd("hyprpaper")''
        ''hl.exec_cmd("hypridle")''
        ''hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")''
        ''	animations = {
		enabled = false,
	},''
        ''		gaps_in = 0,
		gaps_out = 0,''
        ''		border_size = 1,''
        ''hl.animation({ leaf = "workspaces", enabled = true, speed = 1, bezier = "myBezier" })
hl.animation({ leaf = "windows", enabled = true, speed = 1, bezier = "myBezier", style = "popin 60%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1, bezier = "default", style = "popin 90%" })
hl.animation({ leaf = "fade", enabled = true, speed = 1, bezier = "default" })''
        ''hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd('wl-screenrec -g "$(slurp)"'))''
        ''require("monitors")''
        ''		enable_anr_dialog = false,''
        ''-- hyprwhspr - Toggle mode (added by hyprwhspr setup)
-- Press once to start, press again to stop
hl.bind("ALT + G", hl.dsp.exec_cmd("/usr/lib/hyprwhspr/config/hyprland/hyprwhspr-tray.sh record"), {
	description = "Speech-to-text",
})''
      ]
      [
        hyprwhsprRoot
        ''hl.env("SSH_AUTH_SOCK", (os.getenv("XDG_RUNTIME_DIR") or "") .. "/ssh-agent")
hl.env("GNOME_KEYRING_CONTROL", (os.getenv("XDG_RUNTIME_DIR") or "") .. "/keyring")''
        ''hl.env("QT_QPA_PLATFORMTHEME", "gtk")''
        ''hl.env("QT_STYLE_OVERRIDE", "gtk2")''
        ''hl.exec_cmd("gnome-keyring-daemon --start --components=secrets")''
        ''-- Hyprpaper is managed by hyprland-session.target.''
        ''hl.exec_cmd("hypridle")
	hl.exec_cmd("display-control restore")''
        ''hl.exec_cmd("dbus-update-activation-environment --systemd DISPLAY HYPRLAND_INSTANCE_SIGNATURE WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE")
	hl.exec_cmd("systemctl --user start hyprland-session.target")''
        ''	decoration = {
		rounding = 12,
		rounding_power = 4.0,
		shadow = {
			enabled = false,
		},
	},

	animations = {
		enabled = true,
	},''
        ''		gaps_in = 4,
		gaps_out = 4,''
        ''		border_size = 2,''
        ''hl.animation({ leaf = "workspaces", enabled = false })
hl.animation({ leaf = "windows", enabled = true, speed = 3, bezier = "myBezier", style = "popin 85%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 3, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "myBezier", style = "popin 90%" })
hl.animation({ leaf = "fade", enabled = false })''
        ''hl.bind(mainMod .. " + SHIFT + T", hl.dsp.exec_cmd("ocr-screenshot"))''
        (if isDesktop then ''-- Monitor layout is restored by display-control on session startup.'' else ''require("monitors")'')
        (if isDesktop then ''		enable_anr_dialog = false,
		disable_autoreload = true,'' else ''		enable_anr_dialog = false,'')
        ''-- Voxtype replaces the existing Alt+G hyprwhspr action.
hl.bind("ALT + G", hl.dsp.exec_cmd("voxtype record toggle"), {
	description = "Toggle Voxtype dictation",
})''
      ]
      (builtins.readFile "${dotfiles}/hyprland/hyprland.lua")
    + pkgs.lib.optionalString isDesktop ''

      hl.bind("ALT + semicolon", hl.dsp.exec_cmd("qs ipc call barMenu toggle"), {
        description = "Open bar command center",
      })

      hl.bind("SUPER + SHIFT + ALT + M", hl.dsp.exec_cmd("lyre-launch"), {
        description = "Open audio visualizer",
      })

      hl.on("hyprland.shutdown", function()
        os.execute("systemctl --user stop hyprland-session.target && sleep 0.1")
      end)

      -- Home Manager keeps the application configuration declarative; this
      -- small generated file supplies the currently selected Omarchy colors.
      local omarchy_theme = home .. "/.local/state/omarchy/current/theme/hyprland.lua"
      local theme_file = io.open(omarchy_theme, "r")
      if theme_file then
        theme_file:close()
        dofile(omarchy_theme)
      end
    '';
  # Drop the pinned dotfiles theme source and its two legacy accent aliases;
  # the Omarchy adapter below supplies all lock-screen colors directly.
  hyprlockConfig =
    ''source = $HOME/.local/state/omarchy/current/theme/hyprlock.conf
''
    + builtins.concatStringsSep "\n" (
      pkgs.lib.drop 4 (pkgs.lib.splitString "\n" (builtins.readFile "${dotfiles}/hyprland/hyprlock.conf"))
    );
  quickshellConfig = ./quickshell;
  nvimConfig = pkgs.runCommandLocal "nvim-themed-config" { } ''
    cp -r ${dotfiles}/nvim "$out"
    chmod -R u+w "$out"

    substituteInPlace "$out/init.lua" \
      --replace-fail 'vim.cmd.colorscheme("onedark")' \
        '-- The active colorscheme is loaded from Omarchy by lazy.nvim.'
    substituteInPlace "$out/lua/plugins/lualine.lua" \
      --replace-fail 'theme = "onedark",' 'theme = "auto",'
    rm "$out/lua/plugins/onedark.lua"
    cp ${./nvim/lazy.lua} "$out/lua/config/lazy.lua"
    cp ${./nvim/omarchy_theme.lua} "$out/lua/omarchy_theme.lua"
    cp ${./nvim/omarchy-theme.lua} "$out/lua/plugins/omarchy-theme.lua"
  '';
in
{
  # Activate desktop-scoped user services without routing application launches
  # through UWSM. Hyprland starts and stops this target from its Lua lifecycle.
  systemd.user.targets.hyprland-session = pkgs.lib.mkIf isDesktop {
    Unit = {
      Description = "Hyprland compositor session";
      BindsTo = [ "graphical-session.target" ];
      Wants = [ "graphical-session-pre.target" ];
      After = [ "graphical-session-pre.target" ];
      PropagatesStopTo = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.quickshell = pkgs.lib.mkIf isDesktop {
    Unit = {
      Description = "Quickshell desktop shell";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
      X-Restart-Triggers = [ "${./quickshell}" ];
    };

    Service = {
      ExecStartPre = "-${pkgs.quickshell}/bin/quickshell kill";
      ExecStart = "${pkgs.quickshell}/bin/quickshell";
      Restart = "on-failure";
      RestartSec = 1;
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.hyprpaper = pkgs.lib.mkIf isDesktop {
    Unit = {
      Description = "Hyprpaper wallpaper daemon";
      After = [ "graphical-session.target" ];
      PartOf = [ "hyprland-session.target" ];
    };

    Service = {
      ExecStart = "${pkgs.hyprpaper}/bin/hyprpaper";
      Restart = "on-failure";
      RestartSec = 1;
    };

    Install.WantedBy = [ "hyprland-session.target" ];
  };

  xdg.configFile = {
    "aerospace".source = "${dotfiles}/aerospace";
    "aerospace-swipe".source = "${dotfiles}/aerospace-swipe";
    "alacritty".source = alacrittyDir;
    "electron-flags.conf".source = "${dotfiles}/electron/electron-flags.conf";
    "fontconfig/fonts.conf".source = "${dotfiles}/fontconfig/fonts.conf";
    "fuzzel/fuzzel.ini".text = fuzzelConfig;
    "hypr/hypridle.conf".source = "${dotfiles}/hyprland/hypridle.conf";
    "hypr/hyprland.lua".text = hyprlandConfig;
    "hypr/hyprlock.conf".text = hyprlockConfig;
    "hypr/monitors.lua".source = "${dotfiles}/hyprland/monitors.lua";
    "hypr/workspaces.conf".source = "${dotfiles}/hyprland/workspaces.conf";
    "hypr/xdph.conf".source = "${dotfiles}/hyprland/xdph.conf";
    "karabiner".source = "${dotfiles}/karabiner";
    "kdeglobals".source = "${dotfiles}/kde/kdeglobals";
    "kitty/kitty.conf".text = kittyConfig;
    "nvim".source = nvimConfig;
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
    "quickshell".source = quickshellConfig;
    "hypr/hyprpaper.conf".text = ''
      wallpaper {
          monitor =
          path = ${omarchyThemeState}/background
          fit_mode = cover
      }

      splash = false
      ipc = on
    '';
  };

  programs.zsh = {
    dotDir = "${config.xdg.configHome}/zsh";
    envExtra = builtins.readFile "${dotfiles}/zsh/.zshenv";
    initContent = zshInit;
  };
}
