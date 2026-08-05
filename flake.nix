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

      # Username/home dir and the host distro are the only per-machine bits, so
      # inject them here and keep home.nix machine-agnostic. Add a line under
      # homeConfigurations per host.
      #
      # `distro` is passed as a module arg so modules can branch on it — the
      # host distro can't be detected during a pure flake evaluation. It only
      # matters where the surrounding desktop differs (see modules/gnome.nix,
      # where Ubuntu ships extensions Fedora's vanilla GNOME does not).
      # Defaults to "fedora" so existing hosts keep their behaviour.
      mkHome = username: { distro ? "fedora" }: home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          {
            home.username = username;
            home.homeDirectory = "/home/${username}";
            _module.args.distro = distro;
          }
          ./home.nix
        ];
      };
    in
    {
      # Keyed by "<username>-<distro>", not username alone: the same username
      # can exist on hosts running different distros, and the distro decides
      # which desktop assumptions apply (see modules/gnome.nix). Keying on the
      # username alone silently gave every jsond host the Ubuntu branch.
      #
      # The Makefile selects the right one automatically — FLAKE defaults to
      # .#$(id -un)-$(DISTRO), with DISTRO from common/detect-distro.sh. There
      # are deliberately no bare "jsond"/"json0" aliases: a wrong guess writes
      # dconf for extensions the host does not have, so an unknown-attribute
      # error is the better failure.
      homeConfigurations = {
        "json0-fedora" = mkHome "json0" { };
        "jsond-fedora" = mkHome "jsond" { };
        "jsond-ubuntu" = mkHome "jsond" { distro = "ubuntu"; };
      };
    };
}
