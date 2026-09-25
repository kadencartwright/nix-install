{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "opencode-desktop";
  version = "2.0.16";
  src = fetchurl {
    url = "https://opencode.ai/files/bin/${version}/opencode-desktop-linux-x86_64.AppImage";
    hash = "sha256-V9dmMdYEXaTRAcpSGggNnKXR4o534b9NemimFU+o2eI=";
  };
  appimageContents = appimageTools.extract {
    inherit pname version src;
  };
in
appimageTools.wrapType2 {
  inherit pname version src;

  extraInstallCommands = ''
    mkdir -p "$out/share"

    if [ -d ${appimageContents}/usr/share ]; then
      cp -r ${appimageContents}/usr/share/* "$out/share/"
    fi

    # ai.opencode.desktop is the executable; the launcher has two suffixes.
    desktop_file="$out/share/applications/ai.opencode.desktop.desktop"
    install -Dm644 ${appimageContents}/ai.opencode.desktop.desktop "$desktop_file"
    sed -i \
      -e 's|^Exec=[^ ]*|Exec=${pname}|' \
      -e 's|^TryExec=.*|TryExec=${pname}|' \
      "$desktop_file"

    if [ -f ${appimageContents}/.DirIcon ]; then
      install -Dm444 ${appimageContents}/.DirIcon "$out/share/pixmaps/${pname}.png"
    fi
  '';

  meta = {
    description = "OpenCode desktop app";
    homepage = "https://opencode.ai";
    changelog = "https://github.com/anomalyco/opencode/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = pname;
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
