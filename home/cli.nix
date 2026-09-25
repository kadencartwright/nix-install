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
  chatgptVersion = "26.917.71314";
  codex = pkgsUnstable.callPackage ../packages/codex.nix { };
  herdr = pkgs.callPackage ../packages/herdr.nix { };
  tm = pkgs.callPackage ../packages/tm.nix {
    tm-src = inputs.tm;
  };
  openaiChatgptDesktop =
    inputs.openai-chatgpt-desktop-nix.packages.${platformSystem}.default.overrideAttrs (_: {
      version = chatgptVersion;
      src = pkgs.fetchurl {
        url = "https://persistent.oaistatic.com/codex-app-prod/linux/deb/pool/main/c/chatgpt/chatgpt_${chatgptVersion}_amd64.deb";
        hash = "sha256-hR7Ci2W94v8dqfN9zfW24gqRXHVo+LLOmTwAQo8BiuU=";
      };
    });
  opencode = pkgsUnstable.callPackage ../packages/opencode.nix { };
  opencodeDesktop = pkgsUnstable.callPackage ../packages/opencode-desktop.nix { };
  pi = pkgsUnstable.pi-coding-agent.overrideAttrs (finalAttrs: oldAttrs: {
    version = "0.87.1";
    src = pkgsUnstable.fetchFromGitHub {
      owner = "earendil-works";
      repo = "pi";
      tag = "v${finalAttrs.version}";
      hash = "sha256-GUhlq6t+l6iiViOZ0bkV28v3ZDqcLvEwpZpYZ5JAyDk=";
    };
    npmDepsHash = "sha256-JBIYoP2vvRNz1HONNvDJ1U3c+nmCJ7/VgNthRTkrkIA=";
    npmDeps = pkgsUnstable.fetchNpmDeps {
      inherit (finalAttrs) src;
      name = "pi-coding-agent-${finalAttrs.version}-npm-deps";
      hash = finalAttrs.npmDepsHash;
    };
    modelData = pkgsUnstable.fetchurl {
      url = "https://registry.npmjs.org/@earendil-works/pi-ai/-/pi-ai-${finalAttrs.version}.tgz";
      hash = "sha512-X/3PfQBnnoeVdO9Cv8zHghUMglzlgNZYGNzoPnbRoGnHl3Rw3TlA2UKSUB7BRHUOxMryHXYa8dnjWZlbRheDZA==";
    };
    # Build the new workspaces before their consumers, and retain chord at runtime.
    buildPhase = builtins.replaceStrings
      [
        "npx tsgo -p packages/tui/tsconfig.build.json"
        "npx tsgo -p packages/agent/tsconfig.build.json"
        "npx tsgo -p packages/protocol/tsconfig.build.json"
        "npm run build --workspace=packages/coding-agent"
      ]
      [
        "npx tsgo -p packages/chord/tsconfig.build.json\n    npx tsgo -p packages/tui/tsconfig.build.json"
        "npx tsgo -p packages/durable/tsconfig.build.json\n    npx tsgo -p packages/agent/tsconfig.build.json"
        "npx tsgo -p packages/session-backends/sqlite-node/tsconfig.build.json\n    npx tsgo -p packages/protocol/tsconfig.build.json"
        "npx tsgo -p packages/server/tsconfig.build.json\n    npm run build --workspace=packages/coding-agent"
      ]
      oldAttrs.buildPhase;
    postInstall = builtins.replaceStrings
      [ "for ws in " ]
      [ "for ws in @earendil-works/chord:packages/chord " ]
      oldAttrs.postInstall;
  });
  portmux = inputs.portmux.packages.${platformSystem}.default;
  t3 = pkgsUnstable.callPackage ../packages/t3-cli { inherit codex; };
  t3code = pkgsUnstable.callPackage ../packages/t3code.nix { inherit codex; };
in

{
  home.packages = with pkgs; [
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
