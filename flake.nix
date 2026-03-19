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
  };

  outputs = inputs@{ self, nixpkgs, ... }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = lib.genAttrs systems;

      pkgsFor = system:
        import nixpkgs {
          inherit system;
          config = {
            allowUnfree = true;
            permittedInsecurePackages = [
              "openssl-1.1.1w"
            ];
          };
          overlays = [ self.overlays.default ];
        };
    in
    {
      overlays.default = import ./overlay.nix { inherit inputs; };
      overlay = self.overlays.default;

      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
          repo = import ./default.nix { inherit pkgs; };
        in
        repo // {
          default = pkgs.lazyssh;
        }
      );

      checks = forAllSystems (
        system:
        import ./ci.nix {
          pkgs = pkgsFor system;
        }
      );

      legacyPackages = forAllSystems pkgsFor;

      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              git
              jq
              yq
              nurl
              nvfetcher
            ];
          };
        }
      );
    };
}
