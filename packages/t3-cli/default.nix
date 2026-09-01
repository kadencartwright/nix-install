{
  lib,
  buildNpmPackage,
  fetchurl,
  importNpmLock,
  makeWrapper,
  nodejs_22,
  codex,
}:

let
  packageJson = lib.importJSON ./package.json;
  packageJsonForNpm = builtins.removeAttrs packageJson [ "overrides" ];
  packageLockJson = lib.importJSON ./package-lock.json;
in
buildNpmPackage rec {
  pname = "t3-cli";
  version = "0.0.37";
  nodejs = nodejs_22;

  src = fetchurl {
    url = "https://registry.npmjs.org/t3/-/t3-${version}.tgz";
    hash = "sha512-/uSSgJGs/t9r8D5T54sdcFssSOauM5FxwUMUOFATe5N2OD64S594VMtIG7Phbfrllmr8adxBOVrFtD4+VegqCQ==";
  };
  sourceRoot = "package";

  npmDeps = importNpmLock {
    package = packageJsonForNpm;
    packageLock = packageLockJson;
    fetcherOpts = {
      "node_modules/@effect/platform-node".name = "platform-node.tgz";
      "node_modules/@effect/platform-node-shared".name = "platform-node-shared.tgz";
      "node_modules/@effect/sql-sqlite-bun".name = "sql-sqlite-bun.tgz";
      "node_modules/effect".name = "effect.tgz";
    };
  };

  npmConfigHook = importNpmLock.npmConfigHook;
  nativeBuildInputs = [ makeWrapper ];
  dontNpmBuild = true;

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
