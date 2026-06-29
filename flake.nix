{
  description = "My Home Manager configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, home-manager, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      # Username/home dir are the only per-machine bits, so inject them here
      # and keep home.nix machine-agnostic. Add a line under homeConfigurations
      # per host.
      mkHome = username: home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          {
            home.username = username;
            home.homeDirectory = "/home/${username}";
          }
          ./home.nix
        ];
      };
    in {
      homeConfigurations = {
        json0 = mkHome "json0";
        jsond = mkHome "jsond";
      };
    };
}
