{
  lib,
  stdenv,
  fetchurl,
  glibc,
  makeWrapper,
}:

let
  # V2 native binaries are published to npm under @opencode/cli-*.
  version = "2.0.25";
  sources = {
    x86_64-linux = {
      suffix = "linux-x64";
      hash = "sha512-GlqAQ1w5K+MHJ32oVl7Yxg5pE+NyZS2cjpuzGbk4LAmhDrqHbv9JVhwLCLKoPMASdWnHkzpj0W5hs8avYW4NVA==";
    };
    aarch64-linux = {
      suffix = "linux-arm64";
      hash = "sha512-7dSVZxTQR2HGPJfqDkq3ADxHhoXjS1FXxFLYj29nWllut7GjfdGi4AQQlfjQeFeqmO3r0FvQh3okdCYBL5SUSw==";
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
