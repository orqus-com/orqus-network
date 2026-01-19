#!/bin/bash
# Orqus Node Installer
# Usage: curl -L https://orqes.com/install | bash
#        curl -L https://orqes.com/install | bash -s -- --method binary

set -e

VERSION="${ORQUS_VERSION:-latest}"
REPO_URL="https://github.com/orqus-com/orqus-network"
REPO_RAW="https://raw.githubusercontent.com/orqus-com/orqus-network/main"
INSTALL_DIR="/usr/local/bin"
CONFIG_DIR="/etc/orqus"
DATA_DIR="/var/lib/orqus"
METHOD="docker"  # docker or binary

# Component versions (update these for releases)
RETH_VERSION="${RETH_VERSION:-latest}"
ORQUSBFT_VERSION="${ORQUSBFT_VERSION:-latest}"
COMETBFT_VERSION="${COMETBFT_VERSION:-v0.38.15}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Detect OS and architecture
detect_platform() {
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)

    case $ARCH in
        x86_64)  ARCH="amd64" ;;
        aarch64) ARCH="arm64" ;;
        arm64)   ARCH="arm64" ;;
        *)       error "Unsupported architecture: $ARCH" ;;
    esac

    case $OS in
        linux)  PLATFORM="linux-$ARCH" ;;
        darwin) PLATFORM="darwin-$ARCH" ;;
        *)      error "Unsupported OS: $OS" ;;
    esac

    info "Detected platform: $PLATFORM"
}

# Check Docker requirements
check_docker_requirements() {
    info "Checking Docker requirements..."

    if ! command -v docker &> /dev/null; then
        error "Docker is not installed. Please install Docker first: https://docs.docker.com/get-docker/"
    fi

    if ! docker compose version &> /dev/null; then
        error "Docker Compose is not installed. Please install Docker Compose first."
    fi

    if ! docker info &> /dev/null; then
        error "Docker daemon is not running. Please start Docker."
    fi

    info "Docker requirements satisfied."
}

# Check binary requirements
check_binary_requirements() {
    info "Checking binary requirements..."

    if [ "$EUID" -ne 0 ] && [ ! -w "$INSTALL_DIR" ]; then
        warn "Binary installation requires sudo. You may be prompted for your password."
    fi

    # Check for systemd
    if ! command -v systemctl &> /dev/null; then
        warn "systemd not found. You'll need to manage services manually."
    fi

    info "Binary requirements satisfied."
}

# Download and install orqus-node CLI (for Docker method)
install_cli() {
    info "Installing orqus-node CLI..."

    TMP_DIR=$(mktemp -d)
    trap "rm -rf $TMP_DIR" EXIT

    # Download from orqes.com (primary) or GitHub raw (fallback)
    curl -fsSL "$REPO_RAW/scripts/orqus-node" -o "$TMP_DIR/orqus-node"
    
    chmod +x "$TMP_DIR/orqus-node"

    if [ -w "$INSTALL_DIR" ]; then
        mv "$TMP_DIR/orqus-node" "$INSTALL_DIR/orqus-node"
    else
        sudo mv "$TMP_DIR/orqus-node" "$INSTALL_DIR/orqus-node"
    fi

    info "orqus-node CLI installed to $INSTALL_DIR/orqus-node"
}

# Get latest release version from GitHub
get_latest_version() {
    local repo=$1
    curl -fsSL "https://api.github.com/repos/orqus-com/$repo/releases/latest" 2>/dev/null | \
        grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' || echo ""
}

# Download binary from GitHub releases
download_binary() {
    local repo=$1
    local binary=$2
    local version=$3

    if [ "$version" = "latest" ]; then
        version=$(get_latest_version "$repo")
        if [ -z "$version" ]; then
            error "Failed to get latest version for $repo"
        fi
    fi

    info "Downloading $binary $version for $PLATFORM..."

    local url="https://github.com/orqus-com/$repo/releases/download/$version/$binary-$PLATFORM.tar.gz"
    local tmp_file=$(mktemp)

    if ! curl -fsSL "$url" -o "$tmp_file"; then
        error "Failed to download $binary from $url"
    fi

    tar -xzf "$tmp_file" -C /tmp
    rm "$tmp_file"

    if [ -w "$INSTALL_DIR" ]; then
        mv "/tmp/$binary" "$INSTALL_DIR/$binary"
    else
        sudo mv "/tmp/$binary" "$INSTALL_DIR/$binary"
    fi

    chmod +x "$INSTALL_DIR/$binary"
    info "$binary installed to $INSTALL_DIR/$binary"
}

# Download CometBFT from official releases
download_cometbft() {
    local version=$COMETBFT_VERSION

    info "Downloading CometBFT $version for $PLATFORM..."

    # CometBFT uses different naming convention
    local cometbft_os=$OS
    local cometbft_arch=$ARCH

    local url="https://github.com/cometbft/cometbft/releases/download/$version/cometbft_${version#v}_${cometbft_os}_${cometbft_arch}.tar.gz"
    local tmp_file=$(mktemp)

    if ! curl -fsSL "$url" -o "$tmp_file"; then
        error "Failed to download CometBFT from $url"
    fi

    tar -xzf "$tmp_file" -C /tmp
    rm "$tmp_file"

    if [ -w "$INSTALL_DIR" ]; then
        mv "/tmp/cometbft" "$INSTALL_DIR/cometbft"
    else
        sudo mv "/tmp/cometbft" "$INSTALL_DIR/cometbft"
    fi

    chmod +x "$INSTALL_DIR/cometbft"
    info "CometBFT installed to $INSTALL_DIR/cometbft"
}

