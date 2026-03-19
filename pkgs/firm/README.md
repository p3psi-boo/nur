# Firm Nix Package

This directory contains a Nix package definition for [Firm](https://github.com/42futures/firm), a text-based work management system for technologists.

## About Firm

Firm is a business-as-code system that allows you to:
- Define your business entities in plain text files using the Firm DSL
- Build a unified graph of your business relationships
- Query and automate your business processes
- Own your data locally with version control

## Installation

Add this to your Nix configuration flake.nix:

```nix
{
  inputs = {
    # ... other inputs
  };

  outputs = { self, nixpkgs, nur, ... }: {
    nixosConfigurations.example = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          nixpkgs.overlays = [ nur.overlays.default ];
          environment.systemPackages = [ pkgs.firm ];
        })
      ];
    };
  };
}
```

Then you can install it with:
```bash
nix profile install .#firm
```

Or use it in your configuration:
```nix
environment.systemPackages = with pkgs; [
  firm
];
```

## Usage

After installation, you can use the `firm` CLI:

```bash
# Initialize a new workspace
mkdir my-workspace && cd my-workspace

# Add an entity
firm add

# List entities
firm list organization

# Get entity details
firm get person john_doe

# Explore relationships
firm related organization megacorp
```

## Package Details

- **Version**: 0.3.0
- **License**: AGPL-3.0+
- **Platforms**: Linux and macOS
- **Main Program**: `firm`

The package includes:
- `firm-cli` - Command-line interface for interacting with Firm workspaces
- `firm_core` - Core data structures and graph operations
- `firm_lang` - DSL parsing and generation