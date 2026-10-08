{
  inputs,
  lib,
  pkgs,
  pkgsUnstable,
  isDesktop ? false,
  ...
}:

let
  platformSystem = pkgs.stdenv.hostPlatform.system;
  chatgptVersion = "26.1002.52244";
  codex = pkgsUnstable.callPackage ../packages/codex.nix { };
  herdr = pkgs.callPackage ../packages/herdr.nix { };
  tm = pkgs.callPackage ../packages/tm.nix {
    tm-src = inputs.tm;
  };
  openaiChatgptDesktop =
    inputs.openai-chatgpt-desktop-nix.packages.${platformSystem}.default.overrideAttrs
      (oldAttrs: {
        version = chatgptVersion;
        src = pkgs.fetchurl {
          url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${chatgptVersion}_amd64.deb";
          hash = "sha256-lJjkFxMaJ4vONb//YnXSUsDTMvF6/AMT4LeCdJ9NNIo=";
        };
        # Tectonic moved out of the LaTeX plugin in the September 24 package.
        installPhase =
          builtins.replaceStrings
            [ "resources/plugins/openai-bundled/plugins/latex/bin/tectonic" ]
            [ "resources/tectonic/tectonic" ]
            oldAttrs.installPhase;
      });
  opencode = pkgsUnstable.callPackage ../packages/opencode.nix { };
  opencodeDesktop = pkgsUnstable.callPackage ../packages/opencode-desktop.nix { };
  pi = pkgsUnstable.pi-coding-agent.overrideAttrs (
    finalAttrs: oldAttrs: {
      version = "1.1.0";
      src = pkgsUnstable.fetchFromGitHub {
        owner = "earendil-works";
        repo = "pi";
        tag = "v${finalAttrs.version}";
        hash = "sha256-lwjspkMGrW+8Fl/yBEDEFsHZJA57OKOhmVQmi6zfej4=";
      };
      npmDepsHash = "sha256-GOh5WG+rRgzoy/yVHY5PoEKJZGQcEGhISrDDJxkP8W4=";
      npmDeps = pkgsUnstable.fetchNpmDeps {
        inherit (finalAttrs) src;
        name = "pi-coding-agent-${finalAttrs.version}-npm-deps";
        hash = finalAttrs.npmDepsHash;
      };
      modelData = pkgsUnstable.fetchurl {
        url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${finalAttrs.version}.tgz";
        hash = "sha512-1T7LAkc/5Bvc0v6w4vAGVdCrli0o/E0pEmYKTnixu95vSFArBjvbhS/G4ZwI0RUePgf0Imcu0VyqlM4EcXxqfw==";
      };
      # Build new workspaces before their consumers; upstream now uses tsc.
      buildPhase = builtins.replaceStrings [ "npx tsgo" ] [ "npx tsc" ] (
        builtins.replaceStrings
          [
            "npx tsgo -p packages/tui/tsconfig.build.json"
            "npx tsgo -p packages/ai/tsconfig.build.json"
            "npx tsgo -p packages/agent/tsconfig.build.json"
            "npm run build --workspace=packages/coding-agent"
          ]
          [
            "npx tsgo -p packages/chord/tsconfig.build.json\n    npx tsgo -p packages/tui/tsconfig.build.json"
            "npx tsgo -p packages/codemode/tsconfig.build.json\n    npx tsgo -p packages/mcp/tsconfig.build.json\n    npx tsgo -p packages/ai/tsconfig.build.json"
            "npx tsgo -p packages/durable/tsconfig.build.json\n    npx tsgo -p packages/agent/tsconfig.build.json"
            "npx tsgo -p packages/server/tsconfig.build.json\n    npm run build --workspace=packages/coding-agent"
          ]
          oldAttrs.buildPhase
      );
      postInstall =
        builtins.replaceStrings
          [ "for ws in " ]
          [
            "for ws in @earendil-works/chord:packages/chord @earendil-works/pi-codemode:packages/codemode @earendil-works/pi-mcp:packages/mcp "
          ]
          oldAttrs.postInstall;
    }
  );
  portmux = inputs.portmux.packages.${platformSystem}.default;
  t3 = pkgsUnstable.callPackage ../packages/t3-cli { inherit codex; };
  t3code = pkgsUnstable.callPackage ../packages/t3code.nix { inherit codex; };
in

{
  home.packages = with pkgs; [
    awscli2
    bat
    bubblewrap
    btop
    atuin
    eza
    fd
    fnm
    fzf
    gh
    jq
    lazygit
    nodejs
    pass
    ripgrep
    tmux
    zoxide
  ] ++ [ pi ]
  ++ [ codex ]
  ++ [ herdr ]
  ++ [ opencode ]
  ++ [ portmux ]
  ++ lib.optional isDesktop opencodeDesktop
  ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [
    t3
    t3code
  ]
  ++ lib.optional pkgs.stdenv.hostPlatform.isx86_64 openaiChatgptDesktop
  ++ [
    tm
  ];

  # Keep Voxtype's Wayland virtual-keyboard paste events native; XWayland
  # clients can misinterpret wtype's temporary keymap.
  xdg.configFile."chatgpt-flags.conf" = lib.mkIf (isDesktop && pkgs.stdenv.hostPlatform.isx86_64) {
    text = ''
      --ozone-platform=wayland
    '';
  };

  xdg.configFile."tm/config.toml".source = "${inputs.dotfiles}/tm/config.toml";

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };
}
