{
  description = "launchd-tools: Home Manager helpers for macOS launchd user agents (legible Login Items names, one KeepAlive supervisor agent)";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # Only for the module-eval check; consumers already carry home-manager and should `follows` it.
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager }:
    let
      lib = nixpkgs.lib;
      systems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
      forAll = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      fixture = { home = { username = "t"; homeDirectory = "/Users/t"; stateVersion = "24.11"; };
        launchdTools.legibleNames = [ "a" "b" ];
        launchdTools.supervisor = { enable = true; program = "/bin/prog"; }; };
    in
    {
      homeManagerModules.default = import ./nix/module.nix;

      checks = forAll (pkgs:
        let
          # The module's own logic, on any system: evaluated against a stub that declares only what it sets.
          stub = { lib, ... }: {
            options.launchd.agents = lib.mkOption { type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything); default = { }; };
            options.home = lib.mkOption { type = lib.types.attrsOf lib.types.anything; };
          };
          got = (lib.evalModules { modules = [ stub ./nix/module.nix fixture ]; }).config.launchd.agents;
          empty = (lib.evalModules { modules = [ stub ./nix/module.nix { home.homeDirectory = "/Users/t"; } ]; }).config.launchd.agents;
        in
        {
          module-logic =
            assert got.a == { waitForNixStore = false; };
            assert got.b == { waitForNixStore = false; };
            assert got.supervisor.config.ProgramArguments == [ "/bin/prog" ];
            assert got.supervisor.config.KeepAlive && got.supervisor.config.RunAtLoad;
            assert got.supervisor.config.StandardOutPath == "/Users/t/Library/Logs/supervisor.log";
            assert empty == { }; # defaults add no agent
            pkgs.runCommand "launchd-tools-module-logic" { } "touch $out";
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
          # Under real Home Manager (launchd is darwin-only there): named agents get the named launcher, the supervisor is emitted.
          module-eval =
            let
              hm = home-manager.lib.homeManagerConfiguration {
                inherit pkgs;
                modules = [ self.homeManagerModules.default fixture
                  { launchd.agents.a = { enable = true; config.ProgramArguments = [ "/bin/echo" ]; }; } ];
              };
              agents = hm.config.launchd.agents;
            in
            pkgs.runCommand "launchd-tools-module-eval" { } ''
              [ "${lib.boolToString agents.a.waitForNixStore}" = false ]
              [ "${lib.boolToString agents.supervisor.enable}" = true ]
              [ "${builtins.elemAt agents.supervisor.config.ProgramArguments 0}" = /bin/prog ]
              [ "${lib.boolToString agents.b.enable}" = false ] # listed but never enabled: inert
              touch $out
            '';
        });
    };
}
