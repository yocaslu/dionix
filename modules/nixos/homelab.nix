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
    server = lib.mkOption {
      type = lib.types.str;
      default = "10.42.1.20";
      description = "Host `server` (NixOS direto no hardware), na rede de casa.";
    };
  };
}
