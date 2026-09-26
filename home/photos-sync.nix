{
  config,
  isDesktop ? false,
  lib,
  osConfig,
  pkgs,
  ...
}:

let
  source = "${config.home.homeDirectory}/Photos";
  configFile = "${config.xdg.configHome}/rclone/rclone.conf";
  stateDir = "${config.xdg.stateHome}/photos-sync";
  historyDir = "${config.xdg.dataHome}/photos-sync-history";
  destination = "photos-drive:Photos";
  remoteHistory = "photos-drive:Photos-history/${osConfig.networking.hostName}";
  watcherPython = pkgs.python3.withPackages (ps: [ ps.watchdog ]);
  sync = pkgs.writeShellApplication {
    name = "photos-sync";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.rclone
      pkgs.util-linux
    ];
    text = ''
      umask 077
      mode="''${1:-run}"
      case "$mode" in
        preview|init|run) ;;
        *) echo 'Usage: photos-sync [preview|init|run]' >&2; exit 2 ;;
      esac

      source_dir=${lib.escapeShellArg source}
      state_dir=${lib.escapeShellArg stateDir}
      history_dir=${lib.escapeShellArg historyDir}
      destination=${lib.escapeShellArg destination}
      remote_history=${lib.escapeShellArg remoteHistory}
      export RCLONE_CONFIG=${lib.escapeShellArg configFile}

      [[ -f "$RCLONE_CONFIG" ]] || { echo 'Create the photos-drive remote with rclone config first.' >&2; exit 1; }
      [[ -d "$source_dir" ]] || { echo 'Create ~/Photos before initializing sync.' >&2; exit 1; }
      mkdir -p "$state_dir"
      exec 9>"$state_dir/run.lock"
      if [[ "$mode" == run ]]; then
        # Local events and the remote timer have separate systemd jobs. Wait
        # here so a local event always gets a run after an in-progress poll.
        flock 9
      else
        flock -n 9 || { echo 'Photo sync is already running.' >&2; exit 1; }
      fi

      timestamp="$(date -u +%Y-%m-%dT%H-%M-%S-%NZ)"
      args=(
        --workdir "$state_dir/bisync"
        --backup-dir1 "$history_dir/$timestamp"
        --backup-dir2 "$remote_history/remote/$timestamp"
        --conflict-resolve none --conflict-loser num
        --resilient --recover --max-lock 2m
        --max-delete 25 --log-level INFO
      )

      case "$mode" in
        preview)
          # Preview the initial union without changing either photo library.
          exec rclone bisync "$source_dir" "$destination" "''${args[@]}" \
            --resync-mode newer --dry-run
          ;;
        init)
          # Initialization is explicit: never automatically resync after errors.
          rm -f "$state_dir/initialized"
          rclone mkdir "$destination"
          printf 'Photo sync access check\n' > "$source_dir/.photos-sync-check"
          rclone copyto "$source_dir/.photos-sync-check" "$destination/.photos-sync-check"
          args+=(--resync-mode newer)
          ;;
        run)
          [[ -f "$state_dir/initialized" ]] || { echo 'Run photos-sync preview, then photos-sync init first.' >&2; exit 1; }
          ;;
      esac

      rclone bisync "$source_dir" "$destination" "''${args[@]}" \
        --check-access --check-filename .photos-sync-check

      # Path1 history must be local for bisync. Copy it to Drive as well,
      # including any history awaiting upload after a previous interruption.
      if [[ -d "$history_dir" ]]; then
        rclone copy "$history_dir" "$remote_history/local" --log-level INFO
      fi
      if [[ "$mode" == init ]]; then
        touch "$state_dir/initialized"
      fi
    '';
  };
  syncService = {
    Unit = {
      Description = "Sync ~/Photos with the shared Google Drive library";
      ConditionPathIsDirectory = source;
      ConditionPathExists = [
        configFile
        "${stateDir}/initialized"
      ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${sync}/bin/photos-sync run";
      TimeoutStartSec = "infinity";
      KillSignal = "SIGINT";
      TimeoutStopSec = "2min";
      UMask = "0077";
    };
  };
in
{
  config = lib.mkIf isDesktop {
    home.packages = [ sync ];

    systemd.user.services.photos-sync = syncService;
    systemd.user.services.photos-sync-local = syncService;

    systemd.user.timers.photos-sync = {
      Unit.Description = "Check Google Drive for photo changes every minute";
      Timer = {
        OnCalendar = "minutely";
        Persistent = true;
        AccuracySec = "1s";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    systemd.user.services.photos-sync-watch = {
      Unit = {
        Description = "Watch local photo changes and trigger sync";
        ConditionPathIsDirectory = source;
      };
      Service = {
        ExecStart = lib.escapeShellArgs [
          "${watcherPython}/bin/python3"
          "${./photos-sync-watch.py}"
          source
          "${pkgs.systemd}/bin/systemctl"
        ];
        Restart = "on-failure";
        RestartSec = "3s";
      };
      Install.WantedBy = [ "default.target" ];
    };

    systemd.user.paths.photos-sync-watch = {
      Unit.Description = "Start photo watcher when ~/Photos exists";
      Path.PathExists = source;
      Install.WantedBy = [ "default.target" ];
    };
  };
}
