# FTP somente leitura com os jogos do Switch, para o console instalar pela
# rede de casa (10.42.1.0/24, a mesma do server).
#
#   Pasta:   /srv/data/games/switch (o qBittorrent baixa nela; o Nextcloud mostra
#            a mesma pasta como "Jogos do Switch")
#   Acesso:  ftp://10.42.1.20, porta 21, usuário "switch" (passivo nas 50000-50019)
#            liberado só para a rede de casa
#
# A senha do usuário fica fora do repositório (hash SHA-512):
#   mkpasswd -m sha-512 | sudo install -Dm600 /dev/stdin /var/lib/secrets/switch-ftp.hash
# e aplique de novo (nixos-rebuild) para o usuário receber a senha.
{ config, lib, ... }:
let
  games = "${config.dionix.storage.data}/games/switch";
  lan = "10.42.1.0/24";
  pasv = {
    from = 50000;
    to = 50019;
  };
  # Só a rede de casa chega ao FTP (o firewall do NixOS abriria para todas as interfaces)
  regras =
    acao:
    lib.concatMapStrings
      (porta: "iptables -${acao} nixos-fw -p tcp -s ${lan} --dport ${porta} -j nixos-fw-accept\n")
      [
        "21"
        "${toString pasv.from}:${toString pasv.to}"
      ];
in
{
  imports = [ ./storage.nix ];

  users.users.switch = {
    isSystemUser = true;
    group = "media";
    home = games;
    hashedPasswordFile = "/var/lib/secrets/switch-ftp.hash";
  };

  services.vsftpd = {
    enable = true;
    localUsers = true;
    writeEnable = false;
    chrootlocalUser = true;
    localRoot = games;
    # Só o usuário switch entra
    userlistEnable = true;
    userlistDeny = false;
    userlist = [ "switch" ];
    extraConfig = ''
      pasv_enable=YES
      pasv_min_port=${toString pasv.from}
      pasv_max_port=${toString pasv.to}
      # O usuário não tem shell de login
      check_shell=NO
      # Listagens com nomes longos e acentos, comuns nos arquivos de jogos
      utf8_filesystem=YES
    '';
  };

  systemd.services.vsftpd.unitConfig.RequiresMountsFor = games;

  networking.firewall = {
    extraCommands = regras "A";
    extraStopCommands = lib.replaceStrings [ "\n" ] [ " || true\n" ] (regras "D");
  };
}
