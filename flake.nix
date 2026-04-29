{
  description = "nebula root flake - inventory-driven NixOS config with Colmena";

  inputs = {
    # Pinned to a known-good nixpkgs commit for reproducibility
    nixpkgs.url = "github:NixOS/nixpkgs/b86751bc4085f48661017fa226dee99fab6c651b";

    # Colmena — main branch (needed for flake-native features including colmenaHive output).
    colmena.url = "github:zhaofengli/colmena";
    colmena.inputs.nixpkgs.follows = "nixpkgs";

    # Disk tooling
    disko.url = "git+https://github.com/nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # sops-nix for secrets integration
    sops-nix.url = "git+https://github.com/Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    # Local role/profile flakes (path-based)
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    testing = {
      url = "path:./roles/testing";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    security-host = {
      url = "path:./modules/security-host";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Feature modules (composable, added to host modules in inventory)
    web-utils = {
      url = "path:./modules/web-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    maintenance = {
      url = "path:./modules/maintenance";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, colmena, disko, sops-nix, home-manager, ... } @ inputs:
  let
    # inventory is the single source of truth for all instances in the fleet
    inventory = builtins.fromJSON (builtins.readFile ./inventory/machines.json);

    # mkHost builds a NixOS module fragment for each instance defined in the inventory.
    # It:
    #  - imports host-specific configuration.nix (keyed by machine.hostname, not instance ID)
    #  - adds common modules (disko, sops, home-manager)
    #  - imports the role flake (os.role) then any additional feature modules (os.modules)
    #  - passes the whole machine object as _module.args.machine so role flakes can be generic
    mkHost = name: machine: {
      imports = [
        ./hosts/${machine.hostname}/configuration.nix
        disko.nixosModules.disko
        sops-nix.nixosModules.sops
        home-manager.nixosModules.home-manager
        # Pin colmena binary to the same version as the flake input so that
        # `colmena apply-local` on the host always matches the colmenaHive schema.
        ({ pkgs, ... }: {
          environment.systemPackages = [ colmena.packages.${pkgs.system}.colmena ];
        })
      ] ++ [ inputs.${machine.os.role}.nixosModules.default ]
        ++ (map (mod: inputs.${mod}.nixosModules.default) machine.os.modules);

      # Set the host platform via the modern NixOS option rather than the deprecated
      # `system` argument to nixosSystem/Colmena meta. This suppresses the
      # "'system' has been renamed to nixpkgs.hostPlatform" evaluation warning.
      nixpkgs.hostPlatform = systemFor machine;

      # Pass arguments to modules produced by flakes in `modules`.
      _module.args = {
        inherit inputs;
        primaryUser = builtins.head machine.users.admin;
        machine = machine; # whole instance object — role flakes read hardware.disk.*, os.*, users.*, etc.
      };

      # Provide home-manager with helpful extra args so home-manager fragments can access inputs and primaryUser.
      # This makes the module's `homeManagerModules.default` available and parameterized per-host.
      home-manager.extraSpecialArgs = { inherit inputs; primaryUser = builtins.head machine.users.admin; };

      networking.hostName = machine.hostname;
    };

    # Colmena host wrapper: extends mkHost with deployment.* options.
    # These options are injected by Colmena's own module system and MUST NOT appear in
    # nixosConfigurations (which doesn't load that module) or evaluation will error.
    mkColmenaHost = name: machine: {
      imports = [ (mkHost name machine) ];
      deployment = {
        # SSH address — set address in inventory/instances (static IP recommended).
        targetHost           = machine.address;
        targetUser           = builtins.head machine.users.admin;
        tags                 = machine.tags or [];
        # Allows `colmena apply-local` to be run directly on the target machine itself.
        # Useful when deploying from testbed (no remote Nix host required).
        allowLocalDeployment = true;
        # Build the closure on the target; avoids needing a local Nix store.
        buildOnTarget        = true;
      };
    };

    # Colmena host map — uses mkColmenaHost so deployment.* options are present.
    # nixosConfigurations (below) calls mkHost directly, stays free of Colmena options.
    hosts = builtins.mapAttrs mkColmenaHost inventory.instances;

    # os.system is already a valid Nix system string (e.g. x86_64-linux) — used directly.
    systemFor = machine: machine.os.system;
  in {
    # Colmena expects a top-level attribute containing a `meta` attr (nixpkgs + specialArgs)
    # and then the host entries. We compose that by merging `meta` with our `hosts` map.
    #
    # NOTE: The `colmena` attribute below is the *hive configuration* (legacy output name).
    # The `colmenaHive` attribute wraps it via `colmena.lib.makeHive` — this is the output
    # that modern colmena (main branch, Nix 2.21+ pure mode) actually reads by default.
    # The legacy `colmena` output requires `--legacy-flake-eval` on Nix 2.21+ and is kept
    # only as source data for `colmena.lib.makeHive`.
    colmena = {
      meta = {
        # Provide a fixed evaluation of nixpkgs for the colmena build environment
        nixpkgs = import nixpkgs { system = "x86_64-linux"; };
        # Forward all inputs so role flakes can import nested inputs if needed
        specialArgs = inputs;
      };
    } // hosts;

    # colmenaHive is the output that colmena main branch reads by default (Nix 2.21+ pure mode).
    # It wraps the `colmena` hive configuration above via colmena.lib.makeHive.
    colmenaHive = colmena.lib.makeHive self.outputs.colmena;

    # nixosConfigurations must hold nixpkgs.lib.nixosSystem results so that
    # `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` works.
    nixosConfigurations = builtins.mapAttrs (name: machine:
      nixpkgs.lib.nixosSystem {
        modules = [ (mkHost name machine) ];
        # Make all flake inputs available as module args (same as Colmena's specialArgs above).
        specialArgs = inputs;
      }
    ) inventory.instances;
  };
}
