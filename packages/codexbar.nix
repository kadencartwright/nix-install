{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  makeWrapper,
  bash,
  coreutils,
  curl,
  jq,
  gnused,
}:

stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "codexbar";
  version = "0.6.1";

  src = fetchFromGitHub {
    owner = "mryll";
    repo = "codexbar";
    rev = "v${finalAttrs.version}";
    hash = "sha256-wZhSYrDoLCQQvxXz9NIsp8n1+YIXlGZNGfBwvZEIAZk=";
  };

  nativeBuildInputs = [
    bash
    makeWrapper
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    install -Dm755 codexbar "$out/bin/codexbar"
    patchShebangs "$out/bin/codexbar"
    wrapProgram "$out/bin/codexbar" \
      --prefix PATH : ${lib.makeBinPath [
        coreutils
        curl
        jq
        gnused
      ]}

    runHook postInstall
  '';

  meta = {
    description = "Waybar-compatible OpenAI Codex usage widget";
    homepage = "https://github.com/mryll/codexbar";
    license = lib.licenses.mit;
    mainProgram = "codexbar";
    platforms = lib.platforms.linux;
  };
})
