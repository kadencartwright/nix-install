{
  lib,
  buildNpmPackage,
  fetchurl,
  importNpmLock,
  makeWrapper,
  nodejs_22,
  stdenv,
  glibc,
  patchelf,
  codex,
}:

let
  packageJson = lib.importJSON ./package.json;
  packageJsonForNpm = builtins.removeAttrs packageJson [ "overrides" ];
  packageLockJson = lib.importJSON ./package-lock.json;
in
buildNpmPackage rec {
  pname = "t3-cli";
  version = "0.1.6";
  nodejs = nodejs_22;

  src = fetchurl {
    url = "https://registry.npmjs.org/t3/-/t3-${version}.tgz";
    hash = "sha512-Gxiu4vniyTDKcXlyzA8yRQ7/xDB7DXork97rFbX66NXH7NGV8NJPBZi0/+tEMS8KmkUK4rVmPH9zMFKiWe30mg==";
  };
  sourceRoot = "package";

  # Since 0.1.2 npm only ships a downloader; pin its runtime at build time.
  runtime = fetchurl {
    url = "https://github.com/pingdotgg/t3code/releases/download/v${version}/t3-${version}-linux-x64.tar.gz";
    hash = "sha256-fPMdqQ3uQfUk3VtnnrttQEY3yl2dxv2LwBlRHVe7d+Y=";
  };

  npmDeps = importNpmLock {
    package = packageJsonForNpm;
    packageLock = packageLockJson;
  };

  npmConfigHook = importNpmLock.npmConfigHook;
  nativeBuildInputs = [
    makeWrapper
    patchelf
  ];
  dontNpmBuild = true;
  npmFlags = [ "--ignore-scripts" ];
  # Preserve the bundled Node executable and its native modules.
  dontStrip = true;

  postPatch = ''
    cp ${./package.json} package.json
    cp ${./package-lock.json} package-lock.json

    node -e '
      const fs = require("fs");
      const pkg = JSON.parse(fs.readFileSync("package.json", "utf8"));
      delete pkg.overrides;
      fs.writeFileSync("package.json", JSON.stringify(pkg, null, 2) + "\n");
    '

    if [ ! -f dist/bin.mjs ]; then
      echo "missing CLI entrypoint: dist/bin.mjs" >&2
      exit 1
    fi
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/lib/node_modules/t3" "$out/bin"
    cp -r . "$out/lib/node_modules/t3"

    platform_dir="$out/lib/t3-runtime"
    mkdir -p "$platform_dir"
    tar -xzf ${runtime} -C "$platform_dir" --strip-components=1
    printf '%s\n' '${version}' > "$platform_dir/.install-complete"
    substituteInPlace "$out/lib/node_modules/t3/bin/t3.mjs" \
      --replace-fail 'path.join(t3Home(), "runtime", "versions", version)' \
        "\"$platform_dir\""
    # Node resolves bundled modules relative to its executable, so patch the
    # interpreter directly instead of invoking the executable through a loader.
    patchelf \
      --set-interpreter ${stdenv.cc.bintools.dynamicLinker} \
      --set-rpath "${
        lib.makeLibraryPath [
          glibc
          stdenv.cc.cc.lib
        ]
      }" \
      "$platform_dir/t3"

    makeWrapper ${nodejs_22}/bin/node "$out/bin/t3" \
      --add-flags "$out/lib/node_modules/t3/dist/bin.mjs" \
      --prefix PATH : "${lib.makeBinPath [ codex ]}"

    runHook postInstall
  '';

  meta = {
    description = "T3 Code CLI";
    homepage = "https://github.com/pingdotgg/t3code";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
    license = lib.licenses.mit;
    mainProgram = "t3";
    platforms = [ "x86_64-linux" ];
  };
}
