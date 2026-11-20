# Endereços do homelab usados pelos papéis dos servidores. Importado por cada
# papel que precisa deles (o NixOS ignora importações repetidas).
{ lib, ... }:
{
  options.dionix.homelab = {
    domain = lib.mkOption {
      type = lib.types.str;
      default = "vault76.com.br";
      description = "Domínio dos serviços (<serviço>.<domínio>, publicados pelo proxy do Pi).";
    };
    pi = lib.mkOption {
      type = lib.types.str;
      default = "10.42.1.2";
      description = "Raspberry Pi: proxy reverso, DNS e LDAP.";
    };
    forge = lib.mkOption {
      type = lib.types.str;
      default = "10.42.1.3";
      description = "Host `forge`: servidor de desenvolvimento, na rede de casa.";
    };
    server = lib.mkOption {
      type = lib.types.str;
      default = "10.42.1.22";
      description = "Host `server` (NixOS direto no hardware), na rede de casa.";
    };
    serverMac = lib.mkOption {
      type = lib.types.str;
      default = "64:1c:67:73:ae:b1";
      description = "MAC da rede onboard do `server` (eno1), para o Wake-on-LAN.";
    };
    forgeMac = lib.mkOption {
      type = lib.types.str;
      default = "00:e0:4b:01:57:96";
      description = "MAC da rede cabeada do `forge`, para o Wake-on-LAN.";
    };
    cachePublicKey = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "forge-1:AAAA...=";
      description = ''
        Chave pública do cache binário do forge (/var/lib/secrets/cache-key.pub
        no forge). Com ela definida, o notebook usa https://cache.<domínio> como
        substituter. Nula na primeira aplicação, antes de a chave existir.
      '';
    };
  };
}
