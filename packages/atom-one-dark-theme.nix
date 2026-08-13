{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

let
  gtkTheme = fetchFromGitHub {
    owner = "UnnatShaneshwar";
    repo = "AtomOneDarkTheme";
    rev = "cba35c4e5a77eaf3cebc5306fce4dd8bc4415d43";
    hash = "sha256-JbE9uVtlIIb0ei/XuZ2/Ccl3W2SyTYYLZgkbaXf9P2A=";
  };
  iconTheme = fetchFromGitHub {
    owner = "UnnatShaneshwar";
    repo = "AtomOneDarkIcons";
    rev = "949306345aebad680495f93e385f6716ef1415a2";
    hash = "sha256-c4UQf8VkKji/oaC9+6DZ9NnWcbN7euXpgKVtbnghO1Q=";
  };
in
stdenvNoCC.mkDerivation {
  pname = "atom-one-dark-theme";
  version = "0-unstable-2021-12-03";

  dontUnpack = true;
  dontFixup = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/share/themes/AtomOneDarkTheme" "$out/share/icons/Atom One Dark"
    cp -a ${gtkTheme}/. "$out/share/themes/AtomOneDarkTheme/"
    cp -a ${iconTheme}/. "$out/share/icons/Atom One Dark/"

    runHook postInstall
  '';

  meta = {
    description = "Atom One Dark GTK and icon themes";
    homepage = "https://github.com/UnnatShaneshwar/AtomOneDarkTheme";
    # Neither upstream theme repository declares a license.
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
  };
}
