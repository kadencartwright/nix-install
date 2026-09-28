{
  lib,
  stdenv,
  fetchurl,
  glibc,
  makeWrapper,
}:

let
  # V2 native binaries are published to npm under @opencode/cli-*.
  version = "2.0.18";
  sources = {
    x86_64-linux = {
      suffix = "linux-x64";
      hash = "sha512-94dH7lwB+tpmzI1/NIfzFxLBIeshZSNtyx2sskL0C0kgYjMaiVMIHvQLYIECUOWSuVz5/dH/KPUIOGn7ML311g==";
    };
    aarch64-linux = {
      suffix = "linux-arm64";
      hash = "sha512-OjKG0staG+KRG9sNORb2vIPcfthMVk9RtCamU1vMWPquV70bQEYUM0JUT+t0A49eAc2H4lZWhqkpH2gpg87D+Q==";
    };
  };
  source = sources.${stdenv.hostPlatform.system};
in
stdenv.mkDerivation {
  pname = "opencode";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode/cli-${source.suffix}/-/cli-${source.suffix}-${version}.tgz";
    inherit (source) hash;
  };

  sourceRoot = "package";
  nativeBuildInputs = [ makeWrapper ];
  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    # Bun standalone executables store application data in an ELF trailer.
    # patchelf rewrites that trailer and makes this binary run as plain Bun,
    # so keep it byte-for-byte intact and invoke it through glibc's loader.
    install -Dm755 bin/opencode "$out/libexec/opencode/opencode"
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
