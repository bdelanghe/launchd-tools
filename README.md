# launchd-tools

Home Manager helpers for macOS launchd user agents.

- **`launchdTools.legibleNames`** — agents listed here run through a launcher named after the agent
  (`waitForNixStore = false`), so System Settings › Login Items shows each one by name instead of a row of
  identical "sh" entries. Tradeoff: no `wait4path /nix/store` guard; fine for login-time agents with
  `KeepAlive`/`StartInterval`, risky for `RunAtLoad`-only ones (see `nix/module.nix`). A listed name whose agent
  is not enabled is inert.
- **`launchdTools.supervisor`** — one `KeepAlive` agent named `supervisor` running a long-lived program of yours.

```nix
inputs.launchd-tools.url = "github:bdelanghe/launchd-tools";
# modules = [ launchd-tools.homeManagerModules.default ];
launchdTools.legibleNames = [ "my-daemon" "my-sync" ];
launchdTools.supervisor = { enable = true; program = "${my-supervisor}/bin/my-supervisor"; };
```

## Checks

`nix flake check`: the module's logic against a stub (any system), and on macOS the module under Home Manager.
