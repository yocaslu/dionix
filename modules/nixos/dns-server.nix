# DNS da casa e da tailnet com o Technitium DNS Server.
#
# A configuração (zonas, bloqueio, encaminhadores) é feita no painel web e fica
# em /var/lib/private/technitium-dns-server: faça backup por lá (Settings → Backup).
# O painel não é exposto direto na rede: ele escuta na 5380 e é acessado pelo
# proxy reverso (dns.<domínio>, veja reverse-proxy.nix) ou por túnel SSH:
#   ssh -L 5380:localhost:5380 dio@pi   →   http://localhost:5380
{ ... }:
{
  services.technitium-dns-server = {
    enable = true;
    openFirewall = true;
    # Só o DNS fica aberto; 5380 (painel) e 53443 (painel HTTPS) ficam fechados
    firewallUDPPorts = [ 53 ];
    firewallTCPPorts = [ 53 ];
  };
}
