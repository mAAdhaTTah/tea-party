# Inventory triage

Every hand-installed item found on this machine (2026-10-22) that the repo doesn't already declare, plus repo items that no longer match the machine. Each row gets one decision (step A6 of [the mise migration plan](mise-migration-plan.md)):

- **keep**: add it to the repo, so a fresh machine gets it.
- **ignore**: leave it installed here, but keep it out of the repo.
- **uninstall**: remove it from this machine too.

"Suggested" was my guess; "Decision" is final (reviewed together 2026-10-25). Track B uses only the rows marked keep. DEVONthink stays on v3 as a manual install. The machine-side uninstalls, installs and setting changes were applied on 2026-10-25 (see the plan's execution log). One exception: `cloudflare@claude-plugins-official` stays installed until cal-timeblock-sync drops it from its committed settings.

## Homebrew formulae

| Formula                                      | What it is                                                   | Suggested                           | Decision  |
| -------------------------------------------- | ------------------------------------------------------------ | ----------------------------------- | --------- |
| actionlint                                   | GitHub Actions workflow linter                               | keep                                | uninstall |
| cloudflared                                  | Cloudflare Tunnel client                                     | keep                                | keep      |
| codecrafters (tap `codecrafters-io/tap`)     | CodeCrafters course CLI                                      | ignore                              | uninstall |
| colima                                       | Container runtime (Docker VM). Replaced by the remote daemon (plan A9) | keep                                | uninstall (done 2026-10-25) |
| docker                                       | Docker CLI, pointed at four-of-four (plan A9)                | keep                                | keep      |
| docker-compose                               | Compose plugin (works with the remote daemon)                | keep                                | keep      |
| qemu                                         | Machine emulator colima used. Replaced by the remote daemon (plan A9) | keep if colima uses it, else ignore | uninstall (done 2026-10-25) |
| docker-buildx                                | BuildKit builds via the remote daemon (installed in plan A9) | keep                                | keep      |
| lima                                         | colima's VM layer                                            | uninstall                           | uninstall (done 2026-10-25) |
| ffmpeg                                       | Audio/video tool; yt-dlp uses it for merging                 | keep                                | uninstall |
| yt-dlp                                       | Video downloader                                             | keep                                | uninstall |
| findutils                                    | GNU find/xargs (pairs with coreutils)                        | keep                                | keep + put gnubin on PATH |
| gh                                           | GitHub CLI (also the git credential helper)                  | keep                                | keep |
| tea                                          | Gitea CLI (used by the claudev skills)                       | keep                                | keep |
| lazygit                                      | Terminal git UI                                              | keep                                | ignore |
| tmux                                         | Terminal multiplexer                                         | keep                                | uninstall |
| oh-my-posh (tap `jandedobbeleer/oh-my-posh`) | Prompt theme; your bash-it theme needs it                    | keep                                | keep |
| neonctl                                      | Neon CLI                                                     | keep                                | keep |
| wasm-pack                                    | Rust to wasm builds (spotlab)                                | keep                                | move to mise (`cargo:wasm-pack`), uninstall brew formula |
| opencode                                     | Terminal coding agent                                        | keep                                | uninstall |
| pi-coding-agent                              | AI agent toolkit                                             | ignore                              | uninstall |
| supabase (tap `supabase/tap`)                | Supabase CLI                                                 | ignore                              | uninstall |
| km (tap `moghtech/komodo`)                   | Komodo (homelab) CLI                                         | keep                                | keep + manage `~/.config/komodo/komodo.cli.toml` (key/secret from 1Password) |
| homebutler (tap `higangssh/homebutler`)      | Server change summaries                                      | ignore                              | uninstall |
| recyclarr (tap `recyclarr/recyclarr`)        | Syncs TRaSH guides to Sonarr/Radarr                          | ignore                              | uninstall |
| git-filter-repo                              | Rewrites git history (one-off tool)                          | ignore                              | uninstall |
| sigtop (tap `tbvdm/tap`)                     | Signal Desktop message export                                | ignore                              | uninstall |
| poppler                                      | PDF tools (`pdftotext` etc.)                                 | ignore                              | keep |
| nmap                                         | Port scanner                                                 | ignore                              | uninstall |
| iperf3                                       | Network bandwidth test                                       | ignore                              | uninstall |
| smartmontools                                | Disk SMART monitoring                                        | ignore                              | uninstall |
| snitch                                       | Network connection inspector                                 | ignore                              | uninstall |
| superfile                                    | Terminal file manager                                        | ignore                              | uninstall |
| telnet                                       | Telnet client                                                | ignore                              | uninstall |

A tap goes into the repo only if a formula or cask from it is kept. `bash`, `dockutil` and `mise` are installed by roles, so they need no decision.

## Homebrew casks

| Cask                                  | Notes                                          | Suggested     | Decision |
| ------------------------------------- | ---------------------------------------------- | ------------- | -------- |
| anki                                  | Flashcards                                     | keep          | uninstall |
| claude-code@latest                    | Claude Code                                    | keep          | keep |
| ghostty                               | Terminal (replaced iTerm in the Dock)          | keep          | keep |
| font-fira-code-nerd-font              | VS Code terminal font                          | keep          | keep |
| mountain-duck                         | Mounts servers as disks                        | keep          | keep |
| zoom                                  | Video calls                                    | keep          | keep |
| flux-app                              | Repo has the old `flux` name                   | keep (rename) | keep (rename) |
| syncthing-app                         | Repo has the old `syncthing` name              | keep (rename) | keep (rename) |
| tailscale-app                         | Repo has the old `tailscale` name              | keep (rename) | keep (rename) |
| todoist-app                           | Repo has the old `todoist` name                | keep (rename) | keep (rename) |
| gitkraken-cli                         | GitKraken CLI (GitLens AI uses it)             | ignore        | uninstall |
| t3-code                               | GUI for code agents (beta)                     | ignore        | keep |
| tokeneater (tap `athevon/tokeneater`) | Claude usage monitor                           | ignore        | keep |
| anytype                               | App deleted                                    | uninstall     | uninstall |
| claude                                | Claude desktop app; app deleted                | uninstall     | uninstall |
| comfy / comfyui                       | App deleted (comfyui is the old name of comfy) | uninstall     | uninstall |
| dayflow                               | App deleted                                    | uninstall     | uninstall |
| gitkraken                             | App deleted                                    | uninstall     | uninstall |
| lm-studio                             | App deleted                                    | uninstall     | uninstall |
| lookaway                              | App deleted                                    | uninstall     | uninstall |
| ollama-app                            | App deleted                                    | uninstall     | uninstall |
| omnidisksweeper                       | App deleted                                    | uninstall     | uninstall |
| zed                                   | App deleted                                    | uninstall     | uninstall |

`visual-studio-code` is installed by the editor role.

## Repo items that no longer match the machine

| Item                                    | Problem                                                                     | Suggested                                                                               | Decision |
| --------------------------------------- | --------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- | -------- |
| `iterm2` cask                           | Ghostty replaced it in the Dock                                             | uninstall and drop from repo                                                            | uninstall and drop from repo |
| `devonthink` cask                       | The cask now installs `DEVONthink.app` (v4), but you run `DEVONthink 3.app` | decide: upgrade to the v4 cask, or drop from the repo and list v3 under manual installs | drop from repo; DEVONthink 3 listed under manual installs (B8); move back to the `devonthink` cask on upgrading to v4 |
| `font-cutive-mono` cask                 | `editor.fontFamily` no longer uses it                                       | drop from repo (ignore)                                                                 | keep in repo |
| `atlassian.atlascode` VS Code extension | In the repo, not installed (`atlascode.jira.enabled: false` in settings)    | drop from repo                                                                          | keep in repo |
| Dock: GTO Wizard Chrome app             | In the repo's Dock list, not in the live Dock                               | drop from repo                                                                          | drop from repo |

## Global mise tools

| Tool                | Notes                                                                  | Suggested | Decision |
| ------------------- | ---------------------------------------------------------------------- | --------- | -------- |
| `cargo-binstall`    | Installs Rust tools from prebuilt binaries                             | keep      | keep |
| `cargo:cargo-insta` | Snapshot testing (pairs with the `mitsuhiko.insta` extension)          | keep      | keep |
| `cargo:sqlx-cli`    | SQLx migrations CLI                                                    | keep      | keep |
| `cargo:sampo`       | Release and changelog tool                                             | keep      | keep |
| `npm:skills`        | Agent skills installer; the Cloudflare skills now come from the plugin | ignore    | uninstall |

## VS Code extensions (installed, not in repo)

| Extension                                                                                                    | Notes                                                             | Suggested | Decision |
| ------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------- | --------- | -------- |
| anthropic.claude-code                                                                                        | Claude Code                                                       | keep      | keep |
| docker.docker                                                                                                | Docker                                                            | keep      | keep |
| ms-azuretools.vscode-containers                                                                              | Successor to `ms-azuretools.vscode-docker` (which is in the repo) | keep      | keep; drop `ms-azuretools.vscode-docker` from repo |
| github.vscode-github-actions                                                                                 | Actions workflows                                                 | keep      | keep |
| mitsuhiko.insta                                                                                              | insta snapshots                                                   | keep      | keep |
| ms-python.vscode-python-envs                                                                                 | Python environments                                               | keep      | keep |
| oxc.oxc-vscode                                                                                               | oxc lint/format (`oxc.enable` is set)                             | keep      | keep |
| sdras.night-owl                                                                                              | Night Owl Light (your `preferredLightColorTheme`)                 | keep      | keep |
| tauri-apps.tauri-vscode                                                                                      | Tauri                                                             | keep      | keep |
| vitest.explorer                                                                                              | Vitest                                                            | keep      | keep |
| denoland.vscode-deno                                                                                         | Deno                                                              | keep      | uninstall |
| ms-vscode.azure-repos                                                                                        | Pulled in by Remote Repositories                                  | keep      | keep |
| ms-toolsai.jupyter (+ jupyter-keymap, jupyter-renderers, vscode-jupyter-cell-tags, vscode-jupyter-slideshow) | Jupyter pack                                                      | ignore    | uninstall (all 5) |
| vue.volar                                                                                                    | Vue                                                               | ignore    | uninstall |
| continue.continue                                                                                            | Continue AI; `chat.disableAIFeatures` is on                       | uninstall | uninstall |
| danielgjackson.auto-dark-mode-windows                                                                        | Windows only                                                      | uninstall | uninstall |
| lkytal.flatui                                                                                                | Theme                                                             | ignore    | uninstall |
| maptz.regionfolder                                                                                           | Region folding                                                    | ignore    | uninstall |

## VS Code settings (live, not in repo)

| Setting                                                                                                   | Live value                                           | Suggested                 | Decision |
| --------------------------------------------------------------------------------------------------------- | ---------------------------------------------------- | ------------------------- | -------- |
| `[dockercompose]`, `[github-actions-workflow]`, `[markdown]`                                              | Per-language formatter and indentation               | keep                      | keep |
| `ansibleVault.executable`                                                                                 | `pkgx +ansible ansible-vault`                        | keep                      | keep |
| `chat.disableAIFeatures`                                                                                  | true                                                 | keep                      | keep |
| `github.copilot.enable`                                                                                   | all false                                            | keep                      | keep |
| `claudeCode.hideOnboarding`, `claudeCode.preferredLocation`                                               | true, `"panel"`                                      | keep                      | keep |
| `diffEditor.ignoreTrimWhitespace`                                                                         | false                                                | keep                      | keep |
| `docker.extension.enableComposeLanguageServer`                                                            | false                                                | keep                      | keep |
| `editor.unicodeHighlight.ambiguousCharacters`                                                             | false                                                | keep                      | keep |
| `git.confirmSync`                                                                                         | false                                                | keep                      | keep |
| `githubPullRequests.pushBranch`                                                                           | `"always"`                                           | keep                      | keep |
| `json.schemaDownload.trustedDomains`                                                                      | schemastore and GitHub                               | keep                      | keep |
| `notebook.editorOptionsCustomizations`                                                                    | tab size 4                                           | keep                      | remove from live (goes with Jupyter) |
| `oxc.enable`                                                                                              | true                                                 | keep (with the extension) | keep |
| `python.analysis.typeCheckingMode`                                                                        | `"basic"`                                            | keep                      | keep |
| `rust-analyzer.check.command`                                                                             | `"clippy"`                                           | keep                      | keep |
| `terminal.integrated.fontFamily`                                                                          | FiraCode Nerd Font Mono                              | keep (with the font cask) | keep |
| `window.autoDetectColorScheme`, `workbench.preferredDarkColorTheme`, `workbench.preferredLightColorTheme` | false, Night Owl Black, Night Owl Light              | keep                      | keep |
| `yaml.disableSchemaDetection`                                                                             | Workflow globs                                       | keep                      | keep |
| `atlascode.jira.enabled`                                                                                  | false                                                | follows atlascode         | keep |
| `gitlens.ai.model`, `gitlens.ai.gitkraken.model`                                                          | GitKraken / Gemini                                   | ignore                    | remove from live |
| `yaml.schemas`                                                                                            | Points into a versioned Continue extension directory | ignore (machine-specific) | remove from live |
| `cSpell.userWords` (changed)                                                                              | Live list is longer                                  | keep live                 | keep live |
| `editor.cursorSmoothCaretAnimation` (changed)                                                             | `"on"` (repo has `true`)                             | keep live, quoted         | keep `"on"` (quoted string; `"on"` = always animate) |
| `editor.fontFamily` (changed)                                                                             | Cutive Mono dropped                                  | keep live                 | keep, reordered: Source Code Pro, Cutive Mono, then the rest (live and repo) |

## Claude Code

| Item                                                         | Notes                                                   | Suggested | Decision |
| ------------------------------------------------------------ | ------------------------------------------------------- | --------- | -------- |
| Marketplace `claude-plugins-official`                        | Built in                                                | keep      | keep |
| Marketplace `cloudflare` (`cloudflare/skills`)               |                                                         | keep      | keep |
| Marketplace `claudev` (git over SSH)                         |                                                         | keep      | keep |
| Marketplace `doist` (`doist/todoist-mcp`)                    |                                                         | keep      | keep |
| Marketplace `readwise-skills` (`readwiseio/readwise-skills`) |                                                         | keep      | keep |
| Plugins `rust-analyzer-lsp`, `typescript-lsp`                | Enabled                                                 | keep      | keep |
| Plugins `todoist@doist`, `readwise@readwise-skills`          | Enabled                                                 | keep      | keep |
| Plugins `local-agent@claudev`, `core-agent@claudev`          | Enabled                                                 | keep      | keep local-agent; uninstall core-agent (retired) |
| Plugin `cloudflare@cloudflare`                               | Enabled (installed in A7)                               | keep      | keep |
| Plugin `frontend-design@claude-plugins-official`             | Installed, disabled                                     | ignore    | uninstall |
| Plugin `cloudflare@claude-plugins-official`                  | Installed, disabled; duplicates `cloudflare@cloudflare` | uninstall | uninstall |
| MCP server `Neon`                                            | `https://mcp.neon.tech/mcp`                             | keep      | keep |
| MCP server `ogham`                                           | `https://ogham.8p.jamesdigioia.com/mcp`                 | keep      | keep |

Your claude.ai connectors (Gmail, Calendar, Drive, Claude Docs) belong to your account, not this machine, so they need no decision.

## Dock

Live order: Chrome, Todoist, Obsidian, VS Code, Ghostty, Slack, Signal, Messages (Chrome app), Keybase, WhatsApp, Discord, Spotify, Reader.

| Item                                      | Notes                          | Suggested | Decision |
| ----------------------------------------- | ------------------------------ | --------- | -------- |
| Ghostty                                   | Added by hand, replacing iTerm | keep      | keep |
| Live order (VS Code moved ahead of Slack) |                                | keep      | keep |

## Apps not installed by Homebrew

Kept items go into the README's "Manual installs" list (B8).

| App                                | Source                 | Suggested                      | Decision |
| ---------------------------------- | ---------------------- | ------------------------------ | -------- |
| Brother iPrint&Scan                | App Store              | keep                           | keep |
| Developer                          | App Store              | keep                           | keep |
| Pandan                             | App Store              | keep                           | keep |
| Paprika Recipe Manager 3           | App Store              | keep                           | keep |
| Simon Says                         | App Store              | keep                           | keep |
| Brother (printer drivers)          | Vendor installer       | keep                           | keep |
| Logi Options+                      | Vendor installer       | keep                           | keep |
| Exodus                             | Vendor download        | keep                           | keep |
| ClubWPT Gold                       | Vendor download        | ignore                         | keep |
| GTO Wizard, Messages (Chrome apps) | Installed from Chrome  | keep (Messages is in the Dock) | keep (both) |
| Claude Code URL Handler            | Created by Claude Code | ignore                         | ignore |

## Found while preparing this list

These are context only; they need no decision.

- `/pkg/env/global/bin` is on every shell's PATH via `/etc/paths.d/10-pmk-global`, but the directory doesn't exist. **Decision: leave it.**
  - It isn't from pkgx: pkgx lives at `/usr/local/bin/pkgx` with data in `~/.pkgx`, and nothing of its uses `/pkg`.
  - The file has no installer receipt and the same root-owned timestamp (2026-04-30 15:33) as Apple's `10-cryptex` next to it, so it most likely ships with macOS 26.
- The bash-it `go` plugin sets `GOPATH=~/go` in interactive shells. Go is installed, but Homebrew records it as a dependency rather than something you asked for (likely a build dependency). **Decision: disable the bash-it `go` plugin and completion here, and drop both from `bash-it.yml` (B4).**
