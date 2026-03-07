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
    crane.url = "github:ipetkov/crane";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      naersk,
      crane
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
    }
    // flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = (
          import nixpkgs {
            inherit system;
          }
        );
        naersk-lib = pkgs.callPackage naersk { };

        craneLib = crane.mkLib pkgs;

        # Common arguments can be set here to avoid repeating them later
        # Note: changes here will rebuild all dependency crates
        commonArgs = {
          src = craneLib.cleanCargoSource ./.;
          strictDeps = true;
          DEP_JXL_LIB = "${pkgs.libjxl.out}";

          buildInputs = [
            # Add additional build inputs here
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
          ]
          ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
            # Additional darwin specific inputs can be set here
            pkgs.libiconv
          ];
        };

        my-crate = craneLib.buildPackage (
          commonArgs
          // {
            cargoArtifacts = craneLib.buildDepsOnly commonArgs;

            # Additional environment variables or build phases/hooks can be set
            # here *without* rebuilding all dependency crates
            # MY_CUSTOM_VAR = "some value";
          }
        );
      in
      {
        # The naersk build breaks libcamera for some unknown reason.
        # packages.default = naersk-lib.buildPackage {
        #   src = ./.;
        #   DEP_JXL_LIB = "${pkgs.libjxl.out}";
        #   LIBCLANG_PATH = pkgs.lib.makeLibraryPath [ pkgs.llvmPackages_latest.libclang.lib ];
        #   PORT = 3001;

          # buildInputs = [
          #   # Generic DevTools
          #   # clang-tools must be first before clang
          #   pkgs.pkg-config
          #   pkgs.clang
          #   pkgs.gcc
          #   pkgs.libgcc
          #   pkgs.clang-tools
          #   pkgs.rust-bindgen
          #   pkgs.libjxl
          #   pkgs.libllvm
          #   pkgs.libclang
          #   pkgs.libcamera
          # ];
        # };
        packages.default = my-crate;

        packages.sdcard = self.nixosConfigurations.orangepi5plus.config.system.build.sdImage;

        devShells.default =
          with pkgs;
          mkShell {
            buildInputs = [
              cargo
              rustc
              rustfmt
              pre-commit
              rustPackages.clippy
            ];
            RUST_SRC_PATH = rustPlatform.rustLibSrc;
            DEP_JXL_LIB = "${pkgs.libjxl.out}";
            LIBCLANG_PATH = pkgs.lib.makeLibraryPath [ pkgs.llvmPackages_latest.libclang.lib ];

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
