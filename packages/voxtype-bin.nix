{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  alsa-lib,
  libnotify,
  pulseaudio,
  which,
  wl-clipboard,
  wtype,
  dotool,
  xclip,
  xdotool,
}:

let
  version = "1.3.1";
  fetchBinary =
    variant: hash:
    fetchurl {
      url = "https://github.com/peteonrails/voxtype/releases/download/v${version}/voxtype-${version}-linux-x86_64-${variant}";
      inherit hash;
    };
  daemon = fetchBinary "onnx-avx2" "sha256-W3caGMHXav4gjquMbhGPhYYA5uE33ioQ12MOeBpqD/o=";
  audioBridge = fetchBinary "audio-bridge" "sha256-ywv5k6crx9CM6+vBDPFDYCVF+ZJaDNra2UCIjZyv/xo=";
  osd = fetchBinary "osd" "sha256-07luPvkUUr8Y1M7hIFdKGqpEcwctjBZba2a4OXk5/EY=";
  osdQuickshell = fetchBinary "osd-quickshell" "sha256-2gIgDBt+kaFC5aRs9tL515wNb2BZThi078TaRB7B5Bo=";
in
stdenv.mkDerivation {
  pname = "voxtype-bin";
  inherit version;
  dontUnpack = true;
  dontBuild = true;
  dontStrip = true;

  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  buildInputs = [ stdenv.cc.cc.lib alsa-lib ];

  # Upstream's ONNX/AVX2 release statically includes ONNX Runtime. No local
  # Rust, Whisper/Vulkan, or ONNX Runtime compilation is needed.
  installPhase = ''
    runHook preInstall
    install -Dm755 ${daemon} "$out/bin/voxtype"
    install -Dm755 ${audioBridge} "$out/bin/voxtype-audio-bridge"
    install -Dm755 ${osd} "$out/bin/voxtype-osd"
    install -Dm755 ${osdQuickshell} "$out/bin/voxtype-osd-quickshell"
    runHook postInstall
  '';

  postFixup = ''
    wrapProgram "$out/bin/voxtype" \
      --prefix PATH : "$out/bin:${lib.makeBinPath [ libnotify pulseaudio which wl-clipboard wtype dotool xclip xdotool ]}"
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    "$out/bin/voxtype" --version
    "$out/bin/voxtype-audio-bridge" --version
    "$out/bin/voxtype-osd" --version
    "$out/bin/voxtype-osd-quickshell" --version
    runHook postInstallCheck
  '';

  meta = {
    description = "Prebuilt Voxtype with ONNX/Parakeet support (AVX2 required)";
    homepage = "https://github.com/peteonrails/voxtype";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "voxtype";
  };
}
