{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  bubblewrap,
  ripgrep,
}:

let
  system = stdenvNoCC.hostPlatform.system;
  arch =
    if stdenvNoCC.hostPlatform.isx86_64 then
      "x86_64"
    else if stdenvNoCC.hostPlatform.isAarch64 then
      "aarch64"
    else
      throw "codex: unsupported platform ${system}";
  hashes = {
    x86_64-linux = {
      codex = "sha256-NSwk+9xa76/96cHfmRtTS2vHKgbklwh5T8aF/DVWyFU=";
      codeModeHost = "sha256-RJzv41ufNH4/2/Eh6BYzmzeCXrC/7n3oKYoKYbZofLo=";
    };
    aarch64-linux = {
      codex = "sha256-r5d3qNYu3uoxrf7LqipbKWvFekoMPtacAuOcI3RPX+s=";
      codeModeHost = "sha256-E0GDx/W7IkXtS7Fc/PANGmSVCtvdCJ0zwAPIvPEyZ+k=";
    };
  };
in
stdenvNoCC.mkDerivation rec {
  pname = "codex";
  version = "0.152.0";

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-${arch}-unknown-linux-musl.tar.gz";
    hash = hashes.${system}.codex;
  };

  codeModeHost = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-code-mode-host-${arch}-unknown-linux-musl.tar.gz";
    hash = hashes.${system}.codeModeHost;
  };

  sourceRoot = ".";
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/codex "$out/bin/codex"
    tar -xzf "$codeModeHost"
    install -Dm755 codex-code-mode-host-${arch}-unknown-linux-musl "$out/bin/codex-code-mode-host"
    wrapProgram "$out/bin/codex" \
      --prefix PATH : "${
        lib.makeBinPath [
          bubblewrap
          ripgrep
        ]
      }"

    runHook postInstall
  '';

  meta = {
    description = "OpenAI Codex CLI";
    homepage = "https://developers.openai.com/codex/cli/";
    changelog = "https://github.com/openai/codex/releases/tag/rust-v${version}";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
