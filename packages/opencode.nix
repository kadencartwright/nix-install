{
  lib,
  stdenv,
  fetchurl,
  glibc,
  makeWrapper,
}:

let
  version = "1.18.27";
  sources = {
    x86_64-linux = {
      suffix = "linux-x64";
      hash = "sha256-SvVJT5Qz9Z24weNEGY8O5ypQwG7ACftKiuq0wtSr1wI=";
    };
    aarch64-linux = {
      suffix = "linux-arm64";
      hash = "sha256-jLwTTrXhALr2HucZYVD1A+NSBW5wMnbi2GN8OLr9LDk=";
    };
  };
  source = sources.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "opencode";
  inherit version;

  src = fetchurl {
    url = "https://github.com/anomalyco/opencode/releases/download/v${version}/opencode-${source.suffix}.tar.gz";
    inherit (source) hash;
  };

  sourceRoot = ".";
  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # Bun standalone executables store application data in an ELF trailer.
    # patchelf rewrites that trailer and makes this binary run as plain Bun,
    # so keep it byte-for-byte intact and invoke it through glibc's loader.
    install -Dm755 opencode "$out/libexec/opencode/opencode"
    makeWrapper ${stdenv.cc.bintools.dynamicLinker} "$out/bin/opencode" \
      --add-flags "--library-path ${lib.makeLibraryPath [ glibc ]}" \
      --add-flags "$out/libexec/opencode/opencode"

    runHook postInstall
  '';

  meta = {
    description = "Open-source AI coding agent";
    homepage = "https://opencode.ai";
    changelog = "https://github.com/anomalyco/opencode/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
    platforms = builtins.attrNames sources;
  };
}
