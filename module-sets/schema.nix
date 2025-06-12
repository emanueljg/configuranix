{ self, lib, haumea, inputs, flake-parts-lib, withSystem, config, ... }: {
  options.configuranix.moduleSets = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (lib.types.submodule ({ name, ... }@submod: {
      options = {
        _cfgFunction = lib.mkOption {
          type = lib.types.unspecified;
        };

        _inputsList = lib.mkOption {
          default = [ ];
          type = lib.types.listOf lib.types.str;
        };

        _haumeaModules = lib.mkOption {
          readOnly = true;
          type = lib.types.lazyAttrsOf lib.types.unspecified;
          default = haumea.lib.load {
            src = submod.config.path;
            loader = haumea.lib.loaders.verbatim;
          };
        };

        path = lib.mkOption {
          type = lib.types.path;
          default = "${self}/${name}";
        };

        inputs = lib.mkOption {
          default = { };
          type = lib.types.submodule {
            options = lib.genAttrs submod.config._inputsList (_: lib.mkOption {
              type = lib.types.unspecified;
            });
          };
        };

        defaultSpecialArgs = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
        };
      };
    }));
  };

}
