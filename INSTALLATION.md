# GShell Installation Guide

## Quick Install

### One-Liner (Recommended)

Install GShell with a single command:

```bash
curl -fsSL https://raw.githubusercontent.com/ghostkellz/gshell/main/install.sh | bash
```

This script will:
- ✅ Detect your OS and architecture
- ✅ Download and build GShell (or use pre-built binary)
- ✅ Install to `~/.local/bin/gshell`
- ✅ Set up PATH automatically
- ✅ Show optional dependencies

---

## Distribution Packages

### Arch Linux

#### From AUR

```bash
# Using yay
yay -S gshell

# Using paru
paru -S gshell
```

#### Manual PKGBUILD Installation

```bash
# Clone the repository
git clone https://github.com/ghostkellz/gshell.git
cd gshell

# Build and install with makepkg
makepkg -si
```

The PKGBUILD will:
- Build from source using Zig
- Install to `/usr/bin/gshell`
- Install templates to `/usr/share/gshell/`
- Show post-install instructions

---

## Build from Source

### Prerequisites

- **Zig** 0.14.0 or later ([download](https://ziglang.org/download/))
- **Git**

### Steps

```bash
# 1. Clone repository
git clone https://github.com/ghostkellz/gshell.git
cd gshell

# 2. Build
zig build -Doptimize=ReleaseFast

# 3. Install
sudo cp zig-out/bin/gshell /usr/local/bin/

# 4. Verify installation
gshell --version
```

---

## As a Zig Dependency

Add GShell to your Zig project:

### In `build.zig.zon`:

```zig
.{
    .name = "my-project",
    .version = "0.1.0",
    .dependencies = .{
        .gshell = .{
            .url = "https://github.com/ghostkellz/gshell/archive/refs/heads/main.tar.gz",
            .hash = "...", // Run zig fetch to get the hash
        },
    },
}
```

### Fetch the dependency:

```bash
zig fetch --save https://github.com/ghostkellz/gshell/archive/refs/heads/main.tar.gz
```

---

## First Run Setup

When you run GShell for the first time, you'll see an interactive **⚡ Setup Wizard**:

```bash
gshell
```

The wizard will help you:

1. **Choose Prompt Style**
   - Starship (recommended)
   - Git Prompt
   - Minimal

2. **Select Color Theme**
   - Ghost Hacker Blue (default - deep blues & cyans)
   - Mint Fresh (mint greens & light teals)
   - Teal Ocean (deep teals & aqua blues)
   - Dracula (purple & pink classic)
   - Tokyo Night (night blues)

3. **Enable Plugins**
   - Git integration
   - Network utilities
   - Docker integration
   - Development tools

4. **Auto-generate Configuration**
   - Creates `~/.gshrc.gza` with your preferences
   - Sets up `~/.config/starship.toml` (if Starship selected)
   - Applies secure file permissions (600)

---

## Optional Dependencies

These are recommended but not required:

### Starship Prompt (Highly Recommended)

```bash
# Arch Linux
sudo pacman -S starship

# Other distros
curl -sS https://starship.rs/install.sh | sh
```

### Modern CLI Tools

```bash
# Arch Linux
sudo pacman -S eza vivid bat fd ripgrep

# Ubuntu/Debian
sudo apt install bat fd-find ripgrep
cargo install eza
```

- **eza**: Modern `ls` with colors and icons
- **vivid**: LS_COLORS theme generator
- **bat**: `cat` with syntax highlighting
- **fd**: Fast alternative to `find`
- **ripgrep**: Fast grep alternative

---

## Make GShell Your Default Shell

### 1. Add to `/etc/shells`

```bash
echo "$HOME/.local/bin/gshell" | sudo tee -a /etc/shells

# Or if installed system-wide:
echo "/usr/bin/gshell" | sudo tee -a /etc/shells
```

### 2. Change your default shell

```bash
chsh -s "$HOME/.local/bin/gshell"

# Or if installed system-wide:
chsh -s /usr/bin/gshell
```

### 3. Log out and back in

Your next login will use GShell!

---

## Uninstall

### Remove Binary

```bash
# If installed to ~/.local/bin
rm ~/.local/bin/gshell

# If installed to /usr/local/bin
sudo rm /usr/local/bin/gshell

# If installed via AUR
yay -R gshell
```

### Remove Configuration (Optional)

```bash
# Remove all GShell configuration
rm -rf ~/.gshrc.gza ~/.gshell_history ~/.config/gshell
```

### Change Default Shell Back

```bash
chsh -s /bin/bash
```

---

## Troubleshooting

### `gshell: command not found`

Make sure `~/.local/bin` is in your PATH:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

Add this to your `~/.bashrc` or `~/.zshrc` to make it permanent.

### Build Errors

Make sure you have Zig 0.14.0 or later:

```bash
zig version
```

If not, download the latest from https://ziglang.org/download/

### Permission Denied

If you see permission errors when creating config files, check:

```bash
ls -la ~/.gshrc.gza ~/.config/gshell
```

GShell automatically sets secure permissions (600 for files, 700 for directories).

---

## Getting Help

- 📖 **Documentation**: [README.md](./README.md)
- 🐛 **Issues**: https://github.com/ghostkellz/gshell/issues
- 💬 **Discussions**: https://github.com/ghostkellz/gshell/discussions

---

**⚡ Enjoy your next generation shell experience!**
