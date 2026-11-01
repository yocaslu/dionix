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
      description = "Raspberry Pi: proxy reverso, DNS, TURN e LDAP.";
    };
    server = lib.mkOption {
      type = lib.types.str;
      default = "10.0.76.8";
      description = "VM de serviços (host `server`), na LAN do pfSense.";
    };
  };
}
