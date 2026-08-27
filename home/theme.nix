{
  config,
  inputs,
  isDesktop ? false,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.omarchy-theme;
  atomOneDark = pkgs.callPackage ../packages/atom-one-dark-theme.nix { };
  cursorName = "breeze_cursors";
  cursorSize = 24;
  omarchyPath = inputs.omarchy;
  themeState = "${config.home.homeDirectory}/.local/state/omarchy/current";
  currentSystemTheme = pkgs.runCommandLocal "omarchy-current-system-theme" { } ''
    mkdir -p "$out/backgrounds"
    cp ${./omarchy-themes/current-system/colors.toml} "$out/colors.toml"
    cp ${./omarchy-themes/current-system/alacritty.toml} "$out/alacritty.toml"
    cp ${./omarchy-themes/current-system/fuzzel.ini} "$out/fuzzel.ini"
    cp ${./omarchy-themes/current-system/hyprland.lua} "$out/hyprland.lua"
    cp ${./omarchy-themes/current-system/kitty.conf} "$out/kitty.conf"
    cp ${./omarchy-themes/current-system/neovim.lua} "$out/neovim.lua"
    cp ${./omarchy-themes/current-system/icons.theme} "$out/icons.theme"
    cp ${./omarchy-themes/current-system/waybar.css} "$out/waybar.css"
    cp ${inputs.onedark-wallpapers}/os/od_nixos.png "$out/backgrounds/0-nixos.png"
    cp ${inputs.onedark-wallpapers}/os/od_nixos.png "$out/preview.png"
  '';

  # Omarchy targets Arch and uses /bin/bash shebangs. Keep the upstream files
  # untouched while making the small, theme-only call graph work on NixOS.
  wrapOmarchy =
    name:
    pkgs.writeShellScriptBin name ''
      exec ${pkgs.bash}/bin/bash ${omarchyPath}/bin/${name} "$@"
    '';
  omarchyHelpers = pkgs.symlinkJoin {
    name = "omarchy-theme-helpers";
    paths = map wrapOmarchy [
      "omarchy-theme-color"
      "omarchy-theme-colors-from-alacritty"
      "omarchy-theme-current"
      "omarchy-theme-list"
      "omarchy-theme-set"
      "omarchy-theme-set-gnome"
      "omarchy-theme-set-templates"
    ];
  };

  themeCli = pkgs.writeShellApplication {
    name = "omarchy-theme";
    runtimeInputs = with pkgs; [
      alacritty
      coreutils
      dconf
      findutils
      gawk
      glib
      gsettings-desktop-schemas
      gnugrep
      gnused
      jq
      libnotify
      neovim
      omarchyHelpers
      procps
      quickshell
      systemd
      util-linux
    ];
    text = ''
            export OMARCHY_PATH=${omarchyPath}
            export GSETTINGS_SCHEMA_DIR=${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas

            current_dir="$HOME/.local/state/omarchy/current"
            mkdir -p "$HOME/.config/omarchy/themes" "$HOME/.config/omarchy/backgrounds"

            theme_catalog() {
              local current dir slug preview candidate label source
              declare -A theme_dirs=()
              declare -A theme_sources=()

              # User themes intentionally win when their slug overlays a stock theme.
              for dir in "$OMARCHY_PATH/themes"/*; do
                [[ -d "$dir" ]] || continue
                slug="''${dir##*/}"
                theme_dirs["$slug"]="$dir"
                theme_sources["$slug"]="stock"
              done
              for dir in "$HOME/.config/omarchy/themes"/*; do
                [[ -d "$dir" ]] || continue
                slug="''${dir##*/}"
                theme_dirs["$slug"]="$dir"
                theme_sources["$slug"]="custom"
              done

              current="$(cat "$current_dir/theme.name" 2>/dev/null || true)"
              {
                while IFS= read -r -d "" slug; do
                  dir="''${theme_dirs[$slug]}"
                  source="''${theme_sources[$slug]}"
                  preview=""
                  for candidate in \
                    "$dir/preview.png" "$dir/preview.jpg" "$dir/preview.jpeg" \
                    "$dir/preview.webp" "$dir/preview.gif" "$dir/preview.bmp"
                  do
                    if [[ -f "$candidate" ]]; then
                      preview="$candidate"
                      break
                    fi
                  done
                  if [[ -z "$preview" ]]; then
                    preview="$(find -L "$dir/backgrounds" -maxdepth 1 -type f \
                      \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
                         -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.webp" \) \
                      -print 2>/dev/null | sort | head -n 1)"
                  fi
                  label="$(printf '%s\n' "$slug" | awk -F- '{ for (i=1; i<=NF; i++) { $i=toupper(substr($i,1,1)) substr($i,2) } } 1')"
                  jq -cn \
                    --arg slug "$slug" \
                    --arg label "$label" \
                    --arg preview "$preview" \
                    --arg source "$source" \
                    --arg current "$current" \
                    '{slug: $slug, label: $label, preview: $preview, source: $source, selected: ($slug == $current)}'
                done < <(printf '%s\0' "''${!theme_dirs[@]}" | sort -z)
              } | jq -s '.'
            }

            render_adapters() {
              local colors="$current_dir/theme/colors.toml"
              local destination key value stripped sed_script
              declare -A palette=()
              [[ -f "$colors" ]] || {
                echo "The selected theme did not produce colors.toml" >&2
                return 1
              }

              while IFS=$'\t' read -r key value; do
                [[ -n "$key" ]] || continue
                palette["$key"]="$value"
              done < <(omarchy-theme-color --file "$colors" --all)

              # Always overwrite these adapters from trusted Home Manager templates.
              # In particular, this prevents a cloned theme from smuggling executable
              # QML or Hyprlock commands through an otherwise color-only integration.
              while read -r template filename; do
                destination="$current_dir/theme/$filename"
                cp --remove-destination "$template" "$destination"
                sed_script="$(mktemp)"
                for key in \
                  accent background bright_foreground dark_background foreground \
                  green lighter_background magenta muted red selection yellow blue
                do
                  value="''${palette[$key]:-}"
                  stripped="''${value#\#}"
                  printf 's|{{ %s }}|%s|g\n' "$key" "$value" >> "$sed_script"
                  printf 's|{{ %s_strip }}|%s|g\n' "$key" "$stripped" >> "$sed_script"
                done
                sed -i -f "$sed_script" "$destination"
                rm -f "$sed_script"
              done <<'EOF'
      ${./omarchy-templates/Theme.qml.tpl} Theme.qml
      ${./omarchy-templates/fuzzel.ini.tpl} fuzzel.ini
      ${./omarchy-templates/hyprlock.conf.tpl} hyprlock.conf
      ${./omarchy-templates/waybar.css.tpl} waybar.css
      EOF

              # This built-in custom theme is trusted, declarative, and preserves
              # the terminal, launcher, and bar palettes that predate the shared table.
              if [[ "$(cat "$current_dir/theme.name" 2>/dev/null || true)" == "current-system" ]]; then
                cp --remove-destination ${./omarchy-themes/current-system/fuzzel.ini} "$current_dir/theme/fuzzel.ini"
                cp --remove-destination ${./omarchy-themes/current-system/waybar.css} "$current_dir/theme/waybar.css"
              fi
            }

            sync_alacritty() {
              local source="$current_dir/theme/alacritty.toml"
              local destination="$HOME/.local/state/omarchy/alacritty.toml"
              local runtime_dir section line socket
              local options=()

              [[ -f "$source" ]] || return 0
              mkdir -p "''${destination%/*}"
              chmod u+w "$destination" 2>/dev/null || true

              # Keep this inode stable: Alacritty watches imported files for
              # changes, while Omarchy atomically replaces the theme directory.
              cp "$source" "$destination"
              chmod u+w "$destination"

              # Existing windows may have started before the stable import was
              # introduced. Push the same palette over Alacritty's IPC socket so
              # they update immediately; newly started windows use the import.
              section=""
              while IFS= read -r line; do
                if [[ "$line" =~ ^\[colors\.([a-zA-Z0-9_.-]+)\]$ ]]; then
                  section="''${BASH_REMATCH[1]}"
                elif [[ "$line" =~ ^\[ ]]; then
                  section=""
                elif [[ -n "$section" && "$line" =~ ^([a-zA-Z0-9_-]+)[[:space:]]*=[[:space:]]*(.+)$ ]]; then
                  options+=("colors.$section.''${BASH_REMATCH[1]}=''${BASH_REMATCH[2]}")
                fi
              done < "$destination"

              (( ''${#options[@]} > 0 )) || return 0
              runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
              while IFS= read -r -d "" socket; do
                alacritty msg -s "$socket" config -w -1 -r >/dev/null 2>&1 || continue
                alacritty msg -s "$socket" config -w -1 "''${options[@]}" >/dev/null 2>&1 || true
              done < <(find "$runtime_dir" -maxdepth 1 -type s -name "Alacritty-*.sock" -print0 2>/dev/null)
            }

            sync_neovim() {
              local marker="$HOME/.local/state/omarchy/neovim-theme"
              local runtime_dir theme_name

              # Let a short-lived instance install a newly selected theme before
              # notifying existing editors. Run this outside the interactive theme
              # path: plugin installation can wait on the network. Serialize jobs
              # and only publish the marker if this is still the selected theme.
              theme_name="$(cat "$current_dir/theme.name" 2>/dev/null || true)"
              [[ -n "$theme_name" ]] || return 0
              runtime_dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
              (
                exec 8>"$runtime_dir/omarchy-theme-neovim.lock"
                flock 8
                timeout 120 nvim --headless +qa >/dev/null 2>&1 || true
                if [[ "$(cat "$current_dir/theme.name" 2>/dev/null || true)" == "$theme_name" ]]; then
                  mkdir -p "''${marker%/*}"
                  printf '%s\n' "$theme_name" > "$marker.next"
                  mv "$marker.next" "$marker"
                fi
              ) >/dev/null 2>&1 &
            }

            refresh_desktop() {
              local background colors_payload theme_name

              # These are best-effort: the same command also works over SSH and
              # during Home Manager activation when no graphical session is running.
              if [[ -n "''${DBUS_SESSION_BUS_ADDRESS:-}" ]]; then
                omarchy-theme-set-gnome || true
                theme_name="$(cat "$current_dir/theme.name" 2>/dev/null || true)"
                if [[ "$theme_name" == "current-system" ]]; then
                  gsettings set org.gnome.desktop.interface gtk-theme "AtomOneDarkTheme" || true
                fi
              fi

              if command -v hyprctl >/dev/null 2>&1 && hyprctl monitors >/dev/null 2>&1; then
                # Evaluate only the theme fragment. A full compositor reload also
                # reapplies monitor rules and can destroy the restored dock layout.
                # Reset optional theme effects first so a theme such as Lumon does
                # not leave its glow or rounding behind after switching away.
                hyprctl eval 'hl.config({ decoration = { rounding = 12, rounding_power = 4.0, shadow = { enabled = false } } })' >/dev/null 2>&1 || true
                hyprctl eval "dofile(\"$current_dir/theme/hyprland.lua\")" >/dev/null 2>&1 || true
                background="$(readlink -f "$current_dir/background" 2>/dev/null || true)"
                if [[ -n "$background" ]]; then
                  systemctl --user start hyprpaper.service >/dev/null 2>&1 || true
                  for _ in {1..20}; do
                    if hyprctl hyprpaper wallpaper ", $background, cover" >/dev/null 2>&1; then
                      break
                    fi
                    sleep 0.05
                  done
                fi
              fi

              if systemctl --user --quiet is-active quickshell.service 2>/dev/null; then
                colors_payload="$(base64 -w 0 "$current_dir/theme/colors.toml" 2>/dev/null || true)"
                if [[ -z "$colors_payload" ]] \
                  || ! timeout 2 quickshell ipc call theme apply "$colors_payload" >/dev/null 2>&1
                then
                  # Retain a recovery path for an old or unhealthy shell instance.
                  systemctl --user restart quickshell.service || true
                fi
              fi

              pkill -SIGUSR1 kitty >/dev/null 2>&1 || true
              pkill -SIGUSR2 btop >/dev/null 2>&1 || true
            }

            set_theme() {
              local requested="''${1:-}"
              local previous_theme previous_background
              [[ -n "$requested" ]] || {
                echo "Usage: omarchy-theme set <theme-name>" >&2
                exit 2
              }

              previous_theme="$(cat "$current_dir/theme.name" 2>/dev/null || true)"
              previous_background="$(readlink "$current_dir/background" 2>/dev/null || true)"

              # Headless skips Omarchy's Arch/Quattro shell integration while still
              # retaining its staging, safety filtering, rendering, and atomically
              # swapped current-theme state.
              # Files copied from a Nix store input retain read-only directory modes;
              # make only the disposable runtime copies writable before replacement.
              chmod -R u+w "$current_dir/theme" "$current_dir/next-theme" 2>/dev/null || true
              OMARCHY_THEME_HEADLESS=1 omarchy-theme-set "$requested"
              chmod -R u+w "$current_dir/theme" 2>/dev/null || true
              if [[ "$(cat "$current_dir/theme.name")" == "$previous_theme" && -f "$previous_background" ]]; then
                ln -nsf "$previous_background" "$current_dir/background"
              fi
              render_adapters
              sync_alacritty
              sync_neovim
              refresh_desktop
            }

            set_background() {
              local background
              background="$(realpath "''${1:-}" 2>/dev/null || true)"
              [[ -f "$background" ]] || {
                echo "Background does not exist: ''${1:-}" >&2
                exit 2
              }
              ln -nsf "$background" "$current_dir/background"
              refresh_desktop
            }

            next_background() {
              local theme_name current index next_index
              local backgrounds=()
              theme_name="$(cat "$current_dir/theme.name" 2>/dev/null || true)"
              mapfile -d "" -t backgrounds < <(
                find -L \
                  "$HOME/.config/omarchy/backgrounds/$theme_name" \
                  "$current_dir/theme/backgrounds" \
                  -maxdepth 1 -type f \
                  \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \
                     -o -iname "*.gif" -o -iname "*.bmp" -o -iname "*.webp" \) \
                  -print0 2>/dev/null | sort -z
              )
              (( ''${#backgrounds[@]} > 0 )) || {
                echo "No backgrounds found for $theme_name" >&2
                exit 1
              }

              current="$(readlink "$current_dir/background" 2>/dev/null || true)"
              index=-1
              for i in "''${!backgrounds[@]}"; do
                if [[ "''${backgrounds[$i]}" == "$current" ]]; then
                  index=$i
                  break
                fi
              done
              next_index=$(( (index + 1) % ''${#backgrounds[@]} ))
              set_background "''${backgrounds[$next_index]}"
            }

            command="''${1:-}"
            shift || true
            case "$command" in
              list)
                omarchy-theme-list
                ;;
              catalog)
                theme_catalog
                ;;
              current)
                omarchy-theme-current
                ;;
              set)
                set_theme "$@"
                ;;
              background)
                case "''${1:-}" in
                  next) next_background ;;
                  set) shift; set_background "$@" ;;
                  *) echo "Usage: omarchy-theme background [next|set <path>]" >&2; exit 2 ;;
                esac
                ;;
              refresh)
                current="$(cat "$current_dir/theme.name" 2>/dev/null || true)"
                [[ -n "$current" ]] || current=${lib.escapeShellArg cfg.defaultTheme}
                set_theme "$current"
                ;;
              *)
                echo "Usage: omarchy-theme [list|catalog|current|set <name>|refresh|background next|background set <path>]"
                [[ -z "$command" ]] || exit 2
                ;;
            esac
    '';
  };
