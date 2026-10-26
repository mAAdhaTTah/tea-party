# Plan: migrate runtimes to mise and resync tea-party with this machine

**Status:** draft for review · **Written:** 2026-10-22 · **Machine:** Jamess-MacBook-Air (arm64, provisioned ~2024-08-21)

## Goal

1. Replace fnm, the curl-installed rustup bootstrap, Homebrew-installed uv/bun, and the unused php role with **mise** as the single source of truth for language runtimes.
2. While doing so, bring the tea-party repo back in sync with what is actually on this machine, so that a `--check` run of the playbook reports (close to) zero changes.

## Decisions (agreed)

| Topic | Decision |
|---|---|
| Homebrew vs mise split | Version is a property of the **project** → mise. Version is a property of the **machine** → Homebrew. mise itself is installed via Homebrew. Runtimes that Homebrew pulls in as dependencies stay; mise's PATH ordering shadows them. After A6 that's `node` (for neonctl) and `go` (a leftover dependency); the Homebrew Pythons and deno left with yt-dlp and nmap. |
| Rust | **Option B**: mise drives rustup. `rust = "stable"` in the global mise config; mise reuses the existing `~/.rustup`/`~/.cargo` on this machine and bootstraps rustup on a fresh one. `rust-toolchain.toml` is read via the idiomatic-file setting, so the `RUSTUP_TOOLCHAIN` that mise exports matches the project pin. |
| Python | **Mirror of Option B**: mise picks and installs the interpreter (reads `.python-version`); uv is a mise tool, is pinned to mise's Python via `UV_PYTHON`, and is forbidden from downloading its own (`UV_PYTHON_DOWNLOADS=never`). uv still owns venvs/deps. `python.uv_venv_auto = "source"`. |
| pnpm / yarn / npm | mise reads `packageManager` / `devEngines.packageManager` (opt-in via idiomatic files) and installs them itself. **Corepack off** (`node.corepack` stays default `false`). |
| Order | **Machine first** (Track A), then encode the result in the repo (Track B). |
| Scope | Everything: the mise migration plus resolving all drift from the 2026-10-22 drift report. Hand-installed items are **triaged, not adopted wholesale**: each is kept (added to the repo), ignored (left installed, not in the repo) or uninstalled (A6). |
| Other repos | **No changes to any project repo** under `~/Code` as part of this plan. Follow-ups are listed in [Post-migration evaluation](#post-migration-evaluation). |
| Claude Code's shell | Claude Code snapshots a **non-interactive login shell** (`~/.claude/shell-snapshots/`) and replays it before every command, with a `PATH` frozen at session start. So: Claude takes the mise **shims** branch (versions resolve per command from the cwd), and only the specific aliases/functions that change standard-command behaviour are guarded to interactive shells — not whole files. |
| Claude Code config | Capture `~/.claude/settings.json` (seeded, not overwritten), user-scope MCP servers (via `claude mcp add`), and replace the 15 loose Cloudflare skills with the `cloudflare@cloudflare` plugin. |
| Other app configs | Manage **Ghostty**, **gh** (`config.yml` only), **Rectangle** (enforced as macOS defaults, shortcuts included), and the **Komodo CLI** (`komodo.cli.toml`, credentials from 1Password). opencode was uninstalled in A6. |
| Mac App Store | **Dropped from automation.** `mas` has been unreliable; App Store apps are installed by hand from a list in the README. |
| Docker | **No local daemon or VM.** The Docker CLI, Compose and buildx use four-of-four's existing daemon as `drone`, through a `four-of-four` Docker context set as the default. There are no changes to four-of-four or the homelab repo, and no guardrails: name and port clashes with homelab containers are accepted, and Komodo handles pruning and recovery. Compose Watch replaces bind mounts for live reload; DevPod is the optional fallback for full dev environments. |

## Target mise configuration

`~/.config/mise/config.toml` (becomes a template in Track B):

```toml
[tools]
# runtimes
node = "24"
python = "3.14"
ruby = "3.4"
rust = "stable"
bun = "latest"
# package managers / runtime-adjacent tools
pnpm = "latest"          # fallback for projects without packageManager/devEngines
uv = "latest"
cargo-binstall = "latest"
# global ecosystem tools (previously npm -g / cargo install / Homebrew; kept in A6)
"cargo:cargo-insta" = "latest"
"cargo:sqlx-cli" = "0.8"
"cargo:sampo" = "latest"
"cargo:wasm-pack" = "latest"

[settings]
idiomatic_version_file_enable_tools = ["node", "python", "ruby", "rust", "npm", "pnpm", "yarn"]
python.uv_venv_auto = "source"

[env]
UV_PYTHON = { value = "{{ tools.python.path }}", tools = true }
UV_PYTHON_DOWNLOADS = "never"
```

Notes:
- `python = "3.14"` as the global default. Revisit later.
- `npm:skills` was removed in A6, and `cargo:wasm-pack` replaced the Homebrew formula.
- `neonctl` stays a Homebrew formula; the duplicate `npm -g` copy is dropped.
- `.tool-versions` and `mise.toml` files are read by mise natively (no opt-in) — see post-migration notes for the Elixir and claudev cases.

Shell hook (replaces the fnm, uv, and rust blocks in `~/.managed`):

```bash
### BEGIN ANSIBLE MANAGED MISE CONFIG ###
if [[ $- == *i* ]]; then
  eval "$(mise activate bash)"
  eval "$(uv generate-shell-completion bash)"
else
  eval "$(mise activate bash --shims)"
fi
### END ANSIBLE MANAGED MISE CONFIG ###
```

---

## Track A — Machine migration

Each phase ends with a verification step. Do not start the next phase until it passes.

### A0. Prepare and snapshot

1. Back up dotfiles: `mkdir ~/dotfiles-backup-<date>` and copy `~/.{aliases,apps,bash_profile,bashrc,exports,functions,gitconfig,gitignore_global,managed,path,zshrc,npmrc}`, `~/.ssh/config`, `~/.config/mise/config.toml`.
2. Snapshot current state to the backup dir: `brew leaves --installed-on-request`, `brew list --cask`, `fnm list`, `npm ls -g --depth=0`, `cargo install --list`, `rustup toolchain list`, `uv python list --only-installed`, `mise ls`.
3. `brew upgrade mise` (installed 2026.10.13; 2026.10.17 available).

**Verify:** backup dir contains every file above; `mise --version` is current.

### A1. Configure mise alongside fnm (no shell changes yet)

1. Write the target `~/.config/mise/config.toml` above (merging the existing `ruby = "3.4"`).
2. `mise install`.
3. `mise doctor` — resolve any warnings.

**Verify (fnm is still active in the shell, so use `mise exec`):**
- `mise exec -- node -v` → v24.x; `mise exec -- python -V` → 3.14.x; `mise exec -- ruby -v` → 3.4.10
- `mise exec -- rustup show active-toolchain` → stable, and `mise ls rust` shows it reused `~/.rustup` (no second rustup install)
- `mise exec -- uv python find` → a path under mise's installs dir, not `~/.local/share/uv/python`
- Record where the `cargo:` tools were installed (open question: mise installs dir vs `~/.cargo/bin`).

### A2. Shell switchover

1. In `~/.managed`, delete the `VOLTA CONFIG` (fnm), `UV CONFIG`, and `RUST CONFIG` (`source $HOME/.cargo/env`) blocks; replace the existing hand-added `MISE CONFIG` block with the shell hook above.
2. Open a **new** terminal.

**Verify — shell modes:**
- Interactive: `which node python ruby cargo uv bun pnpm` all resolve to mise (installs dir or shims), `which cargo` resolves so that `cargo --version` matches stable.
- Non-interactive: `bash -c 'which node && node -v && cargo --version && python -V'` resolves via shims.
- Login non-interactive: `bash -lc 'node -v'` (what Ansible's `bash -l -c` tasks use).
- VS Code: integrated terminal and a task/debug launch both see mise's node and python.
- Claude Code: start a **new** session (snapshots are taken at session start). The newest file in `~/.claude/shell-snapshots/` should contain the mise shims dir in `PATH`, no `alias cd='__fnmcd'`, no `_mise_hook` PATH entries for a specific Ruby. Then have Claude run `cd ~/Code/JavaScript/cal-timeblock-sync && node -v` (expect 24.21.0) and `cd ~/Code/Rust/neon && rustc -V` (expect 1.77.0) — proves per-cwd resolution with a frozen PATH.
- If `cargo` is missing in shims mode, keep `source $HOME/.cargo/env` in the non-interactive branch and note it for Track B.

**Verify — per-project resolution** (`cd` into each, run `mise current` plus the listed check; accept `mise trust` prompts only for your own repos):

| Project | Expect |
|---|---|
| `JavaScript/cal-timeblock-sync` | `node -v` = 24.21.0 (`.node-version`) |
| `Infra/claudev` | node 24.22.0 (`devEngines.runtime`), `pnpm -v` = 12.14.0 (`packageManager`) |
| `Rust/strategy-builder` | node 24.22.0, pnpm 11.28.5 (`devEngines`), `mise exec -- rustup show active-toolchain` = 1.99.0 |
| `Rust/spotlab` | same as above with pnpm 12.13.0; wasm32 target present |
| `Rust/neon` | rust 1.77.0 with llvm-tools-preview |
| `JavaScript/swr` | `pnpm -v` = 7.1.0 |
| `JavaScript/railway-effects` | `pnpm -v` = 9.9.0 (`packageManager` has a `+sha512` suffix — confirm mise parses it) |
| `JavaScript/desktop-postflop` | `yarn -v` = 1.22.22 (also `+sha512`) |
| `Python/groupchat-summarizer`, `Python/poker_scripts` | `python -V` = 3.12.x; `uv run python -V` matches; `.venv` auto-activates if present |
| `Ruby/learn-ruby-with-claude/pouchrx` | `ruby -v` = 3.4.10 |

**Verify — upgrade behaviour (open question):** determine whether `mise upgrade rust` runs `rustup update` for the `stable` channel. If it doesn't, the fallback is to run `rustup update` by hand (see Open questions). Record the answer in this doc.

**Rollback:** restore `~/.managed` from the A0 backup and open a new terminal; fnm is still installed.

### A3. Move global ecosystem tools

1. Confirm mise's `skills`, `cargo-insta`, `sqlx`, `sampo` resolve first on PATH (`which -a <bin>`).
2. Remove the old copies:
   - `npm uninstall -g skills neonctl` under fnm's Node (or simply let it disappear with fnm in A4).
   - `cargo uninstall cargo-insta sqlx-cli sampo` (real binaries in `~/.cargo/bin`) — only after mise's copies verify.
3. **Stale `rustfmt` 0.10.0 crate:** do **not** run `cargo uninstall rustfmt` — it would delete `~/.cargo/bin/rustfmt` and `cargo-fmt`, which are now rustup proxies. Instead remove the `rustfmt 0.10.0` entries from `~/.cargo/.crates.toml` and `~/.cargo/.crates2.json`.

**Verify:** `cargo install --list` no longer shows rustfmt; `rustfmt --version` still works via rustup; `which -a sqlx sampo cargo-insta skills` shows only mise paths.

### A4. Remove superseded installs

1. `brew uninstall fnm`; `rm -rf ~/.local/share/fnm ~/.local/state/fnm_multishells`.
2. `brew uninstall bun && brew untap oven-sh/bun`.
3. `brew uninstall uv` (mise's uv takes over).
4. `uv python uninstall 3.12 3.13` — removes uv's own downloads (mise now provides 3.12 for the Python projects).
5. ~~Optional: prune unused rustup toolchains~~ Not needed: toolchains are left to come and go as projects bump their pins.
6. `brew autoremove`.

**Verify:** re-run the A2 shell-mode and per-project checks in a new terminal.

### A5. Machine dotfile cleanup

Removes dead or orphaned config so the live files are the version Track B encodes.

1. LM Studio was deleted: remove the `# Added by LM Studio CLI (lms)` PATH lines from `~/.bash_profile`, `~/.bashrc`, `~/.zshrc`.
2. `~/.exports`: remove the commented-out `GEM_HOME` line, `NODE_PATH`, `GOPATH`, the `~/.gem/ruby/1.8/bin` + `/opt/nginx/sbin` PATH line and `NGINX_PATH` (none of those paths exist). Remove `PROJECT_PATHS`: its only consumer is bash-it's `projects` plugin (`pj`), which has never been used (no `pj` in the 8,225-line `~/.bash_history`).
3. `~/.path`: remove `/opt/homebrew/go/bin` and `$HOME/.composer/vendor/bin` (`~/.bin` does not exist either; keep or drop the whole `if` block).
4. bash-it: `bash-it disable completion composer`, `bash-it disable plugin projects`, `bash-it disable completion projects`.
5. Guard the aliases/functions that change the behaviour of standard commands, so non-interactive shells (Claude Code, scripts) get the real commands. Everything else in those files stays loaded everywhere.
   - `~/.aliases` — wrap the `ls` colour block (`alias ls="command ls ${colorflag}"`, plus `l`, `ll`, `lsd`, which build on it). GNU `ls --color` (no `=auto`) emits ANSI codes even into pipes.
   - `~/.aliases` — also wrap `syncup`/`syncdown`: one-word `rsync --delete` against the media server shouldn't be reachable from an agent's shell.
   - `~/.functions` — wrap `diff()`: it replaces `/usr/bin/diff` with `git diff --no-index`, which takes different flags and exit codes.
   - Pattern:
     ```bash
     # Interactive only: overrides standard command behaviour
     if [[ $- == *i* ]]; then
       …
     fi
     ```
   - Leave the `grep --color=auto` aliases, navigation aliases, `mkd`, etc. unguarded (harmless in pipes/scripts).
6. Delete stale app config: `~/.config/zed/` (Zed removed), `~/.haystack-editor/`, `~/.lmstudio-home-pointer` (LM Studio removed), `~/.config/git/ignore` (never read — `core.excludesfile` points at `~/.gitignore_global`, which already has its one line).

**Verify:** new terminal starts without errors; `type pj` reports not found; `echo $PATH | tr : '\n'` has no dead entries; `type ls diff` in an interactive shell shows the alias/function; `bash -lc 'type ls diff'` shows the plain commands. New Claude Code session's snapshot has no `ls`/`diff` overrides.

### A6. Inventory triage (keep / ignore / uninstall)

Not everything installed by hand belongs in the repo. Before any Track B list is written, go through every hand-installed item and give it one of three dispositions:

- **Keep:** add it to the repo, so it's installed on a fresh machine.
- **Ignore:** leave it installed here, but don't add it to the repo (one-off experiments, machine-specific tools).
- **Uninstall:** remove it from this machine as well.

1. Generate the candidate list into `docs/inventory-triage.md`: one table per category, one row per item, with columns for the item, a short note (what it is / what depends on it) and a disposition (left blank):
   - Homebrew taps not in `homebrew.yml`.
   - Homebrew formulae: `brew leaves` not in `homebrew.yml` (bun, uv and fnm are already decided: mise owns or replaces them).
   - Homebrew casks not in `homebrew.yml`, plus the casks whose apps are gone (`anytype claude comfyui dayflow gitkraken lm-studio lookaway ollama-app omnidisksweeper zed`, pre-filled as uninstall).
   - Global mise tools (the `[tools]` entries beyond the runtimes: `npm:skills`, `cargo:cargo-insta`, `cargo:sqlx-cli`, `cargo:sampo`, `cargo-binstall`).
   - VS Code extensions not in `vscode.yml` (the 22 extras), plus `atlassian.atlascode` (in the repo, not installed: keep in repo or drop).
   - VS Code settings added since provisioning (the 27 extra keys).
   - Claude Code marketplaces, plugins and MCP servers.
   - Dock items not in `dock.yml`.
   - Non-Homebrew apps (candidates for the README "Manual installs" list in B8).
2. I pre-fill a suggested disposition per row; you confirm or change each one. Nothing moves to Track B with a blank disposition.
3. Uninstall everything marked **uninstall**, confirming each command first (`brew uninstall`, `brew uninstall --cask`, `brew untap`, `code --uninstall-extension`, `claude plugin uninstall`, `mise uninstall`, and removing items from the Dock). Then `brew autoremove` and `brew cleanup`.

**Verify:** every row has a disposition; nothing marked uninstall is still present; every `brew list --cask` entry has its app.

`docs/inventory-triage.md` stays in the repo as the record of what was deliberately left out, so a future drift check can tell "ignored on purpose" apart from "forgot to add".

### A7. Claude Code skills → plugin

1. Refresh the stale marketplace clone (last updated 2026-04-27): `claude plugin marketplace update cloudflare`.
2. `claude plugin install cloudflare@cloudflare` (upstream now ships 19 skills, a superset of the 15 loose copies except `sandbox-sdk`, which upstream replaced with `sandbox-next`/`sandbox-stable`; it also brings commands and rules).
3. Confirm `"cloudflare@cloudflare": true` is in `enabledPlugins` in `~/.claude/settings.json`.
4. New session: confirm the Cloudflare skills are listed from the plugin.
5. Delete the 15 loose skill dirs in `~/.claude/skills/` (`agents-sdk`, `cloudflare`, `cloudflare-email-service`, `cloudflare-one`, `cloudflare-one-migrations`, `durable-objects`, `nextjs-on-cloudflare`, `sandbox-migrate-to-next`, `sandbox-next`, `sandbox-sdk`, `sandbox-stable`, `turnstile-spin`, `web-perf`, `workers-best-practices`, `wrangler`). **Keep `synced/`** (claude.ai-synced skills).

**Verify:** new session lists each Cloudflare skill once (no duplicates from loose copies).

### A8. Soak

Use the machine normally for a few days before Track B. Note any runtime surprises here.

- 2026-10-25: local Docker VMs take too much of the small disk, so Docker moved to a remote daemon (A9).

### A9. Remote Docker on four-of-four

1. `~/.ssh/config`: add a `Host four-of-four` block (`User drone`, `ControlMaster auto`, `ControlPath ~/.ssh/cm-%r@%h:%p`, `ControlPersist 10m`) and remove `Include ~/.colima/ssh_config`. Connection sharing means one 1Password approval per 10 minutes rather than one per `docker` command.
2. `docker context create four-of-four --docker host=ssh://four-of-four`, then `docker context use four-of-four`.
3. `brew install docker-buildx` (without it, the CLI falls back to the old builder instead of BuildKit).
4. `brew uninstall colima lima qemu`, delete `~/.colima` and `~/.lima`, then `brew autoremove`.
5. Optional, when a project needs it: `brew install devpod` and `devpod provider add ssh --option HOST=four-of-four`.

**Verify:** `docker info` reports four-of-four; `bash -lc 'docker ps'` and a new Claude Code session both see the remote containers; a real `docker build` works; a published port is reachable at `four-of-four:PORT`; `docker compose watch` syncs a local edit into the running container; several `docker` commands in a row prompt 1Password only once.

**Rollback:** `docker context use default`, and `brew install colima` if local Docker is needed again.

**Day-to-day:**
- Images build as amd64 (four-of-four's architecture); add `--platform linux/arm64` for arm, which is emulated and slower.
- Push images you need elsewhere to the Gitea registry.
- For live reload, put a `develop.watch` section (`action: sync` / `rebuild`) in an untracked `compose.override.yaml` and run `docker compose watch`.
- Reach published ports at `four-of-four:PORT` over Tailscale, or forward one with `ssh -L PORT:localhost:PORT four-of-four`. Testcontainers-style tests need `TESTCONTAINERS_HOST_OVERRIDE=four-of-four`.
- Komodo's scheduled prune will eventually remove dev images and build cache, so the first build after a prune is slower.

---

## Track B — Repo changes

Work on a branch. Final acceptance test is B15.

Execution decisions (2026-10-25):
- **Git:** branch `mise-migration`. The first commit is the docs plus the pending `gitconfig` edit, then one commit per B step. Push and open a GitHub PR so CI runs.
- **Ansible:** pin ansible-core **2.21.5** in `tea-party`, CI and the docs, replacing 2.15.3, which the installed `community.general` 12.x doesn't support (it requires ≥ 2.17). Pin the `geerlingguy.mac` and `community.general` versions in `requirements.yml`.
- **Acceptance on this machine:** you run `--check --diff` with `!` (sudo needs your password), I fix any diffs, then you do a real run so the command tasks (mise, claude, op, Docker context) are exercised.
- **CI:** runs everything, with no CI-specific skips.
  - Tasks that need local credentials are expected to fail or skip there: the claudev marketplace over SSH, the `op` tasks, and authenticated `claude` commands.
  - The `op` tasks already skip with a warning when `op` isn't signed in. Revisit anything else if CI fails.

### Implementation notes (2026-10-25)

Where the branch differs from the step text below:
- **Collections:** install into `vendor/collections` (`ansible.cfg`), so the pins don't change the copies homelab uses in `~/.ansible/collections`. `inject_facts_as_vars = True` is set explicitly to silence the 2.21 deprecation warning; the `ansible_*` fact variables need moving to `ansible_facts[...]` before ansible-core 2.24.
- **mise:** the role installs `mise` itself, like the shell role does for `bash`, so it isn't in `homebrew_installed_packages`.
- **App configs (B13) and the Docker context (B14):** live in a new `apps` role, not the shell role. The Claude Code tasks (B12) are a `claude` role. Both run after `mise`.
- **Rectangle:** its scalar settings are a separate `rectangle_defaults` list in `osx.yml`, so only Rectangle changes trigger its restart handler. The shortcuts are `rectangle_shortcuts`. The Downloads stack task is in the `os` role.
- **gh config:** kept at mode `0600`, matching the live file.
- **Lint:** `.ansible-lint` excludes `vendor/` and `roles/apps/files/`, which holds configs copied verbatim from the machine.

### B1. New `mise` role

- `roles/mise/tasks/main.yml`:
  1. Template `~/.config/mise/config.toml` from `mise_tools`, `mise_settings`, `mise_env`.
  2. `blockinfile` the MISE CONFIG block (shell hook above) into `~/.managed`.
  3. `mise install` via `bash -l -c`, with `changed_when` based on output so CI idempotence holds.
  4. rustup bash completions into `{{ bash_it_install_path }}/enabled/450--rustup.completion.bash` (moved from the rust role).
- `roles/mise/templates/config.toml.j2`, `roles/mise/defaults/main.yml`.
- `host_vars/localhost/mise.yml` holds the tool list/settings/env from the target config.
- Add `mise` to `homebrew_installed_packages`.
- `computer.yml`: add `{ role: mise, tags: [mise] }` (runs by default — no `never` tag).

### B2. Remove superseded roles and dead config

- Delete `roles/node`, `roles/php`, `roles/python`, `roles/rust`, `host_vars/localhost/php.yml`, `host_vars/localhost/rust.yml`; remove them from `computer.yml`.
- `requirements.yml`: drop `geerlingguy.docker` (never referenced by `computer.yml`).

### B3. Homebrew lists (`host_vars/localhost/homebrew.yml`)

Final lists from A6 (`docs/inventory-triage.md`).

- **Taps:** add `jandedobbeleer/oh-my-posh`, `moghtech/komodo`, `athevon/tokeneater` (keep `homebrew/services`).
- **Formulae:** keep the existing 12 (bash-completion, coreutils, curl, flyctl, git, gnu-tar, jq, jump, ripgrep, rsync, trash, wget). Add: cloudflared, docker, docker-buildx, docker-compose, findutils, gh, km, mise (B1), neonctl, oh-my-posh, poppler, tea. `bash` and `dockutil` are installed by their roles.
  - **Not added:** lazygit (ignore). wasm-pack is now in mise. Everything uninstalled in A6 or A9 stays out, including colima, lima and qemu.
- **Casks:**
  - **Rename** to current tokens: `flux`→`flux-app`, `syncthing`→`syncthing-app`, `tailscale`→`tailscale-app`, `todoist`→`todoist-app`.
  - **Add:** claude-code@latest, font-fira-code-nerd-font, ghostty, mountain-duck, t3-code, tokeneater, zoom.
  - **Remove:** iterm2, devonthink (now a manual install, see B8).
  - **Keep as is:** font-cutive-mono.

### B4. Shell role and bash-it

- `host_vars/localhost/bash-it.yml`: `bash_it_theme: oh-my-posh` (keep `posh_theme`); remove `composer`, `projects`, `go`, `apm`, `vagrant`, `virtualbox`, `travis` and `gulp` from completions; `projects` and `go` from plugins; `atom` and `vagrant` from aliases. All of these were disabled on the machine in A5/A6.
- `roles/shell/tasks/main.yml`: wrap the BASH-IT block in the `if [[ $- == *i* ]]` guard that the live `~/.managed` has.

### B5. Dotfile templates (adopt live files after A5)

- `aliases`: adopt live, including the A5 interactive guards around the `ls` colour block and `syncup`/`syncdown`. Drops the redundant `alias ls="gls"` — it was immediately overridden — and `alias -- -='cd -'`; rsync target becomes `izzi@icanhazmedia`. Dropping `-` is confirmed.
- `functions`: adopt live, including the A5 interactive guard around `diff()`.
- `bash_profile`, `bashrc`: unchanged once A5 removes the LM Studio lines.
- `exports`, `path`: adopt the A5-cleaned versions; keep `/Applications/Obsidian.app/Contents/MacOS` on PATH. `path` now also puts findutils' `gnubin` and `gnuman` after coreutils' (A6); use `{{ homebrew_prefix }}` for both.
- `gitconfig`: commit the current uncommitted edits, plus `rebase.updateRefs = false` (live value) and the `gh auth git-credential` helpers for github.com and gist.github.com (use `{{ homebrew_prefix }}/bin/gh`). Normalise tabs vs spaces.
- `gitignore_global`: add `**/.claude/settings.local.json`.
- `ssh/config`: add the `192.168.2.35` (izzi) / `192.168.2.128` (dreedle) host blocks and the A9 `four-of-four` block (`User drone` plus the `ControlMaster`/`ControlPath`/`ControlPersist` lines). No colima include.
- Consider adding `~/.zshrc` as a managed template (currently only `export PATH=/opt/homebrew/bin:$PATH` after A5) or leave unmanaged.

### B6. Dock (`host_vars/localhost/dock.yml`)

Live Dock as of 2026-10-25:
- **Apps:** 14, in this order, all non-Homebrew items accounted for in A6.
- **Downloads:** one stack in the right-hand section.
- **Settings:** recents hidden, `tilesize` 50, autohide on.

- **`dockitems_persist`**, in this order, with `pos` 1–14 and paths exactly as the live Dock has them:

  | pos | name | path |
  |---|---|---|
  | 1 | Google Chrome | `/Applications/Google Chrome.app/` |
  | 2 | Todoist | `/Applications/Todoist.app/` |
  | 3 | Obsidian | `/Applications/Obsidian.app/` |
  | 4 | Visual Studio Code | `/Applications/Visual Studio Code.app/` |
  | 5 | Ghostty | `/Applications/Ghostty.app/` |
  | 6 | T3 Code (Beta) | `/Applications/T3 Code (Beta).app/` (added since the 2026-10-22 snapshot; t3-code is a kept cask) |
  | 7 | Slack | `/Applications/Slack.app/` |
  | 8 | Signal | `/Applications/Signal.app/` |
  | 9 | Messages | `~/Applications/Chrome Apps.localized/Messages.app/` (the Chrome app; the repo's `Chrome Apps/` path lacks `.localized`) |
  | 10 | Keybase | `/Applications/Keybase.app/` |
  | 11 | WhatsApp | `/Applications/WhatsApp.app/` |
  | 12 | Discord | `/Applications/Discord.app/` |
  | 13 | Spotify | `/Applications/Spotify.app/` |
  | 14 | Reader | `/Applications/Reader.app/` |

- **Removed from the repo:**
  - iTerm (uninstalled).
  - GTO Wizard (dropped in A6). Its repo entry was also mislabelled `name: "Messages"`, with a `pos` of 14.
- **Fix a `dockitems_remove` bug:**
  - **The bug:** the list contains `"Messages"`. The role removes items with `dockutil --remove '<label>'`, and the Chrome Messages app has that label too. Every run removes the Chrome app, re-adds it and moves it back into position, so the Dock churns and the role is never idempotent.
  - **The fix:** replace `"Messages"` with Apple Messages' bundle ID, `com.apple.MobileSMS`. dockutil accepts bundle IDs for `--find` and `--remove`; verified read-only, it matches the Apple app without hitting the Chrome app.
  - **Other labels:** the rest of the list has no clashes with kept apps.
- **Downloads stack:** the role only adds apps by label and path, and can't set a stack's view options.
  - Add a small task that runs `dockutil --add ~/Downloads --section others --view fan --display stack --sort dateadded` only when `dockutil --find Downloads` fails.
  - Those options match the live `showas = 1`, `displayas = 0` and `arrangement = 2`.
- **Dock settings in `osx.yml` (B7):**
  - Add `show-recents` bool false. It's live but not in the repo, and without it a fresh Dock shows recent apps.
  - `tilesize` 50 and `autohide` are covered by B7's existing entries once the `c` domain bug is fixed.

### B7. macOS defaults (`host_vars/localhost/osx.yml`)

- Update to live values: Finder `FXPreferredViewStyle: Nlsv`, `ShowStatusBar: false`; Activity Monitor `ShowCategory: 100`.
- Fix the Dock size entry: domain `c` → `com.apple.dock`, value `50` (live).
- Add `com.apple.dock` `show-recents` bool `false` (live; see B6). Delete the junk `c` defaults domain on the machine (`defaults delete c`) after confirming it only contains `tilesize`.
- Fix screenshot `location`: use `{{ ansible_env.HOME }}/Desktop` (currently written literally as `${HOME}/Desktop`); correct the live value too.
- Remove keys for sandboxed apps that `defaults write` cannot reach: all `com.apple.mail`, `com.apple.TextEdit`, `com.apple.QuickTimePlayerX`, `com.apple.helpviewer`, `com.apple.appstore` entries.
- Remove duplicate entries (`NSWindowResizeTime`, `AppleKeyboardUIMode`, TextEdit, DiskUtility, App Store `ShowDebugMenu`).
- Remove unused `computer_name` and `timezone` variables (nothing consumes them).

### B8. Mac App Store

- Delete `host_vars/localhost/mas.yml` (never applied; nothing references it).
- Add a "Manual installs" section to `README.md` (final lists from A6):
  - **App Store:** Brother iPrint&Scan, Developer, Pandan, Paprika Recipe Manager 3, Simon Says.
  - **Vendor installers or downloads:** Brother printer drivers, Logi Options+, Exodus, ClubWPT Gold, DEVONthink 3 (https://www.devontechnologies.com/download/devonthink; v3 builds are still hosted, e.g. `download/devonthink/3.9.18/DEVONthink_3.app.zip`; it updates itself within v3).
  - **Note: move DEVONthink back to Homebrew when upgrading to v4** (a $99 upgrade, not planned yet): add the `devonthink` cask, which installs v4 as `DEVONthink.app`, and remove it from this list.
  - **Chrome apps:** Messages (in the Dock) and GTO Wizard.
  - **Configs synced by their apps** (from B13): Alfred, Hazel.

### B9. VS Code (`host_vars/localhost/vscode.yml`)

- **Extensions:**
  - **Add:** anthropic.claude-code, docker.docker, ms-azuretools.vscode-containers, github.vscode-github-actions, mitsuhiko.insta, ms-python.vscode-python-envs, oxc.oxc-vscode, sdras.night-owl, tauri-apps.tauri-vscode, vitest.explorer, ms-vscode.azure-repos.
  - **Remove:** `ms-azuretools.vscode-docker`, which vscode-containers replaces (uninstalled from the machine 2026-10-25).
  - **Keep:** `atlassian.atlascode` (installed on the machine in A6).
- **Settings:**
  - **Add the A6 keeps:** the `[dockercompose]`/`[github-actions-workflow]`/`[markdown]` blocks, `ansibleVault.executable`, `chat.disableAIFeatures`, `github.copilot.enable`, `claudeCode.*`, `diffEditor.ignoreTrimWhitespace`, `docker.extension.enableComposeLanguageServer`, `editor.unicodeHighlight.ambiguousCharacters`, `git.confirmSync`, `githubPullRequests.pushBranch`, `json.schemaDownload.trustedDomains`, `oxc.enable`, `python.analysis.typeCheckingMode`, `rust-analyzer.check.command`, `terminal.integrated.fontFamily`, the three theme keys, `yaml.disableSchemaDetection`, `atlascode.jira.enabled`.
  - **Take the live values:** `cSpell.userWords`, and `editor.fontFamily` (`Source Code Pro, Cutive Mono, Menlo, Monaco, Courier New, monospace`).
  - **Fix the YAML boolean:** quote `editor.cursorSmoothCaretAnimation: "on"`, so it's the string VS Code expects rather than `true`.
  - **Leave out** (removed from the machine in A6): `notebook.editorOptionsCustomizations`, `gitlens.ai.*`, `yaml.schemas`.
- `visual_studio_code_settings_overwrite: false` means these settings only apply on a fresh machine.

### B10. Editor role

No change expected; confirm `EDITOR`/`GIT_EDITOR` block still matches.

### B11. CI (`.github/workflows/ci.yml`)

- `macos-13` runners are retired → move integration to a current macOS arm64 runner.
- Bump `actions/checkout` / `actions/setup-python` from `@v2`.
- Ensure the mise role is idempotent in the second-run check (`mise install` `changed_when`).
- Consider gating heavy installs (e.g. `cargo:` tools compiling) in CI.

### B12. Claude Code

- New `claude` role (or a section of `editor`), after Homebrew (installs the `claude-code@latest` cask) and after the shell role (1Password SSH agent config is needed for the `claudev` git marketplace).
- `~/.claude/settings.json`: template with `force: false` — seeds a fresh machine but never overwrites, since Claude Code writes to this file itself (`/config`, plugin installs). Content = current live file (permissions mode, the six `enabledPlugins` above, `extraKnownMarketplaces`, UI prefs). No secrets.
- User-scope MCP servers: do **not** template `~/.claude.json` (it mixes ~100 keys of state with the OAuth account). Instead, per server in a `claude_mcp_servers` var, run `claude mcp add --scope user --transport http <name> <url>` when `claude mcp get <name>` fails. Kept in A6: `Neon` → `https://mcp.neon.tech/mcp`, `ogham` → `https://ogham.8p.jamesdigioia.com/mcp`. Authentication stays a manual step.
- Plugins: don't rely on Claude Code auto-installing what `settings.json` declares (the docs don't say clearly whether it does). Explicit, idempotent tasks instead:
  - for each entry in a `claude_marketplaces` var: `claude plugin marketplace add <source>` when `claude plugin marketplace list` doesn't show it;
  - for each entry in `claude_plugins`: `claude plugin install <plugin>@<marketplace>` when `claude plugin list` doesn't show it.
  - Final lists from A6:
  - Marketplaces: `claude-plugins-official` (built in), `cloudflare` (`cloudflare/skills`), `claudev` (`git@git.8p.jamesdigioia.com:mAAdhaTTah/claudev.git`), `doist` (`doist/todoist-mcp`), `readwise-skills` (`readwiseio/readwise-skills`).
  - Plugins: `rust-analyzer-lsp@claude-plugins-official`, `typescript-lsp@claude-plugins-official`, `todoist@doist`, `readwise@readwise-skills`, `local-agent@claudev`, `cloudflare@cloudflare`.
  - Not included: `core-agent@claudev` (retired) and `frontend-design` (both uninstalled in A6). Also `cloudflare@claude-plugins-official`, which is cal-timeblock-sync's project scope, not user scope.
- Not managed: history, projects, sessions, caches, shell snapshots, plugin cache, `skills/synced/`.

### B13. App configs

- **Ghostty:** `roles/shell/templates/ghostty/config` → `~/.config/ghostty/config` (full template; hand-edited only). Live file is the source.
- **gh:** template `~/.config/gh/config.yml` from the live file (`git_protocol: ssh`, switched from `https` on 2026-10-25, and the `co: pr checkout` alias). Note `gh config set` / `gh alias set` write to this file, so later changes must be folded back. **Never** manage `~/.config/gh/hosts.yml` (token).
- **Rectangle:** manage it as macOS defaults (domain `com.knollsoft.Rectangle`), read straight from the live preferences. No export from the app is needed.
  - **Scalar keys** go in `host_vars/localhost/osx.yml` as `osx_defaults` entries:
    - `alternateDefaultShortcuts` bool true, `allowAnyShortcut` bool true, `subsequentExecutionMode` int 1, `windowSnapping` int 2, `doubleClickTitleBar` int 0, `launchOnLogin` bool true
    - `todo` bool true, `todoApplication` string `com.todoist.mac.Todoist`, `todoMode` bool false, `todoSidebarSide` int 2, `todoSidebarWidth` int 1000
  - **Shortcuts** are dictionaries, which `osx_defaults` can't write. Use a `rectangle_shortcuts` var (name → `keyCode`, `modifierFlags`) and a looped task:
    - It runs `defaults write com.knollsoft.Rectangle <name> -dict keyCode -int N modifierFlags -int M` only when `defaults read` shows a different value. It's skipped in check mode but reports what it would change.
    - Current values (`keyCode`/`modifierFlags`): `topLeftSixth` 12/1835008, `topCenterSixth` 13/1835008, `topRightSixth` 14/1835008, `bottomLeftSixth` 0/1835008, `bottomCenterSixth` 1/1835008, `bottomRightSixth` 2/1835008, `toggleTodo` 11/786432, `reflowTodo` 45/786432.
  - **Not managed:** `SU*` (Sparkle updater), `NSWindow Frame …`, `NSStatusItem …`, `lastVersion`, `internalTilingNotified`.
  - **Restart:** Rectangle reads its defaults at launch and can write them back while running. A handler restarts it (`killall Rectangle; open -a Rectangle`) when any key changed.
  - **Drift:** shows up in B15's `--check --diff` for the scalars and in the shortcut task's report. New settings changed in Rectangle's UI need adding to these vars.
- **Komodo CLI:** template `~/.config/komodo/komodo.cli.toml` (mode `0600`) from the 1Password item **`op://Private/Komodo CLI/`**, with fields `host`, `cli_key` and `cli_secret`. The item was created 2026-10-25 from the live file and verified to match.
  - Read the fields with `op read` (or the `community.general.onepassword` lookup) using your own 1Password session (desktop-app integration). The homelab service account can only see the `homelab` vault, so it can't read this item.
  - If `op` isn't signed in, skip the task with a warning rather than writing empty credentials.
- **1Password service-account token** (`~/.config/op/service-account-token`, which homelab's `scripts/playbook.sh` reads):
  - Task, run only when the file is missing: `op service-account create "tea-party-{{ ansible_hostname }}" --vault homelab:read_items --raw`, writing the output to the file with mode `0600` and never logging it (`no_log: true`). This matches the current account, which can see only the `homelab` vault, and homelab only reads from it.
  - Needs you signed in to `op` as an account admin. Each machine gets its own service account, so delete the old machine's account in 1Password when you retire it.
  - This machine keeps its existing token; the task doesn't touch an existing file.
- **Left to the app's own sync** (document in README): Alfred (syncs to `~/Documents/Preferences`), Hazel (own rules DB/sync).
- **Never templated (secrets):** `~/.npmrc`, `~/.config/gh/hosts.yml`, `~/.config/neonctl/credentials.json`, `~/.cloudflared/*`. The service-account token is created only when missing, as above, and never stored in the repo.

### B14. Remote Docker

- Homebrew: `docker`, `docker-compose`, `docker-buildx` (B3); SSH block (B5).
- New task in the shell role, after the SSH config template: create the context only if it's missing (`docker context inspect four-of-four` fails → `docker context create four-of-four --docker host=ssh://four-of-four`), then `docker context use four-of-four` when `docker context show` isn't already `four-of-four`. Creating a context doesn't connect, so this is safe on a fresh machine before four-of-four is reachable.
- README: a short "Docker" section — remote daemon on four-of-four, ports at `four-of-four:PORT`, the Compose Watch override pattern, `docker context use default` to switch back.
- B2 already removes `geerlingguy.docker`; no local engine role is needed.
- DevPod: not installed. Add `devpod` to B3 and the provider setup here only if it's adopted later.

### B15. Acceptance

1. `./tea-party throw` is **not** run. Instead: `pkgx +ansible@2.15.3 ansible-playbook -K -i "localhost," computer.yml --check --diff`.
2. Expected: no diffs for dotfile templates, `.managed` blocks, osx defaults, Homebrew lists, Dock, Ghostty/gh configs. Seed-only files (Claude `settings.json`) and the idempotent `claude plugin`/`claude mcp` tasks are no-ops. Shell/command tasks are skipped in check mode — note them.
3. Any remaining diff is either fixed in the repo or documented here as intentional.
4. CI green (lint + integration).

---

## Track A execution log (2026-10-22)

- **A0:** backup and snapshots are in `~/dotfiles-backup-2026-10-22/`, which also holds `~/.cargo/.crates*`, `~/.claude/settings.json` and `snapshot/`. mise is now 2026.10.17.
- **A1:** all tools installed; `mise doctor` reports no problems. `uv python find` ignores `UV_PYTHON` and still lists uv's own downloads. `uv run` and `uv venv` do use mise's Python, so that's cosmetic.
- **A2:** passed in fresh login shells, both interactive and `bash -lc`.
  - Per-project versions all resolve. mise auto-installs a pinned version on first use through a shim.
  - A tool that has never been installed has no shim yet: `yarn` in desktop-postflop failed until `mise install` was run there once.
  - The `{{ tools.python.path }}` template errors once in a directory whose pinned Python isn't installed yet, then works after the auto-install.
- **A3:** mise's copies of cargo-insta, sqlx and sampo are the only ones on PATH, and `cargo install --list` is empty.
  - The plan didn't anticipate that stripping the `rustfmt` 0.10.0 record left a broken `.crates.toml`; it was rewritten as an empty `[v1]` table.
- **A4:** fnm (2.1 GB of Node versions), Homebrew's bun with its `oven-sh/bun` tap, and Homebrew's uv are removed. `brew autoremove` found nothing.
  - **Deferred step 4 (`uv python uninstall 3.12 3.13`):** the `.venv`s in count-sponsors, groupchat-summarizer and poker_scripts are built on uv's 3.12.6. Removing it means recreating those venvs on mise's 3.12.15.
  - **Skipped (optional) step 5:** rustup toolchain prune.
- **A5:** done.
  - The stale app configs were moved to `~/dotfiles-backup-2026-10-22/stale/` rather than deleted.
  - The guards are verified: interactive shells keep `ls`, `diff` and `syncup`; `bash -lc` gets the plain commands and no `syncup`.
- **A7:** the plugin is installed and enabled; its 19 skills cover the loose copies except `sandbox-sdk`. The 15 loose skill directories were moved to `~/dotfiles-backup-2026-10-22/claude/loose-skills/`.
  - The plugin's Cloudflare MCP server needs authenticating (`/mcp`).
- **A6:** the list is in `docs/inventory-triage.md`, waiting for your decisions.
- **Still to do by hand:** VS Code check (A2), new Claude Code session check (A2/A7), the A6 decisions and uninstalls, then A8 soak.

### 2026-10-25

- **A9 done.**
  - `~/.ssh/config` has the `four-of-four` block, and the colima include is gone. The previous file is backed up as `~/dotfiles-backup-2026-10-22/ssh/config.pre-docker`.
  - The `four-of-four` context is created and active, and `docker-buildx` 0.38.1 is installed.
  - colima, lima and qemu are uninstalled (about 790 MB), along with their orphaned dependencies dtc, snappy, libssh and libyaml. `~/.colima` is deleted.
- **Verified:**
  - `docker info` reports four-of-four (29.6.1, linux/x86_64), and `bash -lc 'docker ps'` lists the homelab containers.
  - A busybox compose test built remotely and served on `four-of-four:18080`. `docker compose watch` synced a local edit into the container. The test stack and its image were removed afterwards.
  - sport-video-torznab built remotely in about 12 s, and the test image was removed.
- **Not yet verified:**
  - 1Password prompting once per 10 minutes (the shared connection is up; you need to watch for prompts).
  - `docker` from a new Claude Code session.
- DevPod not installed (optional).
- **A6 decisions are complete** and recorded in `docs/inventory-triage.md` (DEVONthink deferred).
  - The machine-side changes (step 3) are listed below. **They were run on 2026-10-25; results follow the list.**
  - On the machine:
    - **Homebrew formulae to uninstall:** actionlint, codecrafters, ffmpeg, yt-dlp, tmux, opencode, pi-coding-agent, supabase, homebutler, recyclarr, git-filter-repo, sigtop, nmap, iperf3, smartmontools, snitch, superfile, telnet. Uninstall wasm-pack too, after `cargo:wasm-pack` works.
    - **Taps to remove:** codecrafters-io/tap, supabase/tap, higangssh/homebutler, recyclarr/recyclarr, tbvdm/tap.
    - **Homebrew casks to uninstall:** anki, gitkraken-cli, iterm2, anytype, claude, comfy, comfyui, dayflow, gitkraken, lm-studio, lookaway, ollama-app, omnidisksweeper, zed.
    - **Homebrew cleanup:** then `brew autoremove` and `brew cleanup`.
    - **opencode data:** move `~/.config/opencode`, `~/.local/share/opencode`, `~/.local/state/opencode` and `~/.local/share/opentui` to `~/dotfiles-backup-2026-10-22/stale/`.
    - **mise:** add `"cargo:wasm-pack"`; remove `npm:skills` (`mise uninstall npm:skills`).
    - **VS Code extensions to uninstall:** denoland.vscode-deno, the 5 ms-toolsai Jupyter extensions, vue.volar, continue.continue, danielgjackson.auto-dark-mode-windows, lkytal.flatui, maptz.regionfolder.
    - **VS Code extension to install:** atlassian.atlascode.
    - **VS Code settings:** remove `notebook.editorOptionsCustomizations`, `gitlens.ai.model`, `gitlens.ai.gitkraken.model` and `yaml.schemas`. Set `editor.fontFamily` to Source Code Pro, Cutive Mono, then the rest.
    - **Claude Code plugins to uninstall:** `core-agent@claudev`, `frontend-design@claude-plugins-official`, `cloudflare@claude-plugins-official`.
    - **Shell:** add `/opt/homebrew/opt/findutils/libexec/gnubin` to PATH in `~/.path`, next to coreutils. Run `bash-it disable plugin go` and `bash-it disable completion go`.
  - Left for Track B: `~/.config/komodo/komodo.cli.toml` as a template, with `cli_key`/`cli_secret` read from 1Password. You'll need to create the item and say which one it is.
- **A6 step 3 results (2026-10-25):**
  - **Homebrew:**
    - All 19 formulae (including wasm-pack) and 5 taps are removed.
    - Homebrew's automatic cleanup also removed the dependencies only they used: python@3.14, python@3.15, deno, shellcheck (from actionlint), lua, the ffmpeg codec libraries and others. `brew cleanup` freed about 808 MB more.
    - Remaining leaves: bash, bash-completion, cloudflared, coreutils, curl, docker, docker-buildx, docker-compose, dockutil, findutils, flyctl, gh, git, gnu-tar, jq, jump, km, lazygit (ignore), mise, neonctl, oh-my-posh, poppler, ripgrep, rsync, tea, trash, wget.
    - Remaining taps: athevon/tokeneater, homebrew/services, jandedobbeleer/oh-my-posh, moghtech/komodo.
  - **Casks:**
    - All 13 installed casks are removed; `comfyui` was already gone, as an alias of `comfy`.
    - `anki` needed `--force`, because a stalled upgrade from June had left `Caskroom/anki/25.09.upgrading`. Anki's data in `~/Library/Application Support/Anki2` was left untouched.
    - The only cask whose app is missing now is `devonthink` (deferred). The old `flux`, `syncthing`, `tailscale` and `todoist` names in `brew list --cask` are Caskroom symlinks to the renamed casks; nothing is duplicated.
  - **opencode data:** moved to `~/dotfiles-backup-2026-10-22/stale/opencode/` (273 MB).
  - **mise:**
    - `cargo:wasm-pack` 0.15.0 is installed through binstall, and npm:skills is removed.
    - `mise prune` also removed pnpm 12.13.0, which nothing references any more: spotlab now pins pnpm 12.15.0 and Rust 1.99.1, updated during the soak.
  - **VS Code:**
    - All 11 extensions are removed; the Jupyter sub-extensions went with the Jupyter pack. atlascode 4.0.33 is installed.
    - The 4 settings are removed, and the font order is updated. The previous `settings.json` is backed up as `~/dotfiles-backup-2026-10-22/vscode-settings.json`.
  - **Claude Code:**
    - `frontend-design` is uninstalled. `core-agent@claudev` was already gone.
    - **Not removed:** `cloudflare@claude-plugins-official` is installed at *project* scope for cal-timeblock-sync, and its committed `.claude/settings.json` enables it. Removing it would change that repo, so it's listed under Post-migration evaluation instead.
  - **Shell:**
    - findutils' `gnubin` and `gnuman` are added after coreutils in `~/.path`. `find`, `xargs` and `locate` are GNU in both interactive and `bash -lc` shells.
    - The bash-it `go` plugin and completion are disabled, and `GOPATH` is no longer set.
  - **Spot check:** per-project node, python, rust and wasm-pack still resolve, and the Docker context is still `four-of-four`.

## Open items before Track B (from the 2026-10-25 review)

Resolved 2026-10-25:

- **Venvs and uv's Pythons:** the count-sponsors, groupchat-summarizer and poker_scripts `.venv`s were deleted (not recreated; `uv sync` or `uv venv` rebuilds each one on mise's Python next time you work there). `uv python uninstall 3.12 3.13` removed uv's 3.12.6 and 3.13.5.
- **Rust toolchains:** removed 1.97.0, 1.98.1, nightly and 1.99.0 (strategy-builder moved to 1.99.1 on origin). From now on toolchains are left alone: they come and go as projects bump their pins.
- **VS Code:** `ms-azuretools.vscode-docker` uninstalled.
- **bash-it:** disabled the `atom` and `vagrant` aliases and the `apm`, `vagrant`, `virtualbox`, `travis` and `gulp` completions (B4 drops them from the repo).
- **`-` alias:** dropping it from the template is confirmed (B5).
- **Service-account token:** still needed by homelab. Track B creates a new service account per machine (B13).
- **Komodo 1Password item:** `Private/Komodo CLI` created (B13).
- **Rectangle:** no export needed; B13 enforces its settings as defaults.
- **DEVONthink:** stays on v3 as a manual install (B8). Homebrew's stale `devonthink` record was moved to `~/dotfiles-backup-2026-10-22/stale/caskroom-devonthink`, not removed with `brew uninstall`, which could have deleted the live `DEVONthink 3.app` (3.9.18, untouched).
- **Manual checks:** VS Code, a new Claude Code session, Docker's 1Password prompting (one prompt, then none) and Cloudflare MCP auth all pass.

Still open: nothing. Track B can start.

## Open questions to resolve during execution

- Does `mise upgrade rust` update the `stable` channel, or is `rustup update` still needed? (A2)
  - **Not conclusive yet:** stable is already current (1.99.1), and `mise outdated` doesn't list rust at all. Use the fallback (`rustup update`) and re-check when the next stable release ships.
  - **Decided fallback:** if not, keep `rust = "stable"` and run `rustup update` for toolchain updates — the one documented exception to "`mise upgrade` updates everything".
- Where does the `cargo:` backend install binaries, and does shims mode expose `cargo` without `~/.cargo/env`? (A1/A2)
  - **Answered:** binaries go to `~/.local/share/mise/installs/cargo-<name>/<version>/bin`. Shims mode exposes `cargo`, `rustc` and the tools without `~/.cargo/env`.
  - **Decided fallback:** keep the cargo tools in mise regardless; if shims mode has a gap, fix it in the shell (e.g. add mise's shims/installs dir to `.path` for non-interactive shells) rather than moving tools back to `~/.cargo/bin`.
- Does mise parse `packageManager` values with a `+sha512.…` suffix? (A2)
  - **Answered: yes.** railway-effects resolves pnpm 9.9.0 and desktop-postflop resolves yarn 1.22.22. No fallback is needed.

## Post-migration evaluation

**No repo under `~/Code` is modified by this plan.** After Track A soaks, evaluate each of these and decide whether any follow-up is needed:

| Repo | Situation under mise | Things to consider |
|---|---|---|
| `JavaScript/export-content-frontend` (no longer developed) | `engines.node: ^22.6`, no version file. fnm resolved a 22.x; mise ignores `engines` and gives global Node 24. | Probably nothing. If ever run again: `mise exec node@22 -- …`, or an untracked `mise.local.toml`. |
| `JavaScript/meridian` (third-party) | `packageManager: bun@1.3.11` is not read (mise only reads npm/pnpm/yarn there); `engines.node >=22` is satisfied by 24. | Whether global `bun = "latest"` drifting from 1.3.11 matters; if so, an untracked `mise.local.toml` rather than an upstream change. |
| `JavaScript/railway-effects`, `JavaScript/desktop-postflop` | `packageManager` with `+sha512` suffix. | **Resolved in A2:** mise reads both (pnpm 9.9.0, yarn 1.22.22). Nothing to do. |
| `Python/pycon2018` | `.python-version` = 3.8.3 (EOL). | Whether mise has a precompiled 3.8.3 or would compile from source; likely archive or ignore. |
| `Elixir/dialyxir` | `.tool-versions` (elixir 1.12.2 / erlang 24.0.5) — read by mise natively, will report missing tools on `cd`. | Install via mise (erlang compiles from source, slow), ignore the warning, or archive. |
| `Infra/claudev` | `docker/mise.toml` is the in-container config (linux-amd64 `http:tea` URL); mise on the host will read it when you `cd` into `docker/` and prompt for trust. | Don't trust it on the host, or decide whether it should live elsewhere. |
| JS repos with only `engines.node >=N` (`sport-video-torznab`, `pipe-dom`, `prismjs`, `create-restful-swr`) | Satisfied by global Node 24. | Nothing expected; spot-check if touched. |
| `Rust/neon` | Pins Rust 1.77.0. | Keep the toolchain installed; nothing else. |
| `JavaScript/cal-timeblock-sync` | Its committed `.claude/settings.json` enables `cloudflare@claude-plugins-official`, which duplicates the user-scope `cloudflare@cloudflare`. | Drop it from that file (an edit to that repo), then run `claude plugin uninstall --scope project cloudflare@claude-plugins-official` there. |