{
  description = "A `flake-parts` home-manager integration";
  outputs = {...}: let
    mkChildren = children: {inherit children;};
    homeManagerConfigurationsSchema = {
      version = 1;
      doc = ''
        The `home-manager` flake output defines [user environments using Nix](https://nix-community.github.io/home-manager/).
      '';
      inventory = output:
        mkChildren (builtins.mapAttrs
          (configName: home: {
            what = "HomeManager configuration";
            derivation = home.config.home.activationPackage;
          })
          output);
    };
  in {
    flakeModule = ./home-manager-parts;
    schemas.homeConfigurations = homeManagerConfigurationsSchema;
  };
}
