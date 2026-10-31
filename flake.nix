{
  description = "dionix: configuração NixOS + Home Manager do notebook, do desktop e do homelab";

  inputs = {
    # Base estável; pacotes pontuais vêm do unstable (pkgs.unstable.<nome>)
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Arquivos de terceiros que antes vinham do .chezmoiexternal.toml / TPM / ya pkg
    yazi-flavors = {
      url = "github:yazi-rs/flavors";
      flake = false;
    };
    tmux-ping = {
      url = "github:ayzenquwe/tmux-ping";
      flake = false;
    };
    tmux-cargo = {
      url = "github:idevtier/tmux-cargo";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      username = "dio";
      pkgs = nixpkgs.legacyPackages.${system};

      # Monta um host: o módulo dele (hosts/<nome>) escolhe os papéis em modules/nixos
      mkHost =
        hostname:
        nixpkgs.lib.nixosSystem {
          inherit system;
          specialArgs = { inherit inputs username hostname; };
          modules = [
            ./hosts/${hostname}
            home-manager.nixosModules.home-manager
            {
              nixpkgs.overlays = [ (import ./overlays { inherit inputs; }) ];
              networking.hostName = hostname;
            }
          ];
        };
    in
    {
      nixosConfigurations = nixpkgs.lib.genAttrs [
        "notebook"
        "desktop"
        "server"
      ] mkHost;

      # `nix fmt` formata todos os arquivos .nix
      formatter.${system} = pkgs.nixfmt-tree;

      # `nix flake check` avalia os três hosts por completo (sem compilar nada)
      checks.${system} = nixpkgs.lib.mapAttrs (
        name: host:
        pkgs.writeText "${name}-toplevel" (
          builtins.unsafeDiscardStringContext host.config.system.build.toplevel.drvPath
        )
      ) self.nixosConfigurations;
    };
}
