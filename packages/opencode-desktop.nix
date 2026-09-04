{
  lib,
  appimageTools,
  fetchurl,
}:

let
  pname = "opencode-desktop";
  version = "1.18.27";
  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-desktop-linux-x86_64.AppImage";
    hash = "sha256-YK9gaa81xiNkD4Qm/t8RXTkOw8sKuH9Ayecr3NDyOwM=";
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

    desktop_file="$(find "$out/share" -type f -name '*.desktop' | head -n 1 || true)"
    if [ -z "$desktop_file" ]; then
      desktop_source="$(find ${appimageContents} -maxdepth 2 -type f -name '*.desktop' | head -n 1 || true)"
      if [ -n "$desktop_source" ]; then
        desktop_file="$out/share/applications/$(basename "$desktop_source")"
        install -Dm444 "$desktop_source" "$desktop_file"
      fi
    fi

    if [ -n "$desktop_file" ]; then
      sed -i \
        -e 's|Exec=AppRun|Exec=${pname}|g' \
        -e 's|TryExec=AppRun|TryExec=${pname}|g' \
        "$desktop_file"
    fi

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
