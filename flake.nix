{
  description = "VimSeq - A Neovim-native knowledge base with bidirectional [[wiki links]], SQLite index, and Markdown support";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};

        vimseq = pkgs.vimUtils.buildVimPlugin {
          pname = "vimseq";
          version = "0.1.0";
          src = ./.;

          # sqlite.lua needs to find libsqlite3 at runtime
          # Propagate sqlite so it's available in the plugin's environment
          propagatedBuildInputs = [ pkgs.sqlite ];

          meta = with pkgs.lib; {
            description = "Neovim-native knowledge base with bidirectional wiki links and SQLite index";
            homepage = "https://github.com/nclaud/vimseq";
            license = licenses.mit;
            platforms = platforms.all;
          };
        };
      in
      {
        packages = {
          default = vimseq;
          vimseq = vimseq;
        };

        # Overlay for easy integration into other flakes
        overlays.default = final: prev: {
          vimPlugins = prev.vimPlugins // {
            vimseq = vimseq;
          };
        };

        # Dev shell with all dependencies for hacking on vimseq
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            neovim
            luajit
            sqlite
            lua-language-server
          ];

          shellHook = ''
            export LIBSQLITE="${pkgs.sqlite.out}/lib/libsqlite3.so"
          '';
        };
      }
    ) // {
      # System-independent overlay (for use in flake inputs)
      overlays.default = final: prev: {
        vimPlugins = prev.vimPlugins // {
          vimseq = final.vimUtils.buildVimPlugin {
            pname = "vimseq";
            version = "0.1.0";
            src = ./.;
            propagatedBuildInputs = [ final.sqlite ];

            meta = with final.lib; {
              description = "Neovim-native knowledge base with bidirectional wiki links and SQLite index";
              homepage = "https://github.com/nclaud/vimseq";
              license = licenses.mit;
              platforms = platforms.all;
            };
          };
        };
      };
    };
}
