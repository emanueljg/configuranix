{ lib
, deploy-rs
, haumea
}: { self, inputs, flake-parts-lib, withSystem, config, ... }: {
  options.configuranix =
    let
      mkModuleSetOption =
        { output
        , inputsList
        , cfgFunction
        , extraOptions ? { }
        }:
        lib.mkOption {
          default = { };
          type = lib.types.submodule ({ ... }@submod: {
            options = extraOptions // {
              enable = lib.mkOption {
                default = true;
                type = lib.types.bool;
              };

              specialArgs = lib.mkOption {
                type = lib.types.attrsOf lib.types.anything;
                default = submod.specialArgs;
              };

              inputs = lib.mkOption {
                default = { };
                type = lib.types.submodule {
                  options = lib.genAttrs inputsList (_: lib.mkOption {
                    type = lib.types.unspecified;
                  });
                };
              };

              path = lib.mkOption {
                type = lib.types.str;
                default = "${self}/${output}";
              };

              _cfgFunction = lib.mkOption {
                readOnly = true;
                internal = true;
                type = lib.types.unspecified;
                default = cfgFunction;
              };

              _haumeaModules = lib.mkOption {
                readOnly = true;
                internal = true;
                type = with lib.types; lazyAttrsOf unspecified;
                default =
                  let
                    mods = haumea.lib.load {
                      src = submod.config.path;
                      loader = haumea.lib.loaders.verbatim;
                    };
                  in
                  mods;
              };
            };
          });
        };


      mkCfgType =
        { category
        , extraOptions ? { }
        }: lib.types.attrsOf (lib.types.submodule
          ({ name, ... }@submod:
          let
            mkModOption = output: lib.mkOption {
              readOnly = true;
              internal = true;
              default =
                let
                  parentModules = builtins.map (par: par."_${output}Modules") submod.config.parents;
                in
                lib.flatten [ parentModules submod.config.${output} ];
            };

          in
          {
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = true;
              };
              system = lib.mkOption {
                default = "x86_64-linux";
                type = lib.types.str;
              };

              specialArgs = lib.mkOption {
                default = { };
                type = lib.types.submodule ({ ... }@argsmod: {
                  options = {
                    packages = lib.mkOption {
                      default = inputs': { };
                      type = lib.types.functionTo (lib.types.attrsOf lib.types.package);
                    };

                    nixosModules = lib.mkOption {
                      default = { };
                      type = lib.types.attrsOf lib.types.unspecified;
                    };

                    homeModules = lib.mkOption {
                      default = { };
                      type = lib.types.attrsOf lib.types.unspecified;
                    };

                    nixpkgs = lib.mkOption {
                      default = { };
                      type = lib.types.attrsOf lib.types.unspecified;
                    };

                    other = lib.mkOption {
                      default = { };
                      type = lib.types.attrsOf lib.types.unspecified;
                    };

                    _commonMerged = lib.mkOption {
                      readOnly = true;
                      internal = true;
                      default = {
                        # just passthrough
                        inherit (argsmod.config) other;
                        # apply 'inputs
                        packages = withSystem
                          submod.config.system
                          ({ inputs', ... }: argsmod.config.packages inputs');
                        # use legacyPackages
                        nixpkgs = builtins.mapAttrs
                          (n: v: v.legacyPackages.${submod.config.system})
                          argsmod.config.nixpkgs;
                      };
                    };

                    _nixosMerged = lib.mkOption {
                      readOnly = true;
                      internal = true;
                      default = argsmod.config._commonMerged // {
                        inherit (argsmod.config) nixosModules;
                      };
                    };

                    _homeMerged = lib.mkOption {
                      readOnly = true;
                      internal = true;
                      default = argsmod.config._commonMerged // {
                        inherit (argsmod.config) homeModules;
                      };
                    };

                    _nixosFamily = lib.mkOption {
                      readOnly = true;
                      internal = true;
                      type = with lib.types; attrsOf unspecified;
                      default = (lib.foldr
                        (x: y: lib.recursiveUpdate
                          x.specialArgs._nixosFamily
                          y
                        )
                        submod.config.specialArgs._nixosMerged
                        submod.config.parents
                      );
                    };

                    _homeFamily = lib.mkOption {
                      readOnly = true;
                      internal = true;
                      type = with lib.types; attrsOf unspecified;
                      default = (lib.foldr
                        (x: y: lib.recursiveUpdate
                          x.specialArgs._homeFamily
                          y
                        )
                        submod.config.specialArgs._homeMerged
                        submod.config.parents
                      );
                    };

                  };
                });
              };

              deploy = lib.mkOption {
                type = lib.types.attrsOf lib.types.unspecified;
                default = { };
              };

              _deployFamily = lib.mkOption {
                readOnly = true;
                internal = true;
                type = with lib.types; attrsOf unspecified;
                default = (lib.foldr
                  (x: y: lib.recursiveUpdate
                    x._deployFamily
                    y
                  )
                  submod.config.deploy
                  submod.config.parents
                );
              };

              parents = lib.mkOption {
                type = lib.types.listOf lib.types.unspecified;
              };
              nixos = lib.mkOption {
                type = lib.types.listOf lib.types.unspecified;
              };
              home = lib.mkOption {
                type = lib.types.listOf lib.types.unspecified;
              };

              _nixosModules =
                mkModOption "nixos";
              _homeModules = mkModOption "home";


            };
          }));
      mkCfgOption = { category }: lib.mkOption {
        default =
          let
            cfgPath = "${self}/${category}";
          in
          lib.mapAttrs'
            (filename: _:
              let
                value = (import "${cfgPath}/${filename}" {
                  config = value;
                  inherit inputs;
                  inherit (config.configuranix) hosts blueprints;
                  nixos = config.configuranix.nixos._haumeaModules;
                  home = config.configuranix.home._haumeaModules;
                });
              in
              lib.nameValuePair
                (lib.removeSuffix ".nix" filename)
                value
            )
            (builtins.readDir cfgPath);
        type = mkCfgType { inherit category; };
      };
    in
    {
      enable = lib.mkEnableOption "configuranix";

      nixos = mkModuleSetOption {
        output = "nixos";
        inputsList = [ "nixpkgs" ];
        cfgFunction = hostname: configuration: config.configuranix.nixos.inputs.nixpkgs.lib.nixosSystem {
          inherit (configuration) system;
          specialArgs =
            configuration.specialArgs._nixosFamily // {
              inherit self;
            };
          modules = configuration._nixosModules;
        };
      };

      home = mkModuleSetOption {
        output = "home";
        inputsList = [ "home-manager" "nixos-unstable" ];
        cfgFunction = hostname: configuration: config.configuranix.home.inputs.home-manager.lib.homeManagerConfiguration {
          pkgs = config.configuranix.home.inputs.nixos-unstable.legacyPackages.${configuration.system};
          modules = configuration._homeModules;
          extraSpecialArgs =
            configuration.specialArgs._homeFamily // {
              inherit self;
            };
        };
      };

      deploy = lib.mkOption {
        type = with lib.types; attrsOf anything;
        default = { };
      };

      blueprints = mkCfgOption { category = "blueprints"; };
      hosts = mkCfgOption { category = "hosts"; };
    };

  config.flake =
    let
      enabledHosts = lib.filterAttrs (k: v: v.enable) config.configuranix.hosts;
      mkCfgOutputs = output: builtins.mapAttrs
        (hostname: host: config.configuranix.${output}._cfgFunction hostname host)
        enabledHosts;
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
            lib.recursiveUpdate defaultDeploy hostCfg._deployFamily
          )
          enabledHosts;
      };
    };
}



