# GShell Assets

Bundled resources for out-of-the-box GShell functionality.

## Directory Structure

```
assets/
├── vivid/           # Vivid color themes for LS_COLORS
├── templates/       # Configuration templates
└── plugins/         # Built-in GhostPlug plugins
```

## Vivid Themes

Pre-configured vivid themes for file listing colors:

- **ghost-hacker-blue.yml** (PRIMARY) - Custom aquamarine/teal/blue theme
- **dracula.yml** - Dracula color scheme
- **tokyonight-moon.yml** - Tokyo Night Moon variant
- **tokyonight-night.yml** - Tokyo Night Night variant
- **tokyonight-storm.yml** - Tokyo Night Storm variant

### Usage

```lua
-- In ~/.gshrc
load_vivid_theme("ghost-hacker-blue")
```

Or set via environment:
```bash
export GSHELL_VIVID_THEME=dracula
```

## Configuration Templates

### gshrc-ghostkellz

Complete `.gshrc` configuration matching GhostKellz setup:
- Starship prompt integration
- Vivid theme loading (ghost-hacker-blue)
- Core aliases (git, network, dev-tools)
- CLI tool integrations (zoxide, direnv, fzf)
- Syntax highlighting colors

**Installation:**
```bash
cp assets/templates/gshrc-ghostkellz ~/.gshrc
```

### starship-ghostkellz.toml

Starship prompt configuration matching Powerlevel10k style:
- 2-line rainbow powerline layout
- Custom Arch logo (󰣇)
- GhostKellz branding (󰊠 GhostKellz.sh 󰊠)
- 27+ segments (os, user, dir, git, languages, k8s, aws, time)
- Nerd Font v3 icons

**Installation:**
```bash
cp assets/templates/starship-ghostkellz.toml ~/.config/starship.toml
```

## GhostPlug Plugins

Core plugins bundled with GShell:

### Git Plugin (`git/`)

Git shortcuts and workflows:
- **Aliases**: gs, ga, gaa, gc, gcm, gps, gpl, gb, gco, gd, gl
- **Functions**: `gcp()` (quick commit+push), `gundo()` (undo commit), `gfix()` (quick amend)

### Network Plugin (`network/`)

Network diagnostics for IT professionals:
- **Aliases**: pgd, p8, myip, portscan, dnsflush, listening, ports
- **Functions**: `portcheck()`, `netinfo()`, `pingtest()`
- **Built-ins**: net-test, net-resolve, net-fetch, net-scan

### Dev Tools Plugin (`dev-tools/`)

Modern CLI utilities and development tools:
- **Editor**: vi → grim (custom Zig editor) or nvim
- **Listing**: ls → eza (with icons, tree view)
- **Cat**: cat → bat (syntax highlighting)
- **Grep**: grep → ripgrep
- **Find**: find → fd
- **Docker**: d, dc, dps, di, dex, dlogs
- **Kubernetes**: k, kg, kd, klog, kex
- **Functions**: `mkcd()`, `extract()`

## Plugin Loading

Plugins are loaded via `.gshrc`:

```lua
-- Enable individual plugins
enable_plugin("git")
enable_plugin("network")
enable_plugin("dev-tools")

-- Or enable multiple at once
enable_plugin("git", "network", "dev-tools")
```

## Installation Workflow

### First-Time Setup

1. **Copy config template:**
   ```bash
   cp assets/templates/gshrc-ghostkellz ~/.gshrc
   ```

2. **Copy Starship config:**
   ```bash
   mkdir -p ~/.config
   cp assets/templates/starship-ghostkellz.toml ~/.config/starship.toml
   ```

3. **Run GShell:**
   ```bash
   gshell
   ```

GShell will automatically:
- Load vivid theme (ghost-hacker-blue)
- Enable Starship prompt
- Initialize plugins
- Integrate CLI tools (zoxide, direnv, fzf)

### Customization

**Change vivid theme:**
```lua
-- In ~/.gshrc
load_vivid_theme("dracula")  -- or tokyonight-moon, etc.
```

**Switch prompt:**
```lua
-- Option 1: Starship (TOML-based, stable)
use_starship(true)

-- Option 2: GPrompt (native Zig, beta)
use_prompt("gprompt:ghostkellz")
```

**Add custom plugins:**
```bash
mkdir -p ~/.config/gshell/plugins/my-plugin
# Create manifest.toml and plugin.gza
enable_plugin("my-plugin")  # In .gshrc
```

## Future Additions

Planned for Beta/v1.0:
- **docker/** - Docker workflow plugin
- **kubectl/** - Kubernetes management plugin
- **system/** - System utilities plugin
- **GPrompt engine** - Native Zig prompt system
- **Plugin manager** - `gplug install/update/remove`

## See Also

- [GHOSTPLUG_DESIGN.md](../GHOSTPLUG_DESIGN.md) - Plugin system architecture
- [GSHELL_OUTOFBOX.md](../GSHELL_OUTOFBOX.md) - Out-of-box experience design
- [GHOSTPROMPT_PROPOSAL.md](../GHOSTPROMPT_PROPOSAL.md) - Prompt system proposal
