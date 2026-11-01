# NUT: servidor de títulos do Nintendo Switch para o Tinfoil.
#
#   nut.<domínio>  :9000, publicado pelo Pi com autenticação básica (o NUT
#                  não tem login próprio: a autenticação dele está desativada no código)
#   Jogos:         /mnt/nas/data/games/switch (somente leitura)
#   Estado:        /var/lib/nut (base de títulos, fila, keys.txt)
#
# Para o NUT identificar os arquivos, copie suas chaves para /var/lib/nut/app/keys.txt.
# No Tinfoil: File Browser → nova fonte com protocolo https, host nut.<domínio>,
# usuário e senha do proxy (veja o README).
#
# O nut.conf é gerado aqui a cada início: ajustes feitos pela interface web do
# NUT não sobrevivem a um reinício; mude neste módulo.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  games = "/mnt/nas/data/games/switch";
  state = "/var/lib/nut";

  nutConf = (pkgs.formats.json { }).generate "nut.conf" {
    paths.scan = [ games ];
    server = {
      hostname = "0.0.0.0";
      port = 9000;
      enableLocalDriveAccess = 0;
    };
    # Só serve o que já está no NAS: nada de baixar títulos
    download = {
      base = false;
      update = false;
      dlc = false;
      demo = false;
    };
  };
in
{
  imports = [ ./nas.nix ];

  dionix.nas.shares.data.path = "/data";

  systemd.services.nut = {
    description = "NUT: servidor de títulos do Switch";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    unitConfig.RequiresMountsFor = games;
    path = [ pkgs.rsync ];
    # O NUT grava na própria pasta: copia o código (sem apagar conf/, titledb/ e keys.txt)
    preStart = ''
      rsync -a --chmod=u+w --exclude=conf/nut.conf ${pkgs.nut}/share/nut/ ${state}/app/
      install -m644 ${nutConf} ${state}/app/conf/nut.conf
    '';
    serviceConfig = {
      ExecStart = "${pkgs.nut}/bin/nut-python ${state}/app/nut.py -S";
      WorkingDirectory = "${state}/app";
      StateDirectory = "nut";
      DynamicUser = true;
      # Lê os jogos do NAS (grupo media, somente leitura)
      SupplementaryGroups = [ "media" ];
      ReadOnlyPaths = [ games ];
      Restart = "on-failure";
    };
  };

  networking.firewall.allowedTCPPorts = [ 9000 ];
}
