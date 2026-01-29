#!/bin/bash
set -euo pipefail

# code-to-markdown installer
# Usage: curl -fsSL https://raw.githubusercontent.com/togo5/code-to-markdown/main/install.sh | bash
# Or with version: curl -fsSL ... | bash -s v0.1.0

REPO="togo5/code-to-markdown"
INSTALL_DIR="${HOME}/.local/bin"
BINARY_NAME="code-to-markdown"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    exit 1
}

# Check for required commands
check_dependencies() {
    if ! command -v curl &>/dev/null && ! command -v wget &>/dev/null; then
        error "curl or wget is required but not installed"
    fi
}

# Detect platform
detect_platform() {
    local os arch

    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"

    case "$os" in
        darwin) os="darwin" ;;
        linux) os="linux" ;;
        *) error "Unsupported OS: $os" ;;
    esac

    case "$arch" in
        x86_64 | amd64) arch="x64" ;;
        arm64 | aarch64) arch="arm64" ;;
        *) error "Unsupported architecture: $arch" ;;
    esac

    echo "${os}-${arch}"
}

# Fetch URL content
fetch() {
    local url="$1"
    if command -v curl &>/dev/null; then
        curl -fsSL "$url"
    else
        wget -qO- "$url"
    fi
}

# Download file
download() {
    local url="$1"
    local output="$2"
    if command -v curl &>/dev/null; then
        curl -fsSL -o "$output" "$url"
    else
        wget -q -O "$output" "$url"
    fi
}

# Get latest version from GitHub API
get_latest_version() {
    local api_url="https://api.github.com/repos/${REPO}/releases/latest"
    local response

    response=$(fetch "$api_url" 2>/dev/null) || error "Failed to fetch latest release info"

    # Extract tag_name using grep/sed (no jq dependency)
    echo "$response" | grep -o '"tag_name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed 's/.*"\([^"]*\)"$/\1/'
}

# Verify checksum
verify_checksum() {
    local file="$1"
    local expected="$2"
    local actual

    if command -v shasum &>/dev/null; then
        actual=$(shasum -a 256 "$file" | awk '{print $1}')
    elif command -v sha256sum &>/dev/null; then
        actual=$(sha256sum "$file" | awk '{print $1}')
    else
        warn "Neither shasum nor sha256sum found, skipping checksum verification"
        return 0
    fi

    if [ "$actual" != "$expected" ]; then
        error "Checksum verification failed!\nExpected: $expected\nActual: $actual"
    fi

    info "Checksum verified"
}

main() {
    local version="${1:-}"
    local platform
    local download_url
    local checksums_url
    local expected_checksum
    local tmp_dir
    local binary_path

    info "Installing ${BINARY_NAME}..."

    check_dependencies

    platform=$(detect_platform)
    info "Detected platform: ${platform}"

    # Get version
    if [ -z "$version" ] || [ "$version" = "latest" ]; then
        info "Fetching latest version..."
        version=$(get_latest_version)
    fi

    if [ -z "$version" ]; then
        error "Failed to determine version"
    fi

    info "Version: ${version}"

    # Construct URLs
    download_url="https://github.com/${REPO}/releases/download/${version}/${BINARY_NAME}-${platform}"
    checksums_url="https://github.com/${REPO}/releases/download/${version}/checksums.txt"

    # Create temp directory
    tmp_dir=$(mktemp -d)
    trap 'rm -rf "$tmp_dir"' EXIT

    binary_path="${tmp_dir}/${BINARY_NAME}"

    # Download checksums
    info "Downloading checksums..."
    checksums_file="${tmp_dir}/checksums.txt"
    if ! download "$checksums_url" "$checksums_file" 2>/dev/null; then
        warn "Failed to download checksums, skipping verification"
        checksums_file=""
    fi

    # Download binary
    info "Downloading ${BINARY_NAME}-${platform}..."
    if ! download "$download_url" "$binary_path"; then
        error "Failed to download binary"
    fi

    # Verify checksum
    if [ -n "$checksums_file" ] && [ -f "$checksums_file" ]; then
        expected_checksum=$(grep "${BINARY_NAME}-${platform}$" "$checksums_file" | awk '{print $1}')
        if [ -n "$expected_checksum" ]; then
            verify_checksum "$binary_path" "$expected_checksum"
        else
            warn "Checksum not found for ${platform}, skipping verification"
        fi
    fi

    # Install
    info "Installing to ${INSTALL_DIR}..."
    mkdir -p "$INSTALL_DIR"
    mv "$binary_path" "${INSTALL_DIR}/${BINARY_NAME}"
    chmod +x "${INSTALL_DIR}/${BINARY_NAME}"

    info "Successfully installed ${BINARY_NAME} ${version}"

    # Check PATH
    if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
        echo ""
        warn "${INSTALL_DIR} is not in your PATH"
        echo "Add the following to your shell profile (.bashrc, .zshrc, etc.):"
        echo ""
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
        echo ""
    fi

    info "Run '${BINARY_NAME} --help' to get started"
}

main "$@"
