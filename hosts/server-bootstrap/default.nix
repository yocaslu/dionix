# Sistema mínimo gravado no HD do server pelo desktop (docs/homelab.md): só rede
# e SSH, sem serviços e sem os discos do pool. Serve para criar o pool no server e
# aplicar o `.#server` por cima; subir os serviços sem o pool faria o Nextcloud e
# o resto gravarem no ext4, por baixo dos pontos de montagem.
{ lib, ... }:
{
  imports = [ ../server/base.nix ];

  networking.hostName = lib.mkForce "server";

  # Ainda não há senha: o primeiro passo no server é definir a do dio com
  # `sudo passwd dio`, porque o `.#server` volta a exigi-la no sudo.
  security.sudo.wheelNeedsPassword = false;
}
