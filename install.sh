#!/bin/bash
#
# GShell - Next Generation Shell
# Automated Installation Script
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/ghostkellz/gshell/main/install.sh | bash
#

set -e

# Colors (Teal/Mint theme)
TEAL='\033[38;5;51m'
MINT='\033[38;5;121m'
DARK_TEAL='\033[38;5;37m'
WHITE='\033[1;37m'
GRAY='\033[38;5;240m'
RED='\033[1;31m'
YELLOW='\033[1;33m'
RESET='\033[0m'
BOLD='\033[1m'

# Configuration
REPO="ghostkellz/gshell"
INSTALL_DIR="${HOME}/.local/bin"
TMP_DIR="/tmp/gshell-install-$$"

# Print functions
print_header() {
    echo
    echo -e "${TEAL}╔═══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${TEAL}║                                                               ║${RESET}"
    echo -e "${TEAL}║   ${BOLD}${MINT}█▀▀ █▀ █ █   ${TEAL}  ███╗   ██╗███████╗██╗  ██╗████████╗${RESET}${TEAL}     ║${RESET}"
    echo -e "${TEAL}║   ${BOLD}${MINT}█▄█ ▄█ █▀█   ${TEAL}████╗  ██║██╔════╝╚██╗██╔╝╚══██╔══╝${RESET}${TEAL}     ║${RESET}"
    echo -e "${TEAL}║          ${TEAL}██╔██╗ ██║█████╗   ╚███╔╝    ██║${RESET}${TEAL}          ║${RESET}"
    echo -e "${TEAL}║          ${TEAL}██║╚██╗██║██╔══╝   ██╔██╗    ██║${RESET}${TEAL}          ║${RESET}"
    echo -e "${TEAL}║          ${TEAL}██║ ╚████║███████╗██╔╝ ██╗   ██║${RESET}${TEAL}          ║${RESET}"
    echo -e "${TEAL}║          ${TEAL}╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝   ╚═╝${RESET}${TEAL}          ║${RESET}"
    echo -e "${TEAL}║                                                               ║${RESET}"
    echo -e "${TEAL}║           ${MINT}█▀▀ █▀▀ █▄ █ █▀▀ █▀█ ▄▀█ ▀█▀ █ █▀█ █▄ █${RESET}${TEAL}            ║${RESET}"
    echo -e "${TEAL}║           ${MINT}█▄█ ██▄ █ ▀█ ██▄ █▀▄ █▀█  █  █ █▄█ █ ▀█${RESET}${TEAL}            ║${RESET}"
    echo -e "${TEAL}║                                                               ║${RESET}"
    echo -e "${TEAL}║                    ${WHITE}Next Generation Shell${RESET}${TEAL}                     ║${RESET}"
    echo -e "${TEAL}║                         ${MINT}⚡ Installer${RESET}${TEAL}                          ║${RESET}"
    echo -e "${TEAL}║                                                               ║${RESET}"
    echo -e "${TEAL}╚═══════════════════════════════════════════════════════════════╝${RESET}"
    echo
}

print_step() {
    echo -e "${MINT}▸${RESET} ${WHITE}$1${RESET}"
}

print_success() {
    echo -e "${MINT}✓${RESET} $1"
}

print_error() {
    echo -e "${RED}✗ Error:${RESET} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠${RESET} $1"
}

print_info() {
    echo -e "${GRAY}  $1${RESET}"
}

# Cleanup function
cleanup() {
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
}

trap cleanup EXIT

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Do not run this script as root!"
    print_info "GShell should be installed in your user directory."
    exit 1
fi

# Detect OS
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    elif [ -f /etc/arch-release ]; then
        OS="arch"
    else
        OS=$(uname -s)
    fi

    print_step "Detected OS: ${BOLD}${OS}${RESET}"
}

