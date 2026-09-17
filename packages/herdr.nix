{
  lib,
  stdenvNoCC,
  fetchurl,
}:

let
  sources = {
    x86_64-linux = {
      arch = "x86_64";
      hash = "sha256-KgL+0WvrZR7wBuHUPwSPZSyk3FitBTzS1ERQVj1cVLc=";
    };
    aarch64-linux = {
      arch = "aarch64";
      hash = "sha256-9Mz03nRfLLmjmpg+m6NwPa1Q7CpY3qgwJs6rchu9jZ4=";
    };
  };
  source = sources.${stdenvNoCC.hostPlatform.system};
in
stdenvNoCC.mkDerivation rec {
  pname = "herdr";
  version = "0.9.1";

  src = fetchurl {
    url = "https://github.com/herdrdev/herdr/releases/download/v${version}/herdr-linux-${source.arch}";
    inherit (source) hash;
  };

  # Upstream Linux releases are standalone musl binaries.
  dontUnpack = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/herdr"
    runHook postInstall
  '';

  meta = {
    description = "Terminal workspace manager for AI coding agents";
    homepage = "https://herdr.dev";
    changelog = "https://github.com/herdrdev/herdr/releases/tag/v${version}";
    license = lib.licenses.asl20;
    mainProgram = "herdr";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = builtins.attrNames sources;
  };
}
