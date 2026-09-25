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
      codex = "sha256-BC+FHqP8EIPEUVdSBSCUT8eQYytT68WA/JjqylWGKiU=";
    };
    aarch64-linux = {
      codex = "sha256-wcNr6rC09yd5rfU7qenklL98v75PNQagj/Z6JPXwDQg=";
    };
  };
in
stdenvNoCC.mkDerivation rec {
  pname = "codex";
  version = "0.157.0";

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-${arch}-unknown-linux-musl.tar.gz";
    hash = hashes.${system}.codex;
  };

  sourceRoot = ".";
  nativeBuildInputs = [ makeWrapper ];
  dontStrip = true;
  dontPatchELF = true;

  installPhase = ''
    runHook preInstall

    # Daemon bootstrap validates and copies this complete package. Keep its
    # entrypoint unwrapped so the copied binary matches the running executable.
    mkdir -p "$out/lib/codex" "$out/bin"
    cp -a bin codex-package.json codex-path codex-resources "$out/lib/codex/"
    ln -s "$out/lib/codex/bin/codex-code-mode-host" "$out/bin/codex-code-mode-host"
    makeWrapper "$out/lib/codex/bin/codex" "$out/bin/codex" \
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
