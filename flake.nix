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

    # Particionamento declarativo (discos e pool ZFS do server)
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Paletas base16 aplicadas aos aplicativos (home/desktop/themes.nix)
    stylix = {
      url = "github:nix-community/stylix/release-26.05";
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

      # Hosts e a arquitetura de cada um
      hosts = {
        notebook = "x86_64-linux";
        desktop = "x86_64-linux";
        server = "x86_64-linux";
        # Sistema mínimo gravado no HD do server pelo desktop (docs/homelab.md)
        server-bootstrap = "x86_64-linux";
        pi = "aarch64-linux";
      };

      # Monta um host: o módulo dele (hosts/<nome>) escolhe os papéis em modules/nixos
      mkHost =
        hostname: system:
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
      nixosConfigurations = nixpkgs.lib.mapAttrs mkHost hosts;

      # Imagem do cartão SD do Raspberry Pi (compila no desktop via emulação ARM)
      packages.aarch64-linux.pi-image = self.nixosConfigurations.pi.config.system.build.sdImage;

      # `nix fmt` formata todos os arquivos .nix
      formatter.${system} = pkgs.nixfmt-tree;

      # `nix flake check` avalia todos os hosts por completo (sem compilar nada)
      checks.${system} =
        nixpkgs.lib.mapAttrs (
          name: host:
          pkgs.writeText "${name}-toplevel" (
            builtins.unsafeDiscardStringContext host.config.system.build.toplevel.drvPath
          )
        ) self.nixosConfigurations
        // {
          # Testes do comando `theme`
          theme-script = pkgs.runCommand "theme-script-test" { } ''
            bash ${./home/desktop/files/theme/theme-test.sh} ${./home/desktop/files/theme/theme.sh}
            touch $out
          '';
          # Testes do comando `ssh-key-restore`
          ssh-key-restore =
            pkgs.runCommand "ssh-key-restore-test"
              {
                nativeBuildInputs = with pkgs; [
                  jq
                  openssh
                ];
              }
              ''
                bash ${./home/desktop/files/ssh-key-restore/ssh-key-restore-test.sh} ${./home/desktop/files/ssh-key-restore/ssh-key-restore.sh}
                touch $out
              '';
        };
    };
}
