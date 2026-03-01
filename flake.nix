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
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      naersk
    }:
    flake-utils.lib.eachDefaultSystem (
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
        packages.default = naersk-lib.buildPackage {
          src = ./.;
          DEP_JXL_LIB = "${pkgs.libjxl.out}";

          buildInputs = [
            # Generic DevTools
            # clang-tools must be first before clang
            pkgs.pkg-config
            pkgs.clang
            pkgs.gcc
            pkgs.clang-tools
            pkgs.libjxl
            pkgs.libllvm
            pkgs.libclang
            pkgs.libcamera
          ];
        };

        devShells.default =
          with pkgs;
          mkShell {
            buildInputs = [ cargo rustc rustfmt pre-commit rustPackages.clippy ];
            RUST_SRC_PATH = rustPlatform.rustLibSrc;
            CLANG = "${pkgs.libclang.out}";
            DEP_JXL_LIB = "${pkgs.libjxl.out}";

            packages = [
              # Generic DevTools
              # clang-tools must be first before clang
              pkgs.pkg-config
              pkgs.clang-tools
              pkgs.libjxl
              pkgs.libllvm
              pkgs.libclang
              pkgs.libcamera
              pkgs.nixfmt
            ];
          };
      }
    );
}