# Check dependencies
check_dependencies() {
    print_step "Checking dependencies..."

    local missing_deps=()

    # Required tools
    for cmd in curl tar; do
        if ! command -v $cmd &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    # Zig compiler (optional - will download binary if missing)
    if ! command -v zig &> /dev/null; then
        print_warning "Zig compiler not found - will download pre-built binary"
        USE_PREBUILT=true
    else
        ZIG_VERSION=$(zig version 2>/dev/null || echo "unknown")
        print_info "Found Zig: ${ZIG_VERSION}"
        USE_PREBUILT=false
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_info "Please install them using your package manager:"

        case "$OS" in
            arch|manjaro)
                print_info "  sudo pacman -S ${missing_deps[*]}"
                ;;
            ubuntu|debian)
                print_info "  sudo apt install ${missing_deps[*]}"
                ;;
            fedora)
                print_info "  sudo dnf install ${missing_deps[*]}"
                ;;
            *)
                print_info "  Install: ${missing_deps[*]}"
                ;;
        esac

        exit 1
    fi

    print_success "All required dependencies found"
}

# Get latest release
get_latest_release() {
    print_step "Fetching latest release..."

    # Try GitHub API first
    LATEST_TAG=$(curl -fsSL "https://api.github.com/repos/${REPO}/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')

    # Fallback to main branch if no releases
    if [ -z "$LATEST_TAG" ]; then
        print_warning "No releases found, using main branch"
        LATEST_TAG="main"
        DOWNLOAD_URL="https://github.com/${REPO}/archive/refs/heads/main.tar.gz"
    else
        print_info "Latest version: ${BOLD}${LATEST_TAG}${RESET}"
        DOWNLOAD_URL="https://github.com/${REPO}/archive/refs/tags/${LATEST_TAG}.tar.gz"
    fi
}

# Download source
download_source() {
    print_step "Downloading GShell source..."

    mkdir -p "$TMP_DIR"
    cd "$TMP_DIR"

    if curl -fsSL "$DOWNLOAD_URL" -o gshell.tar.gz; then
        print_success "Downloaded successfully"
    else
        print_error "Failed to download from ${DOWNLOAD_URL}"
        exit 1
    fi

    print_info "Extracting..."
    tar -xzf gshell.tar.gz

    # Find the extracted directory
    EXTRACT_DIR=$(find . -maxdepth 1 -type d -name "gshell-*" | head -n 1)
    if [ -z "$EXTRACT_DIR" ]; then
        print_error "Failed to find extracted directory"
        exit 1
    fi

    cd "$EXTRACT_DIR"
}

# Build from source
build_from_source() {
    print_step "Building GShell from source..."

    if ! command -v zig &> /dev/null; then
        print_error "Zig compiler not found"
        print_info "Please install Zig 0.14.0 or later:"
        print_info "  https://ziglang.org/download/"
        exit 1
    fi

    print_info "Running: zig build -Doptimize=ReleaseFast"

    if zig build -Doptimize=ReleaseFast; then
        print_success "Build completed successfully"
    else
        print_error "Build failed"
        exit 1
    fi

    BINARY_PATH="zig-out/bin/gshell"
}

# Download pre-built binary (if available)
download_prebuilt() {
    print_step "Downloading pre-built binary..."

    # Detect architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            ARCH_NAME="x86_64"
            ;;
        aarch64|arm64)
            ARCH_NAME="aarch64"
            ;;
        *)
            print_error "Unsupported architecture: $ARCH"
            print_info "Please build from source with Zig installed"
            exit 1
            ;;
    esac

    # Try to download pre-built binary for this release
    BINARY_URL="https://github.com/${REPO}/releases/download/${LATEST_TAG}/gshell-${ARCH_NAME}-linux"

    print_info "Trying: ${BINARY_URL}"

    if curl -fsSL "$BINARY_URL" -o gshell; then
        chmod +x gshell
        BINARY_PATH="gshell"
        print_success "Downloaded pre-built binary"
    else
        print_warning "Pre-built binary not available"
        print_info "Falling back to building from source..."
        build_from_source
    fi
}

# Install binary
install_binary() {
    print_step "Installing GShell..."

    # Create install directory
    mkdir -p "$INSTALL_DIR"

    # Copy binary
    if cp "$BINARY_PATH" "$INSTALL_DIR/gshell"; then
        chmod +x "$INSTALL_DIR/gshell"
        print_success "Installed to ${INSTALL_DIR}/gshell"
    else
        print_error "Failed to copy binary to ${INSTALL_DIR}"
        exit 1
    fi
}

