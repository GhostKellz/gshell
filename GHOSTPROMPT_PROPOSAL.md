# GhostPrompt - Prompt System Proposal for GShell

## Analysis: Your p10k Setup

I reviewed your `.p10k.zsh` (1883 lines!) and see you have:

**Left Prompt:**
- Custom Arch logo (󰣇)
- GhostKellz.sh branding with Nerd Fonts
- Directory + Git status
- 2-line disconnected layout

**Right Prompt (27+ segments!):**
- Language versions: node, rust, go, python, ruby, lua, java, php
- Version managers: asdf, pyenv, nodenv, goenv, nvm, rbenv, rvm
- Cloud providers: kubecontext, terraform, aws, azure, gcloud
- Tools: nordvpn, ranger, yazi, nnn, toolbox, time
- Status, execution time, background jobs

**Style:** Rainbow powerline with Nerd Font v3 icons

## Recommendation: Three-Tier Hybrid System

### Tier 1: Starship (Default - Ship Now)
**Best for:** 90% of users, cross-platform compatibility

✅ **Already works** - Just enable `use_starship(true)` in .gshrc
✅ **100+ modules** - All your segments supported (node, rust, k8s, aws, etc.)
✅ **Fast** - Rust-native performance
✅ **Maintained** - Active development, cross-platform

**I can create `examples/starship-ghostkellz.toml` matching your exact p10k style in ~30 min**

### Tier 2: GhostPrompt (Power Users - Build for Beta)
**Best for:** Native performance, full control, p10k compatibility

✅ **Native Zig** - Faster than Starship, no external deps
✅ **p10k-compatible** - Eventually parse `.p10k.zsh` configs
✅ **Extensible** - Via GhostPlug plugins
✅ **gcode integration** - Proper Unicode/emoji width handling

**Would be ~100 lines of `ghostprompt.toml` vs 1883 lines of `.p10k.zsh`**

### Tier 3: Custom Prompts (Hackers - Future)
**Best for:** 100% custom logic in Ghostlang

```lua
function render_prompt()
    local branch = exec("git branch --show-current")
    return " 󰣇  " .. getenv("USER") .. " @ " .. getenv("PWD") ..
           (branch and " " .. branch or "") .. "\n❯ "
end
```

## Implementation Plan

### Phase 1: Starship (Immediate - Alpha) ✅
1. Create `examples/starship-ghostkellz.toml` with your style
2. Enable by default in `.gshrc`
3. Ship with Alpha

**Timeline:** Can do this RIGHT NOW

### Phase 2: GhostPrompt Core (Beta)
1. Create `src/ghostprompt.zig`
2. Implement 10-15 core segments (os, user, dir, git, node, rust, k8s, aws, time)
3. TOML config parsing
4. Powerline rendering with gcode

**Timeline:** 1 week

### Phase 3: Extended Segments (Beta → v1.0)
Implement remaining 40+ segments to match your p10k config

**Timeline:** 2 weeks

### Phase 4: p10k Compatibility (v1.0+)
Parse `.p10k.zsh` and convert to GhostPrompt config

**Timeline:** 1 week

## My Suggestion

**For out-of-the-box functionality:**

Ship with **BOTH Starship AND GhostPrompt**:

1. **Default: Starship** (works NOW)
   - Pre-configured with your style
   - Cross-platform, zero code
   - 90% of users satisfied

2. **Advanced: GhostPrompt** (build for Beta)
   - Native Zig performance
   - p10k migration path
   - Power user option

Enable in `.gshrc`:
```lua
-- Option 1: Starship (default)
use_starship(true)

-- Option 2: GhostPrompt (native, beta+)
-- use_prompt("ghostprompt")
```

## Next Step

**Want me to create `examples/starship-ghostkellz.toml` matching your p10k style?**

I can configure:
- Rainbow powerline separators
- 2-line layout
- Custom Arch logo + GhostKellz branding
- All 27+ right-side segments
- Your exact color scheme

Would take ~30 minutes and give you p10k-level prompts immediately.
