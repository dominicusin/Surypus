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
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Haskell toolchain
            stack
            cabal-install
            haskell-language-server
            hlint
            fourmolu
            ghcid
            haskellPackages.criterion

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

          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath (with pkgs; [
            zlib
            gmp
            pcre
            libffi
            ncurses
            openssl
            stdenv.cc.cc.lib
          ]);
        };
      }
    );
}
