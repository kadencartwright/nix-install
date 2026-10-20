{ pkgs }:
pkgs.writeShellApplication {
  name = "screen-record";
  runtimeInputs = [ pkgs.python3 pkgs.wf-recorder pkgs.ffmpeg pkgs.pulseaudio pkgs.xdg-user-dirs ];
  text = ''
    exec python3 ${./screen-record.py} "$@"
  '';
}
