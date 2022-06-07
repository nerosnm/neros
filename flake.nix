{
  description = "Server configuration flake for neros.dev, cacti.dev, etc.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";

    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "utils";
    };

    secrets = {
      url = "git+ssh://git@github.com/nerosnm/secrets.git?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "utils";
    };

    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "utils";
    };

    hatysa = {
      url = "github:nerosnm/hatysa/master";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "utils";
      inputs.rust-overlay.follows = "rust-overlay";
    };

    oxbow = {
      url = "github:nerosnm/oxbow/main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "utils";
      inputs.rust-overlay.follows = "rust-overlay";
    };

    pomocop = {
      url = "github:nerosnm/pomocop/main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "utils";
      inputs.rust-overlay.follows = "rust-overlay";
    };

    cacti-dev = {
      url = "github:nerosnm/cacti.dev/main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "utils";
      inputs.rust-overlay.follows = "rust-overlay";
    };

    neros-dev = {
      url = "git+ssh://git@github.com/nerosnm/neros.dev.git?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "utils";
      inputs.rust-overlay.follows = "rust-overlay";
    };
  };

  outputs =
    { self
    , nixpkgs
    , utils
    , deploy-rs
    , secrets
    , rust-overlay
    , ...
    } @ inputs:
    let
      inherit (builtins) concatMap listToAttrs mapAttrs;
      inherit (nixpkgs.lib) attrNames getAttr nixosSystem;
      inherit (utils.lib) eachDefaultSystem;

      # Turn an attr set into a list by getting the value of each key. Honestly, 
      # why isn't this in nixpkgs.lib? Or am I missing something?
      attrsToList = set: map (key: getAttr key set) (attrNames set);

      # Import nixpkgs for the given system. Applies the necessary overlays so 
      # that custom packages can be seen, etc.
      pkgsFor = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
        overlays = [
          (final: prev: {
            cacti-dev = inputs.cacti-dev.defaultPackage.${system};
            hatysa = inputs.hatysa.packages.${system}.default;
            neros-dev = inputs.neros-dev.packages.${system}.neros-dev;
            neros-dev-wip = inputs.neros-dev.packages.${system}.neros-dev-wip;
            oxbow = inputs.oxbow.defaultPackage.${system};
            oxbow-cacti-dev = inputs.oxbow.packages.${system}.oxbow-cacti-dev;
            pomocop = inputs.pomocop.defaultPackage.${system};
          })
        ];
      };

      secret = {
        inherit (secrets.nixosModules.secret) grafana hatysa oxbow pomocop tailscale;
      };

      service = {
        # Websites
        cacti-dev = import ./service/cacti-dev.nix;
        neros-dev = import ./service/neros-dev.nix;

        # Custom software
        hatysa = import ./service/hatysa.nix;
        oxbow = import ./service/oxbow.nix;
        pomocop = import ./service/pomocop.nix;

        # Minecraft servers
        marsic = import ./service/marsic.nix;
        megrez = import ./service/megrez.nix;
        syrma = import ./service/syrma.nix;
        tarazed = import ./service/tarazed.nix;

        # Monitoring
        grafana = import ./service/grafana.nix;
        prometheus = import ./service/prometheus.nix;

        # Networking
        tailscale = import ./service/tailscale.nix;
      };

      trait = {
        # Sets up a group and homedir parent for services that need a user with 
        # a home in /srv/cacti.
        cacti = import ./trait/cacti.nix;

        # Allows the creation of secrets encrypted with a server's host key.
        secrets = import ./trait/secrets.nix;
      };

      # Gather all the secrets, services and traits together in a list, so they 
      # can be imported by every host and then enabled as needed through 
      # `config`.
      baseModules = concatMap attrsToList [ secret service trait ];

      # Helper function to create a NixOS server configuration without having to 
      # specify a bunch of redundant stuff every time.
      server = hostname: config:
        nixosSystem rec {
          system = "x86_64-linux";
          pkgs = pkgsFor system;
          modules = baseModules ++ [
            ./platform/${hostname}.nix
            config
          ];
        };

      # Helper function to remove some of the redundancy of creating an attr set 
      # of servers. Calls `server` on each element of the set, using the key of 
      # each element as the hostname.
      servers = mapAttrs (hostname: config: server hostname config);

      # Helper function to make it a little easier to set up a deploy-rs node 
      # for a Linux server with just a single system profile. Automatically uses 
      # the nixosConfigurations member with the provided hostname as the config 
      # for that profile.
      node = hostname: {
        inherit hostname;
        profiles = {
          system = {
            user = "root";
            path = deploy-rs.lib.x86_64-linux.activate.nixos
              self.nixosConfigurations.${hostname};
          };
        };
      };

      # Apply a function f to `name`, inserting the result under `value` in an 
      # attrset also containing `name`.
      mapNamed = f: name: { inherit name; value = f name; };

      # Helper function in the same vein as `servers`. Converts a list of 
      # hostname strings to an attrset mapping each hostname to its node config.
      nodes = hostnames: listToAttrs (map (mapNamed node) hostnames);
    in
    {
      nixosConfigurations = servers {
        taygeta = { config, ... }: {
          config.cacti = {
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKnAKrUqhfVaoAbhAJutnAsXwrKfPfmBPI19AuYkSbBY root@taygeta";

            services = {
              enable = true;

              # Websites
              cacti-dev.enable = true;
              neros-dev.enable = true;
              neros-dev.wip.enable = true;

              # Custom software
              hatysa.enable = true;
              oxbow.enable = true;
              pomocop.enable = true;

              # Monitoring
              grafana.enable = true;
              prometheus = {
                enable = true;
                nodeExporter.enable = true;
              };

              # Networking
              tailscale = {
                enable = true;
                authKey = config.nerosnm.secrets.tailscale.taygeta;
              };
            };
          };
        };

        marsic = { config, ... }: {
          config.cacti = {
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFv+FfTb6+8dFM2NSubKP6O6xKQg69tZqjBRNBlCSRXg root@nixos";

            services = {
              enable = true;

              # Minecraft server
              marsic = {
                enable = true;
                memory = 5632;
                # temp world seed was: -2857313200842167840
              };

              # Monitoring
              prometheus.nodeExporter.enable = true;

              # Networking
              tailscale = {
                enable = true;
                trustInterface = true;
                authKey = config.nerosnm.secrets.tailscale.marsic;
              };
            };
          };
        };

        syrma = { config, ... }: {
          config.cacti = {
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHS3fcwk5DX94CnOKg0nJrYaQJNKHEkssGocGjiII5Zq root@nixos";

            services = {
              enable = true;

              # Minecraft server
              syrma = {
                enable = false;
                memory = 3072;
              };

              # Monitoring
              prometheus.nodeExporter.enable = true;

              # Networking
              tailscale = {
                enable = true;
                trustInterface = true;
                authKey = config.nerosnm.secrets.tailscale.syrma;
              };
            };
          };
        };

        megrez = { config, ... }: {
          config.cacti = {
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH3+XtOM9xdAtGw7m/uhvIpqR2S4XZosxXK3laL1Djkx root@nixos";

            services = {
              enable = true;

              # Minecraft server
              megrez = {
                enable = true;
                memory = 5632;
              };

              # Monitoring
              prometheus.nodeExporter.enable = true;

              # Networking
              tailscale = {
                enable = true;
                trustInterface = true;
                authKey = config.nerosnm.secrets.tailscale.megrez;
              };
            };
          };
        };

        tarazed = { config, ... }: {
          config.cacti = {
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPD6d0Ydn2bs6XfSUuB8RWfaqfKw6mIgjHNdZPYXjX21 root@nixos";

            services = {
              enable = true;

              tarazed = {
                enable = true;
                memory = 5120;
              };

              # Monitoring
              prometheus.nodeExporter.enable = true;

              # Networking
              tailscale = {
                enable = true;
                trustInterface = true;
                authKey = config.nerosnm.secrets.tailscale.tarazed;
              };
            };
          };
        };
      };

      deploy = {
        nodes = nodes [
          "taygeta"
          "marsic"
          "syrma"
          "megrez"
          "tarazed"
        ];
        sshUser = "root";
      };
    } //
    eachDefaultSystem (system:
    let
      inherit (deploy-rs.lib.${system}) deployChecks;
      pkgs = pkgsFor system;
    in
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          deploy-rs.packages.${system}.default
          mcrcon
          nixpkgs-fmt
        ];
      };

      checks = {
        format = pkgs.runCommand "check-format" { } ''
          ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./.}
          touch $out
        '';
      } // deployChecks self.deploy;
    });
}
