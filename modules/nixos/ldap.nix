# Login central com o lldap: um servidor LDAP leve só para autenticação
# (usuários e grupos), usado pelo Nextcloud, Jellyfin, Grafana etc.
#
#   Painel web: ldap.<domínio> (pelo proxy) — usuários, grupos e senhas
#   LDAP:       ldaps://ldap.<domínio>:6360 (com o certificado curinga do ACME)
#               ou ldap://<ip-do-pi>:3890 (sem criptografia), base dc=vault76,dc=com,dc=br
#               bind de serviço: uid=<usuário>,ou=people,dc=vault76,dc=com,dc=br
#
# A senha do admin fica fora do repositório. Antes do primeiro start:
#   sudo install -Dm600 /dev/stdin /var/lib/secrets/lldap-admin-pass <<< 'senha-forte'
# O segredo dos tokens (JWT) é gerado sozinho na primeira execução.
# Dados em /var/lib/private/lldap (SQLite), incluído no backup.
{ config, lib, ... }:
let
  domain = config.dionix.proxy.domain;
  tls = config.dionix.proxy.acme.enable;
  cred = "/run/credentials/lldap.service";
  # dc=vault76,dc=com,dc=br a partir do domínio do proxy
  baseDn = lib.concatMapStringsSep "," (p: "dc=${p}") (lib.splitString "." domain);
in
{
  services.lldap = {
    enable = true;
    settings = {
      ldap_base_dn = baseDn;
      ldap_user_email = "admin@${domain}";
      http_url = "https://ldap.${domain}";
      # O painel só é acessado pelo Nginx local
      http_host = "127.0.0.1";
      # LDAPS com o mesmo certificado curinga do proxy
      ldaps_options = lib.mkIf tls {
        enabled = true;
        port = 6360;
        cert_file = "${cred}/cert";
        key_file = "${cred}/key";
      };
    };
    # Senha do admin entregue pelo systemd (o serviço roda com usuário dinâmico)
    environment.LLDAP_LDAP_USER_PASS_FILE = "/run/credentials/lldap.service/admin-pass";
    # A senha do arquivo só vale na criação do banco; depois, troque pelo painel
    silenceForceUserPassResetWarning = true;
  };

  systemd.services.lldap = {
    serviceConfig.LoadCredential = [
      "admin-pass:/var/lib/secrets/lldap-admin-pass"
    ]
    ++ lib.optionals tls [
      "cert:/var/lib/acme/${domain}/fullchain.pem"
      "key:/var/lib/acme/${domain}/key.pem"
    ];
    # Espera o certificado existir (até o primeiro pedido sair, é um autoassinado provisório)
    wants = lib.optional tls "acme-${domain}.service";
    after = lib.optional tls "acme-${domain}.service";
  };

  # Certificado renovado → o lldap relê
  security.acme.certs = lib.mkIf tls { ${domain}.reloadServices = [ "lldap.service" ]; };

  dionix.proxy.hosts.ldap = "http://127.0.0.1:17170";

  # LDAP para a rede de casa e a tailnet
  networking.firewall.allowedTCPPorts = [ 3890 ] ++ lib.optional tls 6360;
}
