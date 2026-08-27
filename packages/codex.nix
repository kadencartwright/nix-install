{
  lib,
  stdenvNoCC,
  fetchurl,
  makeWrapper,
  bubblewrap,
  ripgrep,
}:

stdenvNoCC.mkDerivation rec {
  pname = "codex";
  version = "0.150.1";

  src = fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-package-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-AKunBPAp9twNlIvkB6dW4Ml8yEATL9aRNTssawpQWxc=";
  };

  sourceRoot = ".";
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall

    install -Dm755 bin/codex "$out/bin/codex"
    wrapProgram "$out/bin/codex" \
      --prefix PATH : "${lib.makeBinPath [ bubblewrap ripgrep ]}"

    runHook postInstall
  '';

  meta = {
    description = "OpenAI Codex CLI";
    homepage = "https://developers.openai.com/codex/cli/";
    changelog = "https://github.com/openai/codex/releases/tag/rust-v${version}";
    license = lib.licenses.asl20;
    mainProgram = "codex";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
}
