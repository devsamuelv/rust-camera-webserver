{
  description = "A very basic flake";

  inputs = {
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    naersk = {
      url = "github:nix-community/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      naersk
    }:
    {
      nixosConfigurations = {
        orangepi5plus = nixpkgs.lib.nixosSystem {
          system = "aarch64-linux";
          modules = [
            ./sdcard.nix
            ./hardware-configuration.nix
            ./configuration.nix
            {
              nixpkgs.buildPlatform = "x86_64-linux";
              nixpkgs.hostPlatform = "aarch64-linux";
            }
          ];
          specialArgs = {
            inherit nixpkgs;
          };
        };
      };
    } // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = (
          import nixpkgs {
            inherit system;
          }
        );
        naersk-lib = pkgs.callPackage naersk {};
      in
      {
        # The naersk build breaks libcamera for some unknown reason.
        packages.default = naersk-lib.buildPackage {
          src = ./.;
          DEP_JXL_LIB = "${pkgs.libjxl.out}";
          LIBCLANG_PATH = pkgs.lib.makeLibraryPath [pkgs.llvmPackages_latest.libclang.lib];
          PORT = 3001;

          buildInputs = [
            # Generic DevTools
            # clang-tools must be first before clang
            pkgs.pkg-config
            pkgs.clang
            pkgs.gcc
            pkgs.libgcc
            pkgs.clang-tools
            pkgs.rust-bindgen
            pkgs.libjxl
            pkgs.libllvm
            pkgs.libclang
            pkgs.libcamera
          ];
        };

        packages.sdcard = self.nixosConfigurations.orangepi5plus.config.system.build.sdImage;

        devShells.default =
          with pkgs;
          mkShell {
            buildInputs = [ cargo rustc rustfmt pre-commit rustPackages.clippy ];
            RUST_SRC_PATH = rustPlatform.rustLibSrc;
            CLANG = "${pkgs.libclang.out}";
            DEP_JXL_LIB = "${pkgs.libjxl.out}";
            LIBCLANG_PATH = pkgs.lib.makeLibraryPath [pkgs.llvmPackages_latest.libclang.lib];

            packages = [
              # Generic DevTools
              # clang-tools must be first before clang
              (pkgs.writeShellScriptBin "_exec" ''
                #!/bin/bash
                export PORT=3001
                cargo run --release
              '')
              pkgs.pkg-config
              pkgs.clang-tools
              pkgs.libjxl
              pkgs.libllvm
              pkgs.libclang
              pkgs.rust-bindgen
              pkgs.libcamera
              pkgs.nixfmt
            ];
          };
      }
    );
}