in
{
  options.programs.omarchy-theme = {
    enable = lib.mkEnableOption "Omarchy-compatible user theme switching";

    defaultTheme = lib.mkOption {
      type = lib.types.str;
      default = "tokyo-night";
      description = "Stock Omarchy theme initialized on the first activation.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion =
          cfg.defaultTheme == "current-system"
          || builtins.pathExists "${omarchyPath}/themes/${cfg.defaultTheme}";
        message = "programs.omarchy-theme.defaultTheme '${cfg.defaultTheme}' is not an available built-in theme";
      }
    ];

    home.packages = with pkgs; [
      atomOneDark
      gtk-engine-murrine
      kdePackages.breeze
      kdePackages.breeze-icons
      themeCli
      yaru-theme
    ];

    # Keep the user-scoped CLI ahead of the NixOS profile. This also makes a
    # direct Home Manager activation immediately usable without root.
    home.file."bin/omarchy-theme".source = "${themeCli}/bin/omarchy-theme";

    home.pointerCursor = {
      gtk.enable = true;
      x11.enable = true;
      package = pkgs.kdePackages.breeze;
      name = cursorName;
      size = cursorSize;
    };

    gtk = {
      enable = true;
      colorScheme = "dark";

      # Omarchy switches Adwaita's light/dark variants at runtime. Avoid a
      # fixed third-party GTK theme that would defeat light themes.
      theme = {
        package = null;
        name = "Adwaita-dark";
      };

      iconTheme = {
        package = pkgs.yaru-theme;
        name = "Yaru-blue";
      };

      font = {
        name = "Noto Sans";
        size = 10;
      };

      gtk3.extraConfig = {
        gtk-application-prefer-dark-theme = true;
        gtk-cursor-theme-name = cursorName;
        gtk-cursor-theme-size = cursorSize;
      };

      gtk4.extraConfig = {
        gtk-application-prefer-dark-theme = true;
        gtk-cursor-theme-name = cursorName;
        gtk-cursor-theme-size = cursorSize;
      };

      # Keep libadwaita on its supported color-scheme API. Importing a GTK3
      # theme into GTK4 is both deprecated and visually inconsistent.
      gtk4.theme = null;
    };

    dconf.settings."org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      cursor-theme = cursorName;
      cursor-size = cursorSize;
      gtk-theme = "Adwaita-dark";
      icon-theme = "Yaru-blue";
    };

    qt = {
      enable = true;
      platformTheme.name = "gtk";
      style.name = "gtk2";
    };

    programs.btop = {
      enable = true;
      settings.color_theme = "${themeState}/theme/btop.theme";
    };

    home.sessionVariables = {
      XCURSOR_THEME = cursorName;
      XCURSOR_SIZE = toString cursorSize;
    };

    xdg.configFile = {
      "nwg-look/config".source = "${inputs.dotfiles}/nwg-look/config";
      "omarchy/themes/current-system".source = currentSystemTheme;
      "omarchy/themed/Theme.qml.tpl".source = ./omarchy-templates/Theme.qml.tpl;
      "omarchy/themed/fuzzel.ini.tpl".source = ./omarchy-templates/fuzzel.ini.tpl;
      "omarchy/themed/hyprlock.conf.tpl".source = ./omarchy-templates/hyprlock.conf.tpl;
      "omarchy/themed/waybar.css.tpl".source = ./omarchy-templates/waybar.css.tpl;
    };

    systemd.user.services.quickshell.Service.Environment = lib.mkIf isDesktop [
      "OMARCHY_THEME_BINARY=${themeCli}/bin/omarchy-theme"
    ];

    home.activation.omarchyTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      current="$HOME/.local/state/omarchy/current/theme.name"
      if [[ -s "$current" ]]; then
        selected="$(cat "$current")"
      else
        selected=${lib.escapeShellArg cfg.defaultTheme}
      fi

      if [[ ! -d ${omarchyPath}/themes/"$selected" && ! -d "$HOME/.config/omarchy/themes/$selected" ]]; then
        selected=${lib.escapeShellArg cfg.defaultTheme}
      fi

      OMARCHY_THEME_HEADLESS=1 \
        ${themeCli}/bin/omarchy-theme set "$selected"
    '';
  };
}
