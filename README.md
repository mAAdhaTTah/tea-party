# Tea Party

**Everyone's Invited!**

[![CI](https://github.com/mAAdhaTTah/tea-party/actions/workflows/ci.yml/badge.svg)](https://github.com/mAAdhaTTah/tea-party/actions/workflows/ci.yml)

---

Bring all your old friends to your new computer.

A small bash script around provisioning your new Mac with ansible. To use, clone this repository, `cd` into it, then run `./tea-party prepare` followed by `./tea-party throw` (optionally with tags, e.g. `./tea-party throw shell mise`). It asks for your sudo password only when the run includes the `homebrew` or `shell` tag, or no tags at all. If you want to make modifications, fork this repository and edit it directly.

## Manual installs

Not everything can be installed by the playbook. Install these by hand on a new machine.

**Mac App Store**

- Brother iPrint&Scan
- Developer
- Pandan
- Paprika Recipe Manager 3
- Simon Says

**Vendor installers and downloads**

- Brother printer drivers
- Logi Options+
- Exodus
- ClubWPT Gold
- DEVONthink 3, from [DEVONtechnologies](https://www.devontechnologies.com/download/devonthink). v3 builds are still hosted (e.g. `download/devonthink/3.9.18/DEVONthink_3.app.zip`), and the app updates itself within v3. When upgrading to v4, add the `devonthink` cask to `host_vars/localhost/homebrew.yml` and remove it from this list.

**Chrome apps** (install from Chrome)

- Messages (Google Messages; it's in the Dock)
- GTO Wizard

**Configs synced by their apps**

- Alfred syncs its preferences to `~/Documents/Preferences`; point Alfred at that folder.
- Hazel uses its own rules sync.

## Docker

There's no local Docker daemon or VM. The Docker CLI, Compose and buildx talk to the daemon on `four-of-four` over SSH, through a `four-of-four` Docker context that the playbook creates and makes the default.

- Images build as amd64 (four-of-four's architecture). Add `--platform linux/arm64` for arm, which is emulated and slower.
- Published ports are on four-of-four, not localhost: use `four-of-four:PORT` over Tailscale, or `ssh -L PORT:localhost:PORT four-of-four`.
- Bind mounts refer to four-of-four's filesystem. For live reload, add a `develop.watch` section (`action: sync` / `rebuild`) in an untracked `compose.override.yaml` and run `docker compose watch`.
- To use a local daemon instead, run `docker context use default`.

## Codex

The `maadclankker` role sets up both agents, Claude Code (tag `claude`) and
Codex (tag `codex`), and the Cognee config they share. Codex gets the same
plugins and MCP servers as Claude Code where it has an equivalent, and
`~/.codex/config.toml` is seeded only on a fresh machine. Afterwards, finish
these steps by hand:

1. Run `codex` and choose "Sign in with ChatGPT".
2. Approve the plugin hooks (`local-agent`, `cognee`) in the TUI's hooks
   review. Codex ties each approval to a hash of the plugin's contents, so
   approve them again after every plugin update. Until you do, sessions start
   without the workflow norms or Cognee memory, and nothing warns you.
3. Log in to each MCP server: `codex mcp login Neon`, then `todoist` and
   `readwise`.

Codex has no commit-trailer setting, so the seeded config asks for the
mAAdclanKKer `Co-Authored-By` trailer in `developer_instructions` instead.

## Prior Art

- [Kitchenplan](https://github.com/kitchenplan/kitchenplan)
- [SuperLumic](https://github.com/superlumic/superlumic)
- [ansible-playbooks](https://github.com/ideasonpurpose/ansible-playbooks)
- [provision-ansible-mac](https://github.com/reecefowell/provision-ansible-mac)
