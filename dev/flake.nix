{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.05";
    home-manager.url = "github:nix-community/home-manager/release-23.05";

    flake-parts.url = "github:hercules-ci/flake-parts";
    boulder.url = "github:berkeleytrue/nix-boulder-banner";

    home-manager-parts.url = "../";

    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {inherit inputs;} {
      systems = ["x86_64-linux"];
      imports = [
        inputs.boulder.flakeModule
        inputs.home-manager-parts.flakeModule
      ];

      perSystem = {
        config,
        lib,
        pkgs,
        ...
      }: let
        build-home = pkgs.writeShellScriptBin "build-home" ''
          # check if we are in a home-manager environment
          echo "building home-manager environment for $1"
          nix build --show-trace --print-build-logs .\#homeConfigurations.$1.activationPackage
        '';
      in {
        devShells.default = pkgs.mkShell {
          name = "home-dev";
          buildInputs = [
            build-home
          ];
        };
      };

      flake = {
        schemas.homeConfigurations = inputs.home-manager-parts.schemas;
      };

      home-manager-parts = {
        enable = true;

        home-manager = inputs.home-manager;

        exposePackages = true;

        defaults = {
          system = "x86_64-linux";
          stateVersion = "23.05";
        };

        shared = {
          pkgs,
          profile,
          ...
        }: {
          extraSpecialArgs = rec {
            name =
              if profile == "bill"
              then "ted"
              else "bill";
            hello = pkgs.writeShellScriptBin "hello" ''
              #!/usr/bin/env bash
              echo "hello ${name}"
            '';
          };
        };

        profiles = {
          bill = {
            modules = [
              ({
                hello,
                pkgs,
                ...
              }: {
                home.packages = [
                  hello
                ];
              })
            ];
          };

          ted = {
            modules = [
              ({
                hello,
                pkgs,
                ...
              }: {
                home.packages = [
                  hello
                ];
              })
            ];
          };

          desktop = {
            username = "big-berks";
            modules = [
              {
                xdg.configFile."foo/barrc".text = ''
                  super-lame=config
                '';
              }
            ];
          };

          laptop = {
            username = "big-berks";
            modules = [
              {
                xdg.configFile."foo/barrc".text = ''
                  super-cool=config
                '';
              }
            ];
          };
        };
      };
    };
}
