# Base de todas as máquinas: Nix, idioma, usuário, SSH, zsh e o Home Manager
# com as ferramentas de terminal (home/cli).
{
  pkgs,
  inputs,
  username,
  ...
}:
{
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      trusted-users = [
        "root"
        "@wheel"
      ];
    };
    # `nix shell nixpkgs#x` usa o mesmo nixpkgs do flake (sem baixar outro)
    registry.nixpkgs.flake = inputs.nixpkgs;
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
  };
  nixpkgs.config.allowUnfree = true;

  # nh: `nh os switch` (alias rebuild), `nh os switch --update` (alias syu) e limpeza automática
  programs.nh = {
    enable = true;
    flake = "/home/${username}/repos/dionix";
    clean = {
      enable = true;
      extraArgs = "--keep-since 14d --keep 5";
    };
  };

  # Idioma, fuso e teclado
  time.timeZone = "America/Sao_Paulo";
  i18n = {
    defaultLocale = "pt_BR.UTF-8";
    extraLocaleSettings.LC_MESSAGES = "en_US.UTF-8";
    supportedLocales = [
      "pt_BR.UTF-8/UTF-8"
      "en_US.UTF-8/UTF-8"
    ];
  };
  console.keyMap = "br-abnt2";
  services.xserver.xkb.layout = "br";

  # Usuário principal. A senha é definida com `passwd` depois da instalação.
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [
      "wheel"
      "video"
      "audio"
    ];
    shell = pkgs.zsh;
    # Coloque aqui as suas chaves públicas para entrar por SSH
    openssh.authorizedKeys.keys = [ ];
  };
  programs.zsh.enable = true;
  # Completação dos pacotes do sistema para o zsh do Home Manager
  environment.pathsToLink = [ "/share/zsh" ];

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    vim
    file
    pciutils
    usbutils
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    # Arquivos que já existiam em ~ (ex.: os do chezmoi) viram <arquivo>.hm-bak
    backupFileExtension = "hm-bak";
    extraSpecialArgs = { inherit inputs username; };
    users.${username} = {
      imports = [ ../../home/cli ];
      home = {
        inherit username;
        homeDirectory = "/home/${username}";
        stateVersion = "26.05";
      };
    };
  };

  system.stateVersion = "26.05";
}
