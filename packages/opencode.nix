{
  lib,
  stdenv,
  fetchurl,
  glibc,
  makeWrapper,
}:

let
  # V2 native binaries are published to npm under @opencode/cli-*.
  version = "2.0.16";
  sources = {
    x86_64-linux = {
      suffix = "linux-x64";
      hash = "sha512-BVmvVddA7c4VhSXgTiGtZB9pU+xTyFgsd56KkvQoYMydqy8xfzPGu9BRwQVCG/RTxGhRAwda/MYEWarddscIUg==";
    };
    aarch64-linux = {
      suffix = "linux-arm64";
      hash = "sha512-BThpExec9wEIhC4U9iRY/jWecM8bVOVuYw2YTYYZ/qNn2r/RljDG2flngDmCZFM1cC6miu2kqOgPkVnVeqaapQ==";
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
