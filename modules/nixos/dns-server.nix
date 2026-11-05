# DNS da casa e da tailnet com o Technitium DNS Server.
#
# A configuração (bloqueio, encaminhadores) é feita no painel web e fica
# em /var/lib/private/technitium-dns-server: faça backup por lá (Settings → Backup).
# O painel não é exposto direto na rede: ele escuta na 5380 e é acessado pelo
# proxy reverso (dns.<domínio>, veja reverse-proxy.nix) ou por túnel SSH:
#   ssh -L 5380:localhost:5380 dio@pi   →   http://localhost:5380
#
# A zona do domínio (dionix.dns.zone) é criada pela API, com o token em
# /var/lib/secrets/technitium-token (veja docs/homelab.md). Registros tirados
# da lista não são apagados: remova-os pelo painel.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.dionix.dns;
  api = "http://127.0.0.1:5380/api";
  token = "/var/lib/secrets/technitium-token";

  fqdn = name: if name == "@" then cfg.zone else "${name}.${cfg.zone}";
  registro = name: ip: ''
    chamar zones/records/add --data-urlencode "domain=${fqdn name}" \
      --data-urlencode "type=A" --data-urlencode "ipAddress=${ip}" \
      --data-urlencode "ttl=300" --data-urlencode "overwrite=true" >/dev/null
  '';
in
{
  options.dionix.dns = {
    zone = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "vault76.com.br";
      description = "Zona primária criada no Technitium (DNS split-horizon do domínio).";
    };
    records = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = {
        "@" = "10.42.1.2";
        "*" = "10.42.1.2";
      };
      description = "Registros A da zona (nome → IP; `@` é a própria zona e `*` o curinga).";
    };
  };

  config = {
    services.technitium-dns-server = {
      enable = true;
      openFirewall = true;
      # Só o DNS fica aberto; 5380 (painel) e 53443 (painel HTTPS) ficam fechados
      firewallUDPPorts = [ 53 ];
      firewallTCPPorts = [ 53 ];
    };

    # Cria a zona e os registros pela API (idempotente; roda a cada mudança da lista)
    systemd.services.technitium-zona = lib.mkIf (cfg.zone != null) {
      description = "Zona ${cfg.zone} no Technitium";
      wantedBy = [ "multi-user.target" ];
      after = [ "technitium-dns-server.service" ];
      requires = [ "technitium-dns-server.service" ];
      path = with pkgs; [
        curl
        jq
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        if [ ! -s ${token} ]; then
          echo "sem ${token}: crie o token da API (docs/homelab.md) e reinicie este serviço"
          exit 0
        fi

        # GET na API com o token; falha se a resposta não for "ok"
        chamar() {
          rota=$1; shift
          resposta=$(curl -sS --fail --retry 10 --retry-connrefused --retry-delay 3 --get \
            "${api}/$rota" --data-urlencode "token=$(cat ${token})" "$@")
          status=$(jq -r .status <<< "$resposta")
          if [ "$status" != ok ]; then
            echo "$rota: $(jq -r '.errorMessage // .status' <<< "$resposta")" >&2
            return 1
          fi
          printf '%s' "$resposta"
        }

        zonas=$(chamar zones/list) || {
          echo "o Technitium recusou ${token}: gere outro token (docs/homelab.md)" >&2
          exit 1
        }
        if ! jq -e '.response.zones[] | select(.name == "${cfg.zone}")' <<< "$zonas" >/dev/null; then
          chamar zones/create --data-urlencode "zone=${cfg.zone}" --data-urlencode "type=Primary" >/dev/null
          echo "zona ${cfg.zone} criada"
        fi

        ${lib.concatStrings (lib.mapAttrsToList registro cfg.records)}
        echo "registros de ${cfg.zone}: ${lib.concatStringsSep ", " (lib.attrNames cfg.records)}"
      '';
    };
  };
}