# Install systemd services
install_systemd_services() {
    if ! command -v systemctl &> /dev/null; then
        warn "systemd not found, skipping service installation."
        return
    fi

    info "Installing systemd services..."

    # Create orqus user if not exists
    if ! id -u orqus &>/dev/null; then
        sudo useradd --system --home-dir /var/lib/orqus --shell /sbin/nologin orqus
    fi

    # Create directories
    sudo mkdir -p $CONFIG_DIR $DATA_DIR/{reth,orqusbft,cometbft}
    sudo chown -R orqus:orqus $DATA_DIR

    # Download service files
    for service in cometbft orqusbft orqus-reth; do
        sudo curl -fsSL "$REPO_RAW/systemd/$service.service" -o "/etc/systemd/system/$service.service"
    done

    # Download target file
    sudo curl -fsSL "$REPO_RAW/systemd/orqus-node.target" -o "/etc/systemd/system/orqus-node.target"

    # Reload systemd
    sudo systemctl daemon-reload

    info "Systemd services installed."
    echo ""
    echo "To manage the node:"
    echo "  sudo systemctl start orqus-node.target    # Start all services"
    echo "  sudo systemctl stop orqus-node.target     # Stop all services"
    echo "  sudo systemctl status cometbft            # Check CometBFT status"
    echo "  journalctl -u orqus-reth -f               # View reth logs"
}

# Binary installation
install_binary() {
    detect_platform
    check_binary_requirements

    info "Installing Orqus Node binaries..."

    # Download all binaries
    download_binary "orqus-reth" "orqus-reth" "$RETH_VERSION"
    download_binary "orqusbft" "orqusbft" "$ORQUSBFT_VERSION"
    download_cometbft

    # Install systemd services
    install_systemd_services

    echo ""
    info "Binary installation complete!"
    echo ""
    echo "Installed binaries:"
    echo "  - orqus-reth:  $($INSTALL_DIR/orqus-reth --version 2>/dev/null || echo 'installed')"
    echo "  - orqusbft:    $($INSTALL_DIR/orqusbft --version 2>/dev/null || echo 'installed')"
    echo "  - cometbft:    $($INSTALL_DIR/cometbft version 2>/dev/null || echo 'installed')"
    echo ""
    echo "Next steps:"
    echo "  1. Download genesis files to $CONFIG_DIR/"
    echo "  2. Configure $CONFIG_DIR/orqusbft.yaml"
    echo "  3. Initialize CometBFT: cometbft init --home $DATA_DIR/cometbft"
    echo "  4. Start services: sudo systemctl start orqus-node.target"
    echo ""
    echo "For detailed setup, see: $REPO_URL/blob/main/docs/binary-setup.md"
}

# Docker installation
install_docker() {
    check_docker_requirements
    install_cli

    echo ""
    info "Docker installation complete!"
    echo ""
    echo "Quick Start:"
    echo "  orqus-node init --network testnet   # Initialize node"
    echo "  orqus-node start                    # Start node"
    echo "  orqus-node status                   # Check status"
    echo "  orqus-node logs                     # View logs"
}

# Show help
show_help() {
    cat << EOF
Orqus Node Installer

Usage: curl -L https://orqes.com/install | bash [options]

Options:
  --method <type>    Installation method: docker (default) or binary
  --version <ver>    Version to install (default: latest)
  --help             Show this help message

Examples:
  # Install with Docker (recommended)
  curl -L https://orqes.com/install | bash

  # Install binaries directly
  curl -L https://orqes.com/install | bash -s -- --method binary

  # Install specific version
  curl -L https://orqes.com/install | bash -s -- --version v1.0.0

Environment Variables:
  ORQUS_VERSION      Version to install
  RETH_VERSION       orqus-reth version
  ORQUSBFT_VERSION   orqusbft version
  COMETBFT_VERSION   CometBFT version

For more information: $REPO_URL
EOF
}

# Parse arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --method)
                METHOD="$2"
                shift 2
                ;;
            --version)
                VERSION="$2"
                RETH_VERSION="$2"
                ORQUSBFT_VERSION="$2"
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1. Use --help for usage."
                ;;
        esac
    done
}

# Main
main() {
    echo ""
    echo "  ___                        _   _           _      "
    echo " / _ \ _ __ __ _ _   _ ___  | \ | | ___   __| | ___ "
    echo "| | | | '__/ _\` | | | / __| |  \| |/ _ \ / _\` |/ _ \\"
    echo "| |_| | | | (_| | |_| \__ \ | |\  | (_) | (_| |  __/"
    echo " \___/|_|  \__, |\__,_|___/ |_| \_|\___/ \__,_|\___|"
    echo "              |_|                                   "
    echo ""
    echo "Orqus Node Installer"
    echo ""

    parse_args "$@"

    case $METHOD in
        docker)
            info "Installation method: Docker"
            install_docker
            ;;
        binary)
            info "Installation method: Binary"
            install_binary
            ;;
        *)
            error "Unknown method: $METHOD. Use 'docker' or 'binary'."
            ;;
    esac

    echo ""
    echo "For more information:"
    echo "  $REPO_URL"
    echo ""
}

main "$@"
