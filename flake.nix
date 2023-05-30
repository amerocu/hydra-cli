{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.11";
    flakeu.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flakeu }: let
    overlay = final: prev: with final.pkgs.lib; {
      hydra-cli = prev.hydra-cli.overrideAttrs(oa: {
        version = (importTOML ./Cargo.toml).package.version + "-" + self.shortRev or "unstable";
        src = self;
        cargoDeps = final.pkgs.rustPlatform.importCargoLock {
          lockFile = ./Cargo.lock;
        };
        postPatch = ''
          ln -sf ${./Cargo.lock} Cargo.lock
        '';
      });
    };
    in

    flakeu.lib.eachSystem [flakeu.lib.system.x86_64-linux] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            overlay
          ];
        };

        crateName = "hydra-cli";

      in {
        packages = with pkgs; {
          inherit hydra-cli;
          default = hydra-cli;
        };

        apps = rec {
          hydra-cli = flakeu.lib.mkApp { drv = self.packages.${system}.${crateName}; };
          default = hydra-cli;
        };

        legacyPackages = nixpkgs.legacyPackages.${system};

        devShells = rec {
          hydra-cli = pkgs.mkShell {
            inputsFrom = builtins.attrValues self.packages.${system};
            buildInputs = [ pkgs.cargo pkgs.rust-analyzer pkgs.clippy ];
            nativeBuildInputs = [
              pkgs.openssl
              pkgs.pkg-config
            ];
          };
          default = hydra-cli;
        };
        checks = {
          vm = pkgs.callPackage ./tests/vm.nix { hydra-cli = self.packages.${system}.${crateName}; };
        };
      }) // {
        overlays.default = overlay;
      };
}

