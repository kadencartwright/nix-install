{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    distrobox
    podman
  ];

  programs.appimage = {
    enable = true;
    binfmt = true;
    package = pkgs.appimage-run.override {
      extraPkgs = pkgs: with pkgs; [
        libepoxy
      ];
    };
  };

  programs.nix-ld = {
    enable = true;
    libraries = with pkgs; [
      acl
      attr
      bzip2
      curl
      fontconfig
      freetype
      glib
      glibc
      gtk3
      libGL
      libdrm
      libgbm
      libxcrypt
      libxkbcommon
      nspr
      nss
      openssl
      stdenv.cc.cc
      systemd
      util-linux
      xorg.libX11
      xorg.libXScrnSaver
      xorg.libXcomposite
      xorg.libXcursor
      xorg.libXdamage
      xorg.libXext
      xorg.libXfixes
      xorg.libXi
      xorg.libXrandr
      xorg.libXrender
      xorg.libXtst
      xorg.libxcb
      xz
      zlib
      zstd
    ];
  };

  virtualisation.podman = {
    enable = true;
    dockerCompat = true;
  };

  environment.etc."distrobox/distrobox.conf".text = ''
    container_additional_volumes="/nix/store:/nix/store:ro /etc/profiles/per-user:/etc/profiles/per-user:ro /etc/static/profiles/per-user:/etc/static/profiles/per-user:ro /run/current-system/sw:/run/current-system/sw:ro"
  '';
}
