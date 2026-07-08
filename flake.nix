{
  description = "keytabs-matos-cc — age-encrypted Kerberos keytabs for the nixie NixOS + nix-darwin configuration";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0"; # Stable Nixpkgs (use 0.1 for unstable)

    pre-commit-hooks = {
      url = "github:cachix/pre-commit-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      pre-commit-hooks,
      ...
    }:
    let
      inherit (nixpkgs) lib;

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      forAllSystems = lib.genAttrs supportedSystems;

      # Pre-commit hooks — shared between checks output and devShell shellHook.
      # Running `nix develop` installs the hooks into .git/hooks automatically.
      # Kept in sync with nixie's own flake.nix hook set (nixfmt, markdownlint-cli2,
      # commitlint) — see nixie's CLAUDE.md/ARCHITECTURE.md for the shared-conventions
      # rationale.
      preCommitCheck = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pre-commit-hooks.lib.${system}.run {
          src = ./.;
          hooks = {
            nixfmt = {
              enable = true;
              package = pkgs.nixfmt;
            };

            markdownlint-cli2 = {
              enable = true;
              name = "markdownlint-cli2";
              entry = "${pkgs.markdownlint-cli2}/bin/markdownlint-cli2 **/*.md";
              language = "system";
              pass_filenames = false;
              always_run = true;
            };

            commitlint = {
              enable = true;
              name = "commitlint";
              entry = "${pkgs.commitlint}/bin/commitlint --edit";
              language = "system";
              stages = [ "commit-msg" ];
              pass_filenames = false;
            };
          };
        }
      );
    in
    {
      # Canonical formatter — enables `nix fmt` and `nix run .#formatter -- --check`
      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt);

      # Expose pre-commit check so `nix flake check` verifies formatting too
      checks = forAllSystems (system: {
        pre-commit = preCommitCheck.${system};
      });

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            name = "keytabs-matos-cc";
            packages = [ pkgs.nixfmt ];
            # Installs git hooks into .git/hooks when entering the devShell
            inherit (preCommitCheck.${system}) shellHook;
          };
        }
      );
    };
}
