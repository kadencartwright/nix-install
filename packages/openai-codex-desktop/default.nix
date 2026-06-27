{
  lib,
  stdenv,
  fetchurl,
  electron_39,
  codex,
  python3,
  xdg-utils,
  hicolor-icon-theme,
  libicns,
  libarchive,
  nodejs,
  fetchNpmDeps,
  npmHooks,
  nodePackages,
  makeWrapper,
}:

stdenv.mkDerivation rec {
  pname = "openai-codex-desktop";
  version = "26.602.71036";

  src = ./.;

  codexZip = fetchurl {
    url = "https://persistent.oaistatic.com/codex-app-prod/Codex-darwin-arm64-${version}.zip";
    hash = "sha256-MnhR7/skEf/egw9ErzLDp/eFz8cv0qSfwpM8Qu8LW+U=";
  };

  npmDepsHash = "sha256-GPxj8C4wG5G6beWIWglmWytyIcvpTGnk2PU6rXQxNVI=";
  npmDeps = fetchNpmDeps {
    inherit src;
    hash = npmDepsHash;
  };

  nativeBuildInputs = [
    libarchive
    libicns
    makeWrapper
    nodejs
    nodePackages.asar
    npmHooks.npmConfigHook
    python3
  ];

  buildInputs = [
    hicolor-icon-theme
    xdg-utils
  ];

  npmRebuildFlags = [ "--ignore-scripts" ];

  ELECTRON_SKIP_BINARY_DOWNLOAD = "1";
  npm_config_runtime = "electron";
  npm_config_target = electron_39.version;
  npm_config_nodedir = electron_39.headers;
  npm_config_build_from_source = "true";

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    mkdir dmg
    bsdtar -xf "$codexZip" -C dmg

    appdir="$(find dmg -maxdepth 4 -type d -name '*.app' ! -path '*/__MACOSX/*' | head -n1)"
    test -n "$appdir"

    icon_icns="$(find "$appdir/Contents/Resources" -maxdepth 1 -type f -name '*.icns' ! -name '._*' -print -quit)"
    test -n "$icon_icns"
    mkdir -p icon
    icns2png -x -o icon "$icon_icns"

    asar extract "$appdir/Contents/Resources/app.asar" app-extracted

    if [[ -d "$appdir/Contents/Resources/app.asar.unpacked" ]]; then
      cp -a "$appdir/Contents/Resources/app.asar.unpacked" .
    fi

    rm -rf app-extracted/node_modules/sparkle-darwin
    find app-extracted -type f \( -name '*.dylib' -o -name 'sparkle.node' \) -delete

    node "$src/patch-linux-open-targets.mjs" app-extracted

    bs3_ver="$(node -p "require('./app-extracted/node_modules/better-sqlite3/package.json').version")"
    npty_ver="$(node -p "require('./app-extracted/node_modules/node-pty/package.json').version")"
    test "$bs3_ver" = "12.9.0"
    test "$npty_ver" = "1.1.0"

    export HOME="$TMPDIR/home"
    mkdir -p "$HOME"
    unset nodedir
    export npm_config_runtime=electron
    export npm_config_target="${electron_39.version}"
    export npm_config_disturl="https://electronjs.org/headers"
    export npm_config_nodedir="${electron_39.headers}"
    export npm_config_build_from_source=true

    ./node_modules/.bin/electron-rebuild \
      --version "$npm_config_target" \
      --force

    rm -rf app-extracted/node_modules/better-sqlite3
    rm -rf app-extracted/node_modules/node-pty
    cp -a node_modules/better-sqlite3 app-extracted/node_modules/
    cp -a node_modules/node-pty app-extracted/node_modules/

    strings app-extracted/node_modules/better-sqlite3/build/Release/better_sqlite3.node \
      | grep -q node_register_module_v140

    find app-extracted/node_modules/better-sqlite3 app-extracted/node_modules/node-pty \
      -type f \( -name Makefile -o -name '*.mk' -o -name config.gypi \) -delete
    find app-extracted/node_modules/better-sqlite3 app-extracted/node_modules/node-pty \
      -type d -name .deps -prune -exec rm -rf '{}' +
    for prebuild_root in app-extracted app.asar.unpacked; do
      [[ -d "$prebuild_root" ]] || continue
      find "$prebuild_root" -type d \( -name obj.target -o -name '*.dSYM' \) -prune -exec rm -rf '{}' +
      find "$prebuild_root" -path '*/prebuilds/*' -type f -name '*.node' \
        ! \( -path '*/linux-x64/*' -o -path '*/HID-linux-x64/*' -o -path '*/HID_hidraw-linux-x64/*' \) \
        -delete
      find "$prebuild_root" -path '*/prebuilds/*' -type f -name '*musl*.node' -delete
    done

    asar pack app-extracted app.asar --unpack "{*.node,*.so}"

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm644 app.asar "$out/lib/${pname}/resources/app.asar"

    if [[ -d app.asar.unpacked ]]; then
      cp -a app.asar.unpacked "$out/lib/${pname}/resources/"
    fi

    if [[ -d app-extracted/webview ]]; then
      mkdir -p "$out/lib/${pname}/content"
      cp -a app-extracted/webview "$out/lib/${pname}/content/"
    fi

    install -Dm755 "$src/codex-desktop.sh" "$out/bin/codex-desktop"
    substituteInPlace "$out/bin/codex-desktop" \
      --replace-fail "@out@" "$out" \
      --replace-fail "@electron@" "${electron_39}" \
      --replace-fail "@codex@" "${codex}" \
      --replace-fail "@python@" "${python3}"
    wrapProgram "$out/bin/codex-desktop" \
      --prefix PATH : "${lib.makeBinPath [ xdg-utils ]}"

    icon_png="$(find icon -maxdepth 1 -type f -name '*512x512*.png' -print -quit)"
    if [[ -z "$icon_png" ]]; then
      icon_png="$(find icon -maxdepth 1 -type f -name '*.png' -print | sort -V | tail -n1)"
    fi
    test -n "$icon_png"
    install -Dm644 "$icon_png" "$out/share/icons/hicolor/512x512/apps/openai-codex-desktop.png"
    install -Dm644 "$src/Codex.desktop" "$out/share/applications/Codex.desktop"

    runHook postInstall
  '';

  meta = {
    description = "OpenAI Codex desktop app packaged from the macOS Electron bundle";
    homepage = "https://developers.openai.com/codex/app/";
    license = lib.licenses.unfree;
    mainProgram = "codex-desktop";
    platforms = [ "x86_64-linux" ];
  };
}
