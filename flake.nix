{
  description = "Server configuration flake for neros.dev, cacti.dev, etc.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    utils.url = "github:numtide/flake-utils";

    flake-compat.url = "github:edolstra/flake-compat";
    flake-compat.flake = false;

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.inputs.utils.follows = "utils";
    deploy-rs.inputs.flake-compat.follows = "flake-compat";

    secrets.url = "git+ssh://git@github.com/nerosnm/secrets.git?ref=main";
    secrets.inputs.nixpkgs.follows = "nixpkgs";
    secrets.inputs.flake-utils.follows = "utils";

    agenix.url = "github:ryantm/agenix";
    agenix.inputs.nixpkgs.follows = "nixpkgs";

    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.inputs.flake-utils.follows = "utils";

    naersk.url = "github:nix-community/naersk";
    naersk.inputs.nixpkgs.follows = "nixpkgs";

    hatysa.url = "github:nerosnm/hatysa/master";
    hatysa.inputs.nixpkgs.follows = "nixpkgs";
    hatysa.inputs.flake-utils.follows = "utils";
    hatysa.inputs.rust-overlay.follows = "rust-overlay";
    hatysa.inputs.naersk.follows = "naersk";

    oxbow.url = "github:nerosnm/oxbow/main";
    oxbow.inputs.nixpkgs.follows = "nixpkgs";
    oxbow.inputs.flake-utils.follows = "utils";
    oxbow.inputs.rust-overlay.follows = "rust-overlay";
    oxbow.inputs.naersk.follows = "naersk";

    pomocop.url = "github:nerosnm/pomocop/main";
    pomocop.inputs.nixpkgs.follows = "nixpkgs";
    pomocop.inputs.flake-utils.follows = "utils";
    pomocop.inputs.rust-overlay.follows = "rust-overlay";

    cacti-dev.url = "github:nerosnm/cacti.dev/main";
    cacti-dev.inputs.nixpkgs.follows = "nixpkgs";
    cacti-dev.inputs.flake-utils.follows = "utils";
    cacti-dev.inputs.rust-overlay.follows = "rust-overlay";

    neros-dev.url = "git+ssh://git@github.com/nerosnm/neros.dev.git?ref=main";
    neros-dev.inputs.nixpkgs.follows = "nixpkgs";
    neros-dev.inputs.flake-utils.follows = "utils";
    neros-dev.inputs.flake-compat.follows = "flake-compat";
    neros-dev.inputs.rust-overlay.follows = "rust-overlay";
  };

  outputs =
    { self
    , nixpkgs
    , utils
    , deploy-rs
    , secrets
    , agenix
    , rust-overlay
    , ...
    } @ inputs:
    let
      inherit (builtins) concatMap listToAttrs mapAttrs;
      inherit (nixpkgs.lib) attrNames getAttr nixosSystem;
      inherit (utils.lib) eachSystem eachDefaultSystem system;

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
            neros-dev-content = inputs.neros-dev.packages.${system}.content;
            neros-dev-static = inputs.neros-dev.packages.${system}.static;
            neros-dev-stylesheet = inputs.neros-dev.packages.${system}.stylesheet;
            oxbow = inputs.oxbow.defaultPackage.${system};
            oxbow-cacti-dev = inputs.oxbow.packages.${system}.oxbow-cacti-dev;
            pomocop = inputs.pomocop.defaultPackage.${system};

            tempo = final.callPackage ./pkgs/tempo { };
          })

          agenix.overlay
        ];
      };

      secret = {
        inherit (secrets.nixosModules.secret) grafana hatysa oxbow pomocop tailscale neros-dev;
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
        atm7 = import ./service/atm7.nix;
        lofi = import ./service/lofi.nix;
        marsic = import ./service/marsic.nix;
        megrez = import ./service/megrez.nix;

        # Monitoring
        grafana = import ./service/grafana.nix;
        loki = import ./service/loki.nix;
        prometheus = import ./service/prometheus.nix;
        tempo = import ./service/tempo.nix;

        # Networking
        tailscale = import ./service/tailscale.nix;

        # IRC
        pounce = import ./service/pounce.nix;
      };

      trait = {
        acme = import ./trait/acme.nix;

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
            agenix.nixosModules.age
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
          config = {
            age.secrets."pounce-auth.pem" = {
              file = ./secrets/pounce-auth.pem.age;
              owner = "pounce";
              group = "pounce";
            };

            age.secrets."pounce-client.pem" = {
              file = ./secrets/pounce-client.pem.age;
              owner = "pounce";
              group = "pounce";
            };

            cacti = {
              key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKnAKrUqhfVaoAbhAJutnAsXwrKfPfmBPI19AuYkSbBY root@taygeta";

              acme.enable = true;

              services = {
                enable = true;

                # Websites
                cacti-dev.enable = true;
                neros-dev.enable = true;

                # Custom software
                hatysa.enable = true;
                oxbow.enable = true;
                pomocop.enable = false;

                # Monitoring
                grafana.enable = true;
                loki.enable = true;
                prometheus = {
                  enable = true;
                  nodeExporter.enable = true;
                };
                tempo.enable = true;

                # Networking
                tailscale = {
                  enable = true;
                  trustInterface = true;
                  authKey = config.nerosnm.secrets.tailscale.taygeta;
                };

                # IRC
                pounce = {
                  enable = true;
                  local-ca = config.age.secrets."pounce-auth.pem".path;

                  instances = {
                    libera = {
                      local-host = "libera.cacti.dev";
                      remote-host = "irc.eu.libera.chat";
                      client-cert = config.age.secrets."pounce-client.pem".path;
                      nick = "nerosnm";
                      real = "søren";
                    };
                  };
                };
              };
            };
          };
        };

        marsic = { config, ... }: {
          config.cacti = {
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFv+FfTb6+8dFM2NSubKP6O6xKQg69tZqjBRNBlCSRXg root@nixos";

            acme.enable = true;

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

        atm7 = { config, ... }: {
          config.cacti = {
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHS3fcwk5DX94CnOKg0nJrYaQJNKHEkssGocGjiII5Zq root@nixos";

            acme.enable = true;

            services = {
              enable = true;

              # Minecraft server
              atm7 = {
                enable = true;
                memory = 5632;
              };

              # Monitoring
              prometheus.nodeExporter.enable = true;

              # Networking
              tailscale = {
                enable = true;
                trustInterface = true;
                authKey = config.nerosnm.secrets.tailscale.beez;
              };
            };
          };
        };

        megrez = { config, ... }: {
          config.cacti = {
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH3+XtOM9xdAtGw7m/uhvIpqR2S4XZosxXK3laL1Djkx root@nixos";

            acme.enable = true;

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

        lofi = { config, ... }: {
          config.cacti = {
            key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPD6d0Ydn2bs6XfSUuB8RWfaqfKw6mIgjHNdZPYXjX21 root@nixos";

            acme.enable = true;

            services = {
              enable = true;

              lofi = {
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
          "atm7"
          "lofi"
          "marsic"
          "megrez"
          "taygeta"
        ];
        sshUser = "root";
      };
    } //
    eachDefaultSystem (system:
    let
      pkgs = pkgsFor system;
    in
    {
      devShells.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          agenix.packages.${system}.agenix
          age-plugin-yubikey
          deploy-rs.packages.${system}.default
          mcrcon
          nixpkgs-fmt
        ];
      };
    }) //
    eachSystem (with system; [ x86_64-linux ]) (system:
    let
      pkgs = pkgsFor system;
      inherit (deploy-rs.lib.${system}) deployChecks;
    in
    {
      checks = {
        format = pkgs.runCommand "check-format" { } ''
          ${pkgs.nixpkgs-fmt}/bin/nixpkgs-fmt --check ${./.}
          touch $out
        '';
      } // deployChecks self.deploy;
    });
}
