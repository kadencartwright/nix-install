{
  description = "NixOS replacement for the Arch install scripts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    openai-chatgpt-desktop-nix.url = "github:kadencartwright/openai-chatgpt-desktop-nix";

    obsbot-cli = {
      url = "github:kadencartwright/obsbot-cli";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix.url = "github:Mic92/sops-nix";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    dotfiles = {
      url = "github:kadencartwright/dotfiles";
      flake = false;
    };

    # Theme definitions, templates, and the renderer used by home/theme.nix.
    # The Arch-specific system configuration is deliberately not imported.
    omarchy = {
      url = "github:basecamp/omarchy/quattro";
      flake = false;
    };

    # Retained for the declarative "Current System" custom Omarchy theme.
    onedark-wallpapers = {
      url = "github:Narmis-E/onedark-wallpapers";
      flake = false;
    };

    tm = {
      url = "github:kadencartwright/tm";
      flake = false;
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      nixpkgs-unstable,
      disko,
      home-manager,
      sops-nix,
      ...
    }:
    let
      lib = nixpkgs.lib;
      mkHost =
        {
          hostModule,
          system ? "x86_64-linux",
          extraModules ? [ ./hosts/common/disko.nix ],
        }:
        let
          pkgsUnstable = import nixpkgs-unstable {
            inherit system;
            config.allowUnfree = true;
          };
        in
        lib.nixosSystem {
          inherit system;
          specialArgs = {
            inherit inputs pkgsUnstable;
          };

          modules =
            [
              disko.nixosModules.disko
              home-manager.nixosModules.home-manager
              sops-nix.nixosModules.sops
            ]
            ++ extraModules
            ++ [
              hostModule
            ];
        };
    in
    {
      nixosConfigurations.Z16 = mkHost { hostModule = ./hosts/Z16/default.nix; };
      nixosConfigurations.T16 = mkHost { hostModule = ./hosts/T16/default.nix; };
      nixosConfigurations.X1C = mkHost { hostModule = ./hosts/X1C/default.nix; };
      nixosConfigurations.MINI = mkHost { hostModule = ./hosts/MINI/default.nix; };
      nixosConfigurations.pi5 = mkHost {
        hostModule = ./hosts/pi5/default.nix;
        system = "aarch64-linux";
        extraModules = [ ];
      };
    };
}
