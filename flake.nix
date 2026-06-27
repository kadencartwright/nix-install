{
  description = "NixOS replacement for the Arch install scripts";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    t3code-nix.url = "github:Sawrz/t3code-nix";
    openai-codex-desktop-nix.url = "github:kadencartwright/openai-codex-desktop-nix/latest";

    disko = {
      url = "github:nix-community/disko/latest";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix.url = "github:Mic92/sops-nix";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    dotfiles = {
      url = "github:kadencartwright/dotfiles";
      flake = false;
    };

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
      nixosConfigurations.X1C = mkHost { hostModule = ./hosts/X1C/default.nix; };
      nixosConfigurations.MINI = mkHost { hostModule = ./hosts/MINI/default.nix; };
      nixosConfigurations.pi5 = mkHost {
        hostModule = ./hosts/pi5/default.nix;
        system = "aarch64-linux";
        extraModules = [ ];
      };
    };
}
