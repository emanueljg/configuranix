{ self, withSystem }: { config, lib, ... }: {
  options = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
    };
    system = lib.mkOption {
      type = lib.types.str;
    };

    deploy = lib.mkOption {
      type = lib.types.attrsOf lib.types.unspecified;
      default = { };
    };

    nixos = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
    };

    home = lib.mkOption {
      type = lib.types.listOf lib.types.unspecified;
    };

    specialArgs = {
      packages = lib.mkOption {
        default = { };
        type = lib.types.attrsOf lib.types.package;
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

      # nixpkgs but instanced
      nixpkgs' = lib.mkOption {
        readOnly = true;
        type = lib.types.attrsOf lib.types.unspecified;
        default = builtins.mapAttrs (_: v: v.legacyPackages.${config.system}) config.specialArgs.nixpkgs;
      };

      self = lib.mkOption {
        readOnly = true;
        type = lib.types.attrsOf lib.types.unspecified;
        default = self;
      };

      other = lib.mkOption {
        default = { };
        type = lib.types.attrsOf lib.types.unspecified;
      };
    };
  };

  config = {
    _module.args = {
      inherit (withSystem config.system lib.trivial.id)
        inputs';
    };
  };
}

