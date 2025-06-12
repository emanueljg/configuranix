{ lib
, deploy-rs
, haumea
}: { self, inputs, flake-parts-lib, withSystem, config, ... }: {

  imports = [
    ./module-sets/nixos.nix
    ./module-sets/home.nix
  ];

  options.configuranix =
    let
      hostTypes = [ "blueprints" "hosts" ];
    in
    {
      enable = lib.mkEnableOption "configuranix";

      hostsPath = lib.mkOption {
        type = lib.types.path;
      };

      blueprintsPath = lib.mkOption {
        type = lib.types.path;
      };


      deploy = lib.mkOption {
        type = with lib.types; attrsOf anything;
        default = { };
      };

      inherit (let
        mkConfigurationModulesOptions = hostType: lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          # default = haumea.lib.load {
          #   src = config.configuranix."${hostType}Path";
          #   loader = haumea.lib.loaders.verbatim;
          # };
          default = lib.mapAttrs'
            (k: v: lib.nameValuePair
              (lib.removeSuffix ".nix" k)
              ("${config.configuranix."${hostType}Path"}/${k}")
            )
            (builtins.readDir
              config.configuranix."${hostType}Path");
        };
      in
      lib.genAttrs hostTypes mkConfigurationModulesOptions)
        blueprints
        hosts;

      _configurations =
        let
          hostSchema = import ./host-schema.nix { inherit self withSystem; };
          mkConfigurationConfigsOptions = hostType: lib.mkOption {
            internal = true;
            readOnly = true;
            default = builtins.mapAttrs
              (_: module: (lib.evalModules {
                modules = [
                  # add in inputs'
                  hostSchema
                  module
                ];
                specialArgs = {
                  inherit self;
                  inherit (config.configuranix) hosts blueprints;
                  inherit inputs;
                } // (builtins.mapAttrs (k: v: v._haumeaModules) config.configuranix.moduleSets);
              }).config)
              config.configuranix.${hostType};
          };
        in
        lib.genAttrs hostTypes mkConfigurationConfigsOptions;

    };

  config = {
    _module.args = {
      inherit haumea;
    };
    flake =
      let
        mkCfgOutputs = output: lib.filterAttrs (k: v: v != null) (builtins.mapAttrs
          (name: mod: config.configuranix.moduleSets.${output}._cfgFunction name mod)
          config.configuranix._configurations.hosts);
      in
      lib.mkIf config.configuranix.enable {
        nixosConfigurations = mkCfgOutputs "nixos";
        homeConfigurations = mkCfgOutputs "home";
        deploy = config.configuranix.deploy // {
          nodes = builtins.mapAttrs
            (hostname: hostCfg:
              let
                inherit (deploy-rs.lib.${hostCfg.system}) activate;
                defaultDeploy = {
                  inherit hostname;
                  profiles = {
                    system = {
                      path = activate.nixos self.nixosConfigurations.${hostname};
                    };
                    home-manager = {
                      user = self.homeConfigurations.${hostname}.config.home.username;
                      path = activate.home-manager self.homeConfigurations.${hostname};
                    };
                  };
                };
              in
              lib.recursiveUpdate defaultDeploy hostCfg.deploy
            )
            config.configuranix._configurations.hosts;
        };
      };
  };
}



