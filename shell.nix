{ pkgs ? (import <nixpkgs> { }), ... }:
with pkgs;
let
  otp = beam.packages.erlang_27;
  elixir = otp.elixir_1_18;
  version = "0.16.61";
  hash = "sha256-ClQLzae+8xd9Jb9fGRJ3u/SAYSlk/bxgSITDxSIbS7U=";
  system = "x86_64-linux";
in
pkgs.mkShell {
  buildInputs = [
    elixir
    otp.erlang
    (tigerbeetle.overrideAttrs (old: {
      src = fetchzip {
        url = "https://github.com/tigerbeetle/tigerbeetle/releases/download/${version}/tigerbeetle-${system}.zip";
        inherit hash;
      };
    }))
  ];

  shellHook = ''
    # keep your shell history in iex
    export ERL_AFLAGS="-kernel shell_history enabled"

    # Force UTF8 in CLI
    export LANG="C.UTF-8"

    # this isolates mix to work only in local directory
    mkdir -p .nix-mix .nix-hex
    export MIX_HOME=$PWD/.nix-mix
    export HEX_HOME=$PWD/.nix-hex

    # make hex from Nixpkgs available
    # `mix local.hex` will install hex into MIX_HOME and should take precedence
    export MIX_PATH="${otp.hex}/lib/erlang/lib/hex/ebin"
    export PATH=$MIX_HOME/bin:$HEX_HOME/bin:$PATH
  '';
}
