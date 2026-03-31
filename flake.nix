{
  description = "bubu's NUR-style package repository";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
    };

    bun2nix = {
      url = "github:nix-community/bun2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      packageSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      checkSystems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllPackageSystems = lib.genAttrs packageSystems;
      forAllCheckSystems = lib.genAttrs checkSystems;
      nixpkgsConfig = import ./nix/config/nixpkgs.nix;

      pkgsFor = system:
        import nixpkgs {
          inherit system;
          config = nixpkgsConfig;
          overlays = [
            inputs.bun2nix.overlays.default
            self.overlays.default
          ];
        };
    in
    {
      overlays.default = import ./overlay.nix { inherit inputs; };
      overlay = self.overlays.default;

      packages = forAllPackageSystems (
        system:
        let
          pkgs = pkgsFor system;
          repo = import ./repo.nix { inherit pkgs; };
        in
        repo // {
          default = pkgs.lazyssh;
        }
      );

      checks = forAllCheckSystems (
        system:
        import ./nix/config/ci.nix {
          pkgs = pkgsFor system;
        }
      );

      legacyPackages = forAllPackageSystems pkgsFor;

      devShells = forAllPackageSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              git
              jq
              yq
              nurl
              nvfetcher
              inputs.bun2nix.packages.${system}.default
            ];
          };
        }
      );
    };
}
