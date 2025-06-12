{ config, lib, ... }: {
  imports = [
    ./schema.nix
  ];

  configuranix.moduleSets.home =
    let
      cfg = config.configuranix.moduleSets.home;
    in
    {
      _inputsList = [ "home-manager" "nixpkgs" ];
      _cfgFunction = name: configuration:
        if !configuration.enable then null else
        config.configuranix.moduleSets.home.inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = cfg.inputs.nixpkgs.legacyPackages.${configuration.system};
          modules = configuration.home;
          extraSpecialArgs = configuration.specialArgs;
        };
    };

}
