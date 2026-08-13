{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  python3,
  binutils,
  bash,
  cmake,
  coreutils,
  curl,
  findutils,
  gawk,
  gcc,
  git,
  gnugrep,
  gnused,
  gnumake,
  pkg-config,
  procps,
  systemd,
  wl-clipboard,
  wtype,
  ydotool,
  xclip,
  xdotool,
  xprop,
  pipewire,
  pulseaudio,
  alsa-utils,
  libnotify,
  glib,
  util-linux,
  pciutils,
  gtk4,
  gtk4-layer-shell,
  shaderc,
  vulkan-headers,
  vulkan-loader,
  vulkan-tools,
}:

let
  pythonEnv = python3.withPackages (ps: [
    ps."dbus-python"
    ps.evdev
    ps.numpy
    ps.pycairo
    ps.pygobject3
    ps.pyperclip
    ps.pyudev
    ps.pulsectl
    ps.requests
    ps.rich
    ps.sounddevice
    ps.soxr
  ]);

  runtimePath = lib.makeBinPath [
    pythonEnv
    binutils
    bash
    cmake
    coreutils
    curl
    findutils
    gawk
    gcc
    git
    gnugrep
    gnused
    gnumake
    pkg-config
    procps
    systemd
    wl-clipboard
    wtype
    ydotool
    xclip
    xdotool
    xprop
    pipewire
    pulseaudio
    alsa-utils
    libnotify
    glib
    util-linux
    pciutils
    shaderc
    vulkan-tools
  ];

  vulkanPackages = [
    shaderc
    vulkan-headers
    vulkan-loader
  ];
in
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "hyprwhspr";
  version = "1.41.0";

  src = fetchurl {
    url = "https://github.com/goodroot/hyprwhspr/archive/refs/tags/v${finalAttrs.version}.tar.gz";
    hash = "sha256-w64ddT8Cmt4AFAiTfcXS6Q3IJgnf8hZ7fsE67SNEoEc=";
  };

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    packageRoot="$out/lib/hyprwhspr"
    mkdir -p "$packageRoot" "$out/bin" "$out/lib/systemd/user"
    cp -r lib bin config share README.md LICENSE requirements*.txt "$packageRoot"

    # The upstream launchers intentionally avoid version-manager Python
    # installations. Add this package's Python environment to that clean search.
    substituteInPlace \
      "$packageRoot/bin/hyprwhspr" \
      "$packageRoot/config/hyprland/hyprwhspr-tray.sh" \
      --replace-fail \
        '/usr/bin:/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/sbin' \
        '${pythonEnv}/bin:/usr/bin:/bin:/usr/local/bin:/usr/local/sbin:/usr/sbin:/sbin'

    # ydotool 1.x does not expose its version on the command line. Upstream
    # otherwise assumes it is 0.1.x when no distro package manager is present.
    substituteInPlace "$packageRoot/lib/src/cli/_shared.py" \
      --replace-fail \
        'version = "0.1.0"' \
        'version = os.environ.get("HYPRWHSPR_YDOTOOL_VERSION", "0.1.0")'

    substituteInPlace "$packageRoot/lib/src/backend_installer.py" \
      --replace-fail \
        "'/usr/include/vulkan/vulkan.h'," \
        "'${vulkan-headers}/include/vulkan/vulkan.h', '/usr/include/vulkan/vulkan.h',"

    substituteInPlace "$packageRoot/lib/cli.py" \
      --replace-fail \
        "return 'unknown'" \
        "return 'v${finalAttrs.version}'"

    # Make the service copied by `hyprwhspr setup` valid on NixOS.
    substituteInPlace "$packageRoot/config/systemd/hyprwhspr.service" \
      --replace-fail '/bin/bash' '${bash}/bin/bash' \
      --replace-fail '/usr/lib/hyprwhspr' "$packageRoot"

    # Upstream probes FHS library paths when enabling its GTK layer-shell OSD.
    substituteInPlace "$packageRoot/lib/mic_osd/runner.py" \
      --replace-fail \
        "for pattern in [" \
        "for pattern in ['${gtk4-layer-shell}/lib/libgtk4-layer-shell.so*',"

    patchShebangs "$packageRoot"

    wrapProgram "$packageRoot/bin/hyprwhspr" \
      --set HYPRWHSPR_ROOT "$packageRoot" \
      --set HYPRWHSPR_YDOTOOL_VERSION '${ydotool.version}' \
      --prefix PATH : '${runtimePath}' \
      --prefix PYTHONPATH : '${pythonEnv}/${python3.sitePackages}' \
      --prefix GI_TYPELIB_PATH : '${gtk4}/lib/girepository-1.0:${gtk4-layer-shell}/lib/girepository-1.0' \
      --prefix LD_LIBRARY_PATH : '${lib.makeLibraryPath [ gtk4 gtk4-layer-shell ]}' \
      --prefix XDG_DATA_DIRS : '${gtk4}/share' \
      --prefix CMAKE_PREFIX_PATH : '${lib.makeSearchPath "lib/cmake" vulkanPackages}' \
      --prefix CPATH : '${lib.makeSearchPath "include" vulkanPackages}' \
      --prefix LIBRARY_PATH : '${lib.makeLibraryPath vulkanPackages}' \
      --prefix PKG_CONFIG_PATH : '${lib.makeSearchPath "lib/pkgconfig" vulkanPackages}'

    wrapProgram "$packageRoot/config/hyprland/hyprwhspr-tray.sh" \
      --set HYPRWHSPR_ROOT "$packageRoot" \
      --prefix PATH : '${runtimePath}'

    wrapProgram "$packageRoot/bin/meeting-recorder" \
      --set HYPRWHSPR_ROOT "$packageRoot" \
      --prefix PATH : '${runtimePath}' \
      --prefix PYTHONPATH : '${pythonEnv}/${python3.sitePackages}'

    ln -s "$packageRoot/bin/hyprwhspr" "$out/bin/hyprwhspr"
    ln -s "$packageRoot/bin/meeting-recorder" "$out/bin/meeting-recorder"
    ln -s "$packageRoot/config/systemd/hyprwhspr.service" "$out/lib/systemd/user/hyprwhspr.service"

    ${python3.interpreter} scripts/validate-package-payload.py "$packageRoot"

    runHook postInstall
  '';

  meta = {
    description = "Native system-wide speech-to-text for Linux";
    homepage = "https://github.com/goodroot/hyprwhspr";
    license = lib.licenses.mit;
    mainProgram = "hyprwhspr";
    platforms = [ "x86_64-linux" ];
  };
})
