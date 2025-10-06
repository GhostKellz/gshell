# Maintainer: ghostkellz <ghostkellz@github.com>
pkgname=gshell
pkgver=0.1.0
pkgrel=1
pkgdesc="Next Generation Shell - Modern shell with Lua scripting, networking, and beautiful prompts"
arch=('x86_64' 'aarch64')
url="https://github.com/ghostkellz/gshell"
license=('MIT')
depends=()
makedepends=('zig>=0.14.0' 'git')
optdepends=(
    'starship: Fast, customizable prompt (recommended)'
    'eza: Modern replacement for ls with colors'
    'vivid: LS_COLORS theme generator'
    'bat: Cat clone with syntax highlighting'
    'fd: Fast alternative to find'
    'ripgrep: Fast grep alternative'
)
provides=('gshell')
conflicts=('gshell-git')
install=gshell.install
source=("${pkgname}-${pkgver}.tar.gz::https://github.com/ghostkellz/${pkgname}/archive/v${pkgver}.tar.gz")
sha256sums=('SKIP')  # Update with actual checksum on release

build() {
    cd "${srcdir}/${pkgname}-${pkgver}"

    # Build with Zig in release mode
    zig build -Doptimize=ReleaseFast
}

check() {
    cd "${srcdir}/${pkgname}-${pkgver}"

    # Run tests if available
    zig build test || true
}

package() {
    cd "${srcdir}/${pkgname}-${pkgver}"

    # Install binary
    install -Dm755 "zig-out/bin/gshell" "${pkgdir}/usr/bin/gshell"

    # Install default configuration templates
    install -Dm644 "assets/templates/gshrc-ghostkellz" "${pkgdir}/usr/share/gshell/templates/gshrc-default"
    install -Dm644 "assets/templates/starship-ghostkellz.toml" "${pkgdir}/usr/share/gshell/templates/starship.toml"

    # Install themes
    if [ -d "assets/themes" ]; then
        install -d "${pkgdir}/usr/share/gshell/themes"
        install -Dm644 assets/themes/*.yml "${pkgdir}/usr/share/gshell/themes/" 2>/dev/null || true
    fi

    # Install plugins
    if [ -d "assets/plugins" ]; then
        install -d "${pkgdir}/usr/share/gshell/plugins"
        for plugin in assets/plugins/*.gza; do
            [ -f "$plugin" ] && install -Dm644 "$plugin" "${pkgdir}/usr/share/gshell/plugins/"
        done
    fi

    # Install documentation
    install -Dm644 README.md "${pkgdir}/usr/share/doc/${pkgname}/README.md"
    install -Dm644 LICENSE "${pkgdir}/usr/share/licenses/${pkgname}/LICENSE" || true

    # Install shell integration scripts
    install -Dm644 "contrib/shells/gshell.bash" "${pkgdir}/usr/share/gshell/integration/bash" 2>/dev/null || true
    install -Dm644 "contrib/shells/gshell.zsh" "${pkgdir}/usr/share/gshell/integration/zsh" 2>/dev/null || true

    # Add to /etc/shells
    # Note: This should be done in post_install, not here
}
