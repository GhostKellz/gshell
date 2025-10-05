# GShell Out-of-the-Box Experience - Complete Design

Based on analysis of your `.zshrc` and `.p10k.zsh` configuration.

## Your Current Setup

**Prompt:** Powerlevel10k + Starship (both together!)
**Colors:** Vivid with `ghost-hacker-blue.yml` theme (aquamarine/teal/blue)
**Tools:** zoxide, fzf, direnv, eza
**Plugins:** git, zsh-autosuggestions, zsh-syntax-highlighting
**Aliases:** Git shortcuts, network tools, dev tools

## GShell Out-of-the-Box Components

### 1. GPPrompt (Ghostlang-based prompts via .gza)

Name: `gprompt` (not "ghostprompt")

Users write prompts in Ghostlang:
```lua
-- ~/.config/gshell/prompts/ghostkellz.gza
local gprompt = require("gprompt")
local prompt = gprompt.new({ style = "rainbow", layout = "two-line" })

prompt:add_segment("os_icon", { text = " 󰣇 ", bg = 33, fg = 18 })
prompt:add_segment("user", { text = " 󰊠 GhostKellz.sh 󰊠 ", bg = 17, fg = 122 })
prompt:add_segment("dir", { truncate = 3 })

if gprompt.in_git_repo() then
    prompt:add_segment("git", { text = "  " .. gprompt.git_branch() })
end

return prompt:render()
```

### 2. Vivid Integration (LS_COLORS)

Bundle all 5 themes in `assets/vivid/`:
- ghost-hacker-blue.yml (PRIMARY)
- dracula.yml
- tokyonight-moon/night/storm.yml

Auto-load in .gshrc:
```lua
load_vivid_theme("ghost-hacker-blue")
```

### 3. GhostPlug Plugins (Built-in)

Ship with 6 core plugins in `src/ghostplug/`:
- **git** - Git aliases (gcm, gaa, gps)
- **docker** - Docker shortcuts
- **kubectl** - K8s management
- **network** - Network tools (pgd, p8, myip, portscan)
- **dev-tools** - Dev aliases (vi=nvim, ls=eza, zigv, pyver)
- **system** - System utilities

### 4. CLI Tool Integration

Auto-detect and integrate:
- zoxide (smart cd)
- fzf (fuzzy finder)
- direnv (auto env loading)
- starship (optional alternative to gprompt)

### 5. Default .gshrc

Based on your exact setup:
```lua
-- GhostKellz Edition
setenv("EDITOR", "nvim")
load_vivid_theme("ghost-hacker-blue")
use_prompt("gprompt:ghostkellz")
enable_plugin("git", "docker", "kubectl", "network", "dev-tools")

-- Integrations
if command_exists("zoxide") then exec("zoxide init gshell") end
if command_exists("direnv") then exec("direnv hook gshell") end

-- Syntax highlighting colors
set_highlight_color("command", "#7FFFD4")  -- Aquamarine
set_highlight_color("builtin", "#98ff98")  -- Mint

-- History
set_history_size(10000)
```

### 6. Directory Structure

```
gshell/
├── assets/vivid/          # Bundled themes
├── examples/
│   ├── gshrc-ghostkellz   # Your config
│   ├── starship-ghostkellz.toml
│   └── prompts/ghostkellz.gza
└── src/ghostplug/         # Built-in plugins
    ├── git/
    ├── docker/
    ├── kubectl/
    ├── network/
    ├── dev-tools/
    └── system/
```

## Implementation Phases

**Phase 1 (Alpha):** Basics
- ✅ Starship integration
- ⏳ Vivid theme bundling
- ⏳ 3 core plugins (git, network, dev-tools)
- ⏳ Default .gshrc template

**Phase 2 (Beta):** GPPrompt
- ⏳ GPPrompt engine in Zig
- ⏳ .gza scripting API
- ⏳ ghostkellz.gza prompt
- ⏳ Full GhostPlug system

**Phase 3 (v1.0):** Polish
- ⏳ All 6 plugins
- ⏳ Modular config (rc.d/)
- ⏳ CLI tool integrations
- ⏳ zsh migration tools

## First Run Experience

```bash
$ gshell
🎨 Welcome to GShell!

✓ Created ~/.config/gshell/
✓ Loaded vivid theme: ghost-hacker-blue
✓ Enabled plugins: git, docker, network, dev-tools
✓ GPPrompt loaded: ghostkellz style

 󰣇   󰊠 GhostKellz.sh 󰊠  ~/projects
❯
```

## Immediate Actions Available

1. Copy vivid themes to `assets/vivid/`
2. Create default `.gshrc` matching your setup
3. Create 3 core GhostPlug plugins
4. Create `starship-ghostkellz.toml`

Estimated time: ~30 minutes for basics.