# Setup PATH
setup_path() {
    print_step "Setting up PATH..."

    # Check if already in PATH
    if echo "$PATH" | grep -q "${INSTALL_DIR}"; then
        print_success "~/.local/bin is already in PATH"
        return
    fi

    # Add to shell rc files
    local shell_rc=""

    if [ -n "$BASH" ]; then
        shell_rc="$HOME/.bashrc"
    elif [ -n "$ZSH_VERSION" ]; then
        shell_rc="$HOME/.zshrc"
    else
        # Try to detect shell
        case "$SHELL" in
            */bash)
                shell_rc="$HOME/.bashrc"
                ;;
            */zsh)
                shell_rc="$HOME/.zshrc"
                ;;
            */fish)
                shell_rc="$HOME/.config/fish/config.fish"
                ;;
        esac
    fi

    if [ -n "$shell_rc" ] && [ -f "$shell_rc" ]; then
        if ! grep -q "\.local/bin" "$shell_rc"; then
            echo "" >> "$shell_rc"
            echo "# Added by GShell installer" >> "$shell_rc"
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shell_rc"
            print_success "Added ~/.local/bin to PATH in ${shell_rc}"
            print_warning "Run 'source ${shell_rc}' or restart your terminal"
        fi
    else
        print_warning "Could not automatically add to PATH"
        print_info "Add this to your shell config:"
        print_info '  export PATH="$HOME/.local/bin:$PATH"'
    fi
}

# Install optional dependencies
install_optional_deps() {
    print_step "Checking optional dependencies..."

    local optional_deps=()

    # Starship prompt (recommended)
    if ! command -v starship &> /dev/null; then
        optional_deps+=("starship")
        print_info "Starship prompt: Not installed (recommended)"
    fi

    # eza (modern ls)
    if ! command -v eza &> /dev/null; then
        optional_deps+=("eza")
        print_info "eza: Not installed (optional)"
    fi

    if [ ${#optional_deps[@]} -ne 0 ]; then
        echo
        print_warning "Optional dependencies available:"

        case "$OS" in
            arch|manjaro)
                echo -e "  ${GRAY}sudo pacman -S ${optional_deps[*]}${RESET}"
                ;;
            ubuntu|debian)
                echo -e "  ${GRAY}# Starship: curl -sS https://starship.rs/install.sh | sh${RESET}"
                echo -e "  ${GRAY}# eza: cargo install eza${RESET}"
                ;;
            *)
                echo -e "  ${GRAY}# Visit: https://starship.rs${RESET}"
                ;;
        esac
        echo
    fi
}

# Print completion message
print_completion() {
    echo
    echo -e "${TEAL}╔═══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${TEAL}║                                                               ║${RESET}"
    echo -e "${TEAL}║               ${MINT}✓ GShell installed successfully!${RESET}${TEAL}              ║${RESET}"
    echo -e "${TEAL}║                                                               ║${RESET}"
    echo -e "${TEAL}╚═══════════════════════════════════════════════════════════════╝${RESET}"
    echo
    echo -e "${WHITE}Quick Start:${RESET}"
    echo -e "${MINT}  1.${RESET} Add to PATH (if needed):"
    echo -e "     ${GRAY}export PATH=\"\$HOME/.local/bin:\$PATH\"${RESET}"
    echo
    echo -e "${MINT}  2.${RESET} Launch GShell:"
    echo -e "     ${GRAY}gshell${RESET}"
    echo
    echo -e "${MINT}  3.${RESET} Complete the interactive setup wizard"
    echo
    echo -e "${WHITE}Make it your default shell:${RESET}"
    echo -e "  ${GRAY}echo \"\$HOME/.local/bin/gshell\" | sudo tee -a /etc/shells${RESET}"
    echo -e "  ${GRAY}chsh -s \$HOME/.local/bin/gshell${RESET}"
    echo
    echo -e "${WHITE}Documentation:${RESET}"
    echo -e "  ${GRAY}https://github.com/${REPO}${RESET}"
    echo
    echo -e "${TEAL}⚡ Enjoy your next generation shell experience!${RESET}"
    echo
}

# Main installation flow
main() {
    print_header

    detect_os
    check_dependencies
    get_latest_release
    download_source

    if [ "$USE_PREBUILT" = true ]; then
        download_prebuilt
    else
        build_from_source
    fi

    install_binary
    setup_path
    install_optional_deps
    print_completion
}

# Run main
main
