{
  description = "Description for the project";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    deploy-rs.url = "github:serokell/deploy-rs";
    haumea.url = "github:nix-community/haumea";
  };

  outputs = inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
      perSystem = { inputs', ... }: {
        packages.deploy-rs = inputs'.deploy-rs.packages.deploy-rs;
      };
      flake = {
        flakeModules.default = import ./flake-module.nix {
          lib = inputs.nixpkgs.lib;
          inherit (inputs) deploy-rs haumea;
        };
      };
    };
}
