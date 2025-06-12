{ config, lib, ... }: {
  imports = [
    ./schema.nix
  ];

  configuranix.moduleSets.nixos =
    let
      cfg = config.configuranix.moduleSets.nixos;
    in
    {
      _inputsList = [ "nixpkgs" ];
      _cfgFunction = name: configuration:
        if !configuration.enable then null else
        config.configuranix.moduleSets.nixos.inputs.nixpkgs.lib.nixosSystem {
          inherit (configuration) system specialArgs;
          modules = configuration.nixos ++ [{
            networking.hostName = lib.mkDefault name;
          }];
        };

    };

}
