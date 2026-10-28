{ config, lib, ... }:

# launchd-tools: two small Home Manager helpers for macOS user agents.
#
# legibleNames — give each listed agent its own name in System Settings > Login Items & Extensions instead of
# a row reading "sh". BackgroundTaskManagement derives a row's display name from the basename of the executable
# path (verify with `sfltool dumpbtm`). Home Manager emits every agent as
#   /bin/sh -c "/bin/wait4path /nix/store && exec <real command>"
# so argv[0] is /bin/sh and every row collapses to "sh". waitForNixStore = false swaps that wrapper for a
# launcher script named after the agent, so the row reads <name>.
# The tradeoff: wait4path guards against launchd starting an agent before the Nix store volume is mounted. That
# is a boot race; user agents start at login, long after /nix is mounted, and agents with KeepAlive or
# StartInterval self-heal a miss. An agent with RunAtLoad only and no restart policy that loses the race stays
# unrun until the next login, silently — leave such agents off the list if a legible name is not worth that.
# Not fixed by this: "Item from unidentified developer" (Developer Name comes from a Developer ID signature; Nix
# store outputs are ad-hoc signed), and system daemons in /Library/LaunchDaemons outside Home Manager.
# Names are listed rather than derived from config.launchd.agents (that would recurse into the attrset being
# defined). A stale name is inert: Home Manager only emits agents whose own `enable` is true.
#
# supervisor — one KeepAlive agent running a single long-lived program (the shape for consolidating many
# launchd jobs under one process supervisor). The program is the consumer's.
let
  cfg = config.launchdTools;
in
{
  options.launchdTools = {
    legibleNames = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "launchd agents to run through a launcher named after the agent (waitForNixStore = false), so Login Items shows the agent's name instead of \"sh\".";
    };
    supervisor = {
      enable = lib.mkEnableOption "one KeepAlive launchd agent named `supervisor` running `program`";
      program = lib.mkOption {
        type = lib.types.str;
        description = "Executable the agent runs (a store path). It must be long-running: KeepAlive restarts it whenever it exits.";
      };
      logDir = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/Library/Logs";
        description = "Directory for supervisor.log and supervisor.err.log.";
      };
    };
  };

  config = lib.mkMerge [
    { launchd.agents = lib.genAttrs cfg.legibleNames (_: { waitForNixStore = false; }); }
    (lib.mkIf cfg.supervisor.enable {
      launchd.agents.supervisor = {
        enable = true;
        waitForNixStore = false;
        config = {
          ProgramArguments = [ cfg.supervisor.program ];
          KeepAlive = true;
          RunAtLoad = true;
          StandardOutPath = "${cfg.supervisor.logDir}/supervisor.log";
          StandardErrorPath = "${cfg.supervisor.logDir}/supervisor.err.log";
        };
      };
    })
  ];
}
