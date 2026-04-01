{
  description = "A very basic flake";

  inputs = {
    flake-utils = {
      url = "github:numtide/flake-utils";
    };
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-25.11";
    crane.url = "github:ipetkov/crane";

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      rust-overlay,
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
        crossSystem = "aarch64-linux";
        pkgs = (
          import nixpkgs {
            inherit crossSystem system;
            overlays = [ (import rust-overlay) ];
          }
        );

        craneLib = crane.mkLib pkgs;
        crateExpression =
          {
            openssl,
            libiconv,
            lib,
            pkg-config,
            stdenv,
          }:
          craneLib.buildPackage {
            src = craneLib.cleanCargoSource ./.;
            DEP_JXL_LIB = "${pkgs.libjxl.out}";
            LIBCLANG_PATH = pkgs.lib.makeLibraryPath [ pkgs.llvmPackages_latest.libclang.lib ];
            strictDeps = true;

            # Dependencies which need to be build for the current platform
            # on which we are doing the cross compilation. In this case,
            # pkg-config needs to run on the build platform so that the build
            # script can find the location of openssl. Note that we don't
            # need to specify the rustToolchain here since it was already
            # overridden above.
            nativeBuildInputs = with pkgs; [
              pkg-config
              clang-tools
              libgcc
              clang
              libllvm
              libclang
              gcc
              rust-bindgen
            ]
            ++ lib.optionals stdenv.buildPlatform.isDarwin [
              libiconv
            ];

            # Dependencies which need to be built for the platform on which
            # the binary will run. In this case, we need to compile openssl
            # so that it can be linked with our executable.
            buildInputs = [
              # Add additional build inputs here
              openssl
            ];
          };

        # Common arguments can be set here to avoid repeating them later
        # Note: changes here will rebuild all dependency crates
        # commonArgs = {
        #   src = craneLib.cleanCargoSource ./.;
        #   strictDeps = true;
        #   DEP_JXL_LIB = "${pkgs.libjxl.out}";
        #   LIBCLANG_PATH = pkgs.lib.makeLibraryPath [ pkgs.llvmPackages_latest.libclang.lib ];

        #   nativeBuildInputs = with pkgs; [
        #     # Add extra native build inputs here, etc.
        #     # pkg-config
        #     pkgs.pkg-config
        #     pkgs.clang-tools
        #     pkgs.libgcc
        #     pkgs.clang
        #     pkgs.libllvm
        #     pkgs.libclang
        #     pkgs.gcc
        #     pkgs.rust-bindgen
        #   ];

        #   buildInputs = [
        #     # Add additional build inputs here
        #     pkgs.libjxl
        #     pkgs.libcamera
        #   ]
        #   ++ pkgs.lib.optionals pkgs.stdenv.isDarwin [
        #     # Additional darwin specific inputs can be set here
        #     pkgs.libiconv
        #   ];
        # };

        my-crate = pkgs.callPackage crateExpression { };
      in
      {
        packages.default = my-crate;

        packages.sdcard = self.nixosConfigurations.orangepi5plus.config.system.build.sdImage;

        apps.default = flake-utils.lib.mkApp {
          drv = pkgs.writeScriptBin "my-app" ''
            ${pkgs.pkgsBuildBuild.qemu}/bin/qemu-aarch64 ${my-crate}/bin/cross-rust-overlay
          '';
        };

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
