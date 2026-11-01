# Backup diário com restic para o Google Drive (pelo rclone). Cada host tem o
# próprio repositório em gdrive:homelab/<host>; o restic criptografa tudo
# antes de enviar, então o Drive só vê blocos cifrados.
#
# Segredos (fora do repositório, criados à mão em cada host):
#   /var/lib/secrets/rclone.conf      remote "gdrive" (gerado com `rclone config`, veja o README)
#   /var/lib/secrets/restic-password  senha do repositório: guarde uma cópia fora do homelab!
#
# Comandos (wrapper com as variáveis já definidas):
#   sudo restic-gdrive snapshots
#   sudo restic-gdrive restore latest --target /tmp/restore
#   sudo systemctl start restic-backups-gdrive   # roda agora
{
  config,
  lib,
  hostname,
  ...
}:
let
  cfg = config.dionix.backup;
in
{
  options.dionix.backup = {
    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Pastas copiadas para o Google Drive.";
    };
    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Padrões ignorados (sintaxe do restic --exclude).";
    };
    prepare = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Comandos rodados antes do backup (ex.: dump de banco para uma das pastas).";
    };
  };

  config = lib.mkIf (cfg.paths != [ ]) {
    services.restic.backups.gdrive = {
      initialize = true;
      repository = "rclone:gdrive:homelab/${hostname}";
      rcloneConfigFile = "/var/lib/secrets/rclone.conf";
      passwordFile = "/var/lib/secrets/restic-password";
      inherit (cfg) paths exclude;
      backupPrepareCommand = lib.mkIf (cfg.prepare != "") cfg.prepare;
      # Diário de madrugada, com atraso aleatório; roda no boot se perdeu o horário
      timerConfig = {
        OnCalendar = "03:00";
        RandomizedDelaySec = "1h";
        Persistent = true;
      };
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 6"
      ];
      # Checa uma amostra dos dados a cada execução
      checkOpts = [ "--read-data-subset=1%" ];
      # Menos chamadas à API do Drive (limite de requisições)
      rcloneOptions.drive-chunk-size = "64M";
    };
  };
}
