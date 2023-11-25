{
  config,
  lib,
  withSystem,
  ...
}: let
  cfg = config.home-manager-parts;
in
  with lib; {
    options = {
      home-manager-parts = {
        enable = lib.mkOption {
          type = types.bool;
          description = mdDoc "Whether all homeManagerConfigurations should be enabled by default";
          default = true;
        };

        home-manager = mkOption {
          type = types.unspecified;
          description = mdDoc "home-manager input to use for building all homeManagerConfigurations. Required";
        };

        exposePackages = mkOption {
          type = types.bool;
          description = mdDoc "Whether to expose homeManagerConfigurations output at `.#packages.<system>.home/<profile name>`";
          default = true;
        };

        defaults = {
          system = mkOption {
            type = types.enum platforms.all;
            description = mdDoc "The default system to use for building homeManagerConfigurations";
            default = "x86_64-linux";
          };

          stateVersion = mkOption {
            type = types.str;
            description = mdDoc "The default stateVersion to use for building homeManagerConfigurations";
            default = "23.05";
          };
        };

        shared = mkOption {
          description = mdDoc "Global options for all homeManagerConfigurations, a function supplied name, profile and pkgs";
          type = types.functionTo (types.submodule {
            options = {
              modules = mkOption {
                type = types.listOf types.unspecified;
                description = mdDoc "List of modules to include in all homeManagerConfigurations";
                default = [];
              };

              extraSpecialArgs = mkOption {
                type = types.attrsOf types.unspecified;
                description = mdDoc "`extraSpecialArgs` passed to all homeManagerConfigurations";
                default = {};
              };
            };
          });
        };

        profiles = mkOption {
          description = lib.mdDoc "An attribute set of profiles to be built using homeConfigurations, where the key is the username and the value is a set of options. Each profile is built using the following options:";
          type = types.attrsOf (types.submodule ({
            name, # Key of the profile?
            config,
            ...
          }: {
            options = {
              enable = mkOption {
                type = types.bool;
                description = mdDoc "Whether to expose the homeManagerConfiguration to the flake";
                default = cfg.enable;
              };

              directory = mkOption {
                type = types.str;
                description = mdDoc "The home directory passed to home-manager, or `home.homeDirectory`";
                default = "/home/${name}";
              };

              home-manager = mkOption {
                type = types.unspecified;
                description = mdDoc "home-manager input to use for building the homeManagerConfiguration. Required to be set per-profile or using `home-manager-parts.home-manager`";
                default = cfg.home-manager;
              };

              modules = mkOption {
                type = types.listOf types.unspecified;
                description = mdDoc "List of modules to include in the homeManagerConfiguration";
                default = [];
              };

              specialArgs = mkOption {
                type = types.attrsOf types.unspecified;
                description = mdDoc "`specialArgs` passed to the homeManagerConfiguration call for this profile";
                default = {};
              };

              system = mkOption {
                type = types.enum platforms.all;
                description = mdDoc "system used for building the homeManagerConfiguration";
                default = cfg.defaults.system;
              };

              stateVersion = mkOption {
                type = types.str;
                description = mdDoc "stateVersion used for building the homeManagerConfiguration, defaults to `defaults.stateVersion`";
                default = cfg.defaults.stateVersion;
              };

              username = mkOption {
                type = types.str;
                description = mdDoc "The username passed to home-manager, or `home.username`. Defaults to the profile name";
                default = name;
              };

              # readOnly

              homeConfigOutput = mkOption {
                type = types.unspecified;
                readOnly = true;
                description = mdDoc "Output of homeConfigurations call for this profile";
              };

              finalModules = mkOption {
                type = types.unspecified;
                description = mdDoc "Final set of modules available to be used in homeConfigurations input";
                readOnly = true;
              };

              activationPackage = mkOption {
                type = types.unspecified;
                description = mdDoc "Package to be added to the flake to provide schema-supported access to activationPackage";
                readOnly = true;
              };
            };

            config = let
              profile = config;
              pkgs = withSystem profile.system ({pkgs, ...}: pkgs);
              sharedCfg =
                if lib.isFunction cfg.shared
                then cfg.shared {inherit name profile pkgs;}
                else throw "home-manager-parts.shared must be a function";
            in
              lib.mkIf profile.enable {
                finalModules =
                  sharedCfg.modules
                  ++ [
                    {
                      home.homeDirectory = lib.mkDefault profile.directory;
                      home.username = lib.mkDefault profile.username;
                    }
                  ]
                  ++ profile.modules;

                homeConfigOutput = profile.home-manager.lib.homeManagerConfiguration {
                  inherit pkgs;

                  extraSpecialArgs = lib.recursiveUpdate sharedCfg.extraSpecialArgs profile.specialArgs;

                  modules =
                    [
                      (_: {
                        home.stateVersion = lib.mkDefault profile.stateVersion;
                      })
                    ]
                    ++ profile.finalModules;
                };

                activationPackage = {
                  ${profile.system}."home/${name}" = profile.homeConfigOutput.activationPackage;
                };
              };
          }));
        };
      };
    };

    config = lib.mkMerge [
      (lib.mkIf cfg.enable (let
        # group checks into system-based sortings
        # packages.<system>."home/<name>" = homeConfigurationOutput.activationPackage
        packages =
          lib.zipAttrs
          (builtins.attrValues
            (lib.mapAttrs
              (_: i:
                if i.enable
                then i.activationPackage
                else {})
              cfg.profiles));
      in {
        # homes.<name> = <homeManagerConfiguration>
        flake.homeConfigurations =
          builtins.mapAttrs
          (_: profile: profile.homeConfigOutput)
          cfg.profiles;

        perSystem = {system, ...}: {
          packages = lib.mkIf (cfg.exposePackages && (builtins.hasAttr system packages)) (lib.mkMerge packages.${system});
        };
      }))
    ];
  }
