{
  description = "Surypus ERP/CRM - Haskell implementation with formal verification";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        haskellPackages = pkgs.haskellPackages.override {
          overrides = hself: hsuper: {
            surypus = hself.callCabal2nix "surypus" ./. {};
          };
        };

        ghcVersion = "966";

        stack-wrapped = pkgs.stack.override {
          ghc = pkgs.haskell.compiler.ghc${ghcVersion};
        };

      in
      {
        packages.default = haskellPackages.surypus;

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Haskell toolchain
            stack-wrapped
            haskell.compiler.ghc${ghcVersion}
            cabal-install
            haskell-language-server
            hlint
            fourmolu
            hpc-codecov
            ghcid
            pkgs.haskellPackages.criterion

            # Database
            postgresql_16
            libpqxx

            # Build tools
            gnumake
            pkg-config
            zlib
            gmp
            pcre
            libffi
            ncurses
            openssl

            # Documentation
            python311
            python311Packages.pip
            python311Packages.mkdocs
            python311Packages.mkdocs-material

            # Utilities
            git
            jq
            curl
            docker
            docker-compose
          ];

          shellHook = ''
            echo "Surypus Development Environment"
            echo "==============================="
            echo "GHC: $(ghc --version)"
            echo "Stack: $(stack --version)"
            echo "Cabal: $(cabal --version)"
            echo ""
            echo "Available commands:"
            echo "  stack build     - Build the project"
            echo "  stack test      - Run all tests"
            echo "  stack ghci      - Start REPL"
            echo "  stack haddock   - Generate documentation"
            echo "  fourmolu -i .   - Format all Haskell files"
            echo "  hlint src/      - Lint source files"
            echo "  docker compose up -d db - Start PostgreSQL"
            echo ""
          '';

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [
            zlib
            gmp
            pcre
            libffi
            ncurses
            openssl
            pkgs.stdenv.cc.cc.lib
          ];
        };

        # Docker image for CI/CD
        dockerImage = pkgs.dockerTools.buildLayeredImage {
          name = "surypus";
          tag = "latest";
          contents = [
            pkgs.bashInteractive
            pkgs.coreutils
            pkgs.cacert
            haskellPackages.surypus
          ];
          config = {
            Cmd = [ "${haskellPackages.surypus}/bin/surypus" ];
            ExposedPorts = {
              "8080/tcp" = {};
            };
          };
        };
      }
    );
}
