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
      # Username/home dir, system and host distro are the only per-machine
      # bits, so inject them here and keep home.nix machine-agnostic. Add a
      # line under homeConfigurations per host.
      #
      # `distro` is passed as a module arg so modules can branch on it — the
      # host distro can't be detected during a pure flake evaluation. It only
      # matters where the surrounding desktop differs (see modules/gnome.nix).
      # "darwin" is a distro like any other; the Makefile detects it the same
      # way (common/detect-distro.sh).
      #
      # `dotfilesRepo` is the repo directory name under ~/Documents/workarea.
      # The Mac checkout is "dotfiles.nosync" to keep iCloud's sync away from
      # it; the Linux hosts use plain "dotfiles". modules/dotfiles.nix and the
      # cdd alias consume the resulting absolute path (dotfilesDir).
      #
      # services.nix and gnome.nix are included only on Linux: Home Manager
      # does not define systemd.user.* options on Darwin, so importing
      # services.nix there is an eval error no amount of mkIf can guard.
      mkHome = username: { system ? "x86_64-linux", distro ? "fedora", dotfilesRepo ? "dotfiles" }:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          isDarwin = nixpkgs.lib.hasSuffix "darwin" system;
          homeDirectory = if isDarwin then "/Users/${username}" else "/home/${username}";
        in
        home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            {
              home.username = username;
              home.homeDirectory = homeDirectory;
              _module.args.distro = distro;
              _module.args.dotfilesDir = "${homeDirectory}/Documents/workarea/${dotfilesRepo}";
            }
            ./home.nix
          ] ++ nixpkgs.lib.optionals (!isDarwin) [
            ./modules/services.nix
            ./modules/gnome.nix
          ];
        };
    in
    {
      # Keyed by "<username>-<distro>", not username alone: the same username
      # can exist on hosts running different distros, and the distro decides
      # which desktop assumptions apply (see modules/gnome.nix). The Makefile
      # selects the right one automatically — FLAKE defaults to
      # .#$(id -un)-$(DISTRO), with DISTRO from common/detect-distro.sh.
      homeConfigurations = {
        "json0-fedora" = mkHome "json0" { };
        "jsond-fedora" = mkHome "jsond" { };
        "jsond-ubuntu" = mkHome "jsond" { distro = "ubuntu"; };
        "json0-darwin" = mkHome "json0" {
          system = "aarch64-darwin";
          distro = "darwin";
          dotfilesRepo = "dotfiles.nosync";
        };
      };
    };
}
