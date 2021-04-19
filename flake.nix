{
  description = "Cardano Node";

  inputs = {
    haskellNix.url = "github:input-output-hk/haskell.nix";
    # Would rather use iohkNix/nixpkgs here but we may need to add a flake there first
    nixpkgs.follows = "haskellNix/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";
    iohkNix.url = "github:input-output-hk/iohk-nix/flake";
  };

  outputs = { self, nixpkgs, utils, haskellNix, iohkNix, ... }:
    let
      overlays = with iohkNix.overlays; [
        haskellNix.overlay
        haskell-nix-extra
        crypto
        cardano-lib
        (final: prev: {
          gitrev = self.rev or "dirty";
          commonLib = final.lib // final.cardano-lib;
        })
        (import ./nix/pkgs.nix)
      ];
    in utils.lib.eachSystem [ "x86_64-linux" "x86_64-darwin" ] (system:
      let
        pkgs = import nixpkgs { inherit system overlays; };
        flake = pkgs.cardanoNodeProject.flake {};
      in with pkgs; flake // {
        # Built by `nix build .`
        defaultPackage = flake.packages."cardano-node:exe:cardano-node";

        # This is used by `nix develop .` to open a devShell
        devShell = import ./shell.nix { inherit pkgs; };

        apps.repl = utils.lib.mkApp {
          drv = writeShellScriptBin "repl" ''
            confnix=$(mktemp)
            echo "builtins.getFlake (toString $(git rev-parse --show-toplevel))" >$confnix
            trap "rm $confnix" EXIT
            nix repl $confnix
          '';
        };
      }
    );
}
