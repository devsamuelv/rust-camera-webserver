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
        # packages.jxl =
        #   with pkgs.clangStdenv;
        #   mkDerivation {
        #     pname = "jxl-lib";
        #     version = "1.0.0";
        #     src = nixpkgs.legacyPackages.x86_64-linux.fetchFromGitHub {
        #       owner = "libjxl";
        #       repo = "libjxl";
        #       rev = "8ce9537c989cfc7adff034556c8a4b9469e874d6";
        #       sha256 = "sha256-PHkk3Fe1WEoF1lJjKUsH7STcZUjr6y251g7oHAnHUME=";
        #     };

        #     buildInputs = [ pkgs.cmake pkgs.libhwy pkgs.brotli pkgs.libjpeg pkgs.libwebp skcms.packages.x86_64-linux.skcms ];
        #     cmakeFlags = [ ];
        #     nativeBuildInputs = [ ];
        #     buildPhase = ''
        #       export CC=clang CXX=clang++ PATH="$PATH:${skcms.packages.x86_64-linux.skcms.out}/libskcms.a"
        #       mkdir build
        #       cd build
        #       cmake -DCMAKE_BUILD_TYPE=Release -DBUILD_TESTING=OFF ..
        #       cmake --build . -- -j$(nproc)
        #     '';
        #   };

        packages.default = naersk-lib.buildPackage {
          src = ./.;
          buildInputs = [
            # Generic DevTools
            # clang-tools must be first before clang
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
            packages = [
              # Generic DevTools
              # clang-tools must be first before clang
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
