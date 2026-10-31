# Overlay do dionix.
#   pkgs.unstable.<pacote>  pacote do nixos-unstable, para casos pontuais
#   pkgs.tmuxPlugins.ping / .cargo  plugins do tmux que não estão no nixpkgs
{ inputs }:
final: prev: {
  unstable = import inputs.nixpkgs-unstable {
    inherit (final.stdenv.hostPlatform) system;
    config.allowUnfree = true;
  };

  tmuxPlugins = prev.tmuxPlugins // {
    ping = prev.tmuxPlugins.mkTmuxPlugin {
      pluginName = "ping";
      rtpFilePath = "ping.tmux";
      version = "unstable-${inputs.tmux-ping.shortRev or "dirty"}";
      src = inputs.tmux-ping;
    };
    cargo = prev.tmuxPlugins.mkTmuxPlugin {
      pluginName = "cargo";
      rtpFilePath = "tmux_cargo.tmux";
      version = "unstable-${inputs.tmux-cargo.shortRev or "dirty"}";
      src = inputs.tmux-cargo;
    };
  };
}
