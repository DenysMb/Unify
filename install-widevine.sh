#!/bin/bash
#
# Widevine CDM Installation Script for Unify
#
# This script downloads and installs the Widevine Content Decryption Module
# required for playing DRM-protected content from services like Spotify,
# Prime Video, Netflix, etc.
#
# The Widevine library is downloaded from Firefox's official repository
# which maintains up-to-date links to Google's Widevine CDM.
#
# Usage: ./install-widevine.sh [install|uninstall]
#

set -eu

APP_ID="io.github.denysmb.unify"

is_running_in_flatpak() {
    # The most reliable indicator is the presence of /.flatpak-info.
    # FLATPAK_ID is also set in many runtimes, but not always.
    [ -f "/.flatpak-info" ] || [ -n "${FLATPAK_ID:-}" ]
}

IN_FLATPAK=0
if is_running_in_flatpak; then
    IN_FLATPAK=1
fi

# Installation directory:
# We always install Widevine under the Flatpak app directory:
#   ~/.var/app/<APP_ID>/plugins
#
# Important: Inside the Flatpak sandbox, $HOME is typically the user's real home
# (and may be mounted read-only via --filesystem=home:ro). Write access to this
# specific path must be granted (e.g. via:
#   --filesystem=~/.var/app/<APP_ID>/plugins:create
# )
PLUGINS_DIR="$HOME/.var/app/$APP_ID/plugins"

WIDEVINE_BASE_DIR="$PLUGINS_DIR/WidevineCdm"

flatpak_cmd() {
    # Inside Flatpak, the `flatpak` binary is typically not available. Use
    # flatpak-spawn to execute host commands instead.
    if [ "$IN_FLATPAK" -eq 1 ]; then
        flatpak-spawn --host flatpak "$@"
    else
        flatpak "$@"
    fi
}

# Firefox repository URL for Widevine metadata
FIREFOX_WIDEVINE_JSON="https://raw.githubusercontent.com/mozilla/gecko-dev/master/toolkit/content/gmp-sources/widevinecdm.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_dependencies() {
    local missing_deps=()

    if ! command -v wget &> /dev/null && ! command -v curl &> /dev/null; then
        missing_deps+=("wget or curl")
    fi

    if ! command -v unzip &> /dev/null; then
        missing_deps+=("unzip")
    fi

    # Flatpak dependency handling:
    # - Outside Flatpak: we need the `flatpak` CLI on the host.
    # - Inside Flatpak: the CLI usually isn't exposed; we should use
    #   flatpak-spawn to call host commands instead.
    if [ "$IN_FLATPAK" -eq 1 ]; then
        if ! command -v flatpak-spawn &> /dev/null; then
            missing_deps+=("flatpak-spawn")
        fi
    else
        if ! command -v flatpak &> /dev/null; then
            missing_deps+=("flatpak")
        fi
    fi

    # Check for JSON parser (prefer jq, fallback to python)
    if ! command -v jq &> /dev/null && ! command -v python3 &> /dev/null && ! command -v python &> /dev/null; then
        missing_deps+=("jq or python")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing dependencies: ${missing_deps[*]}"
        print_error "Please install them and try again."
        exit 1
    fi
}

check_flatpak_installed() {
    if ! flatpak_cmd list --app | grep -q "$APP_ID"; then
        print_error "Unify Flatpak is not installed."
        print_error "Please install it first: flatpak install flathub $APP_ID"
        exit 1
    fi
}

download_file() {
    local url="$1"
    local output="$2"

    if command -v wget &> /dev/null; then
        # NOTE: Flatpak runtime currently ships wget2, which does not support
        # `--show-progress` (unlike GNU Wget 1.x). Try with `--show-progress`
        # first (best UX on host), then fall back silently.
        if [ "$IN_FLATPAK" -eq 1 ]; then
            wget -q -O "$output" "$url"
        else
            wget -q --show-progress -O "$output" "$url" 2>/dev/null || wget -q -O "$output" "$url"
        fi
    elif command -v curl &> /dev/null; then
        curl -L -o "$output" "$url"
    else
        print_error "Neither wget nor curl found"
        exit 1
    fi
}

download_silent() {
    local url="$1"

    if command -v wget &> /dev/null; then
        wget -qO- "$url"
    elif command -v curl &> /dev/null; then
        curl -s "$url"
    else
        print_error "Neither wget nor curl found"
        exit 1
    fi
}

parse_json() {
    local json_file="$1"
    local field="$2"

    if command -v jq &> /dev/null; then
        if [ "$field" = "version" ]; then
            # Version is in .name field as "Widevine-X.X.X.X", extract just the version number
            jq -r '.name | split("-")[1]' "$json_file"
        else
            jq -r '.vendors."gmp-widevinecdm".platforms."Linux_x86_64-gcc3"."'"$field"'"' "$json_file"
        fi
    elif command -v python3 &> /dev/null; then
        if [ "$field" = "version" ]; then
            python3 -c "import json; data=json.load(open('$json_file')); print(data['name'].split('-')[1])"
        else
            python3 -c "import json; data=json.load(open('$json_file')); print(data['vendors']['gmp-widevinecdm']['platforms']['Linux_x86_64-gcc3']['$field'])"
        fi
    elif command -v python &> /dev/null; then
        if [ "$field" = "version" ]; then
            python -c "import json; data=json.load(open('$json_file')); print(data['name'].split('-')[1])"
        else
            python -c "import json; data=json.load(open('$json_file')); print(data['vendors']['gmp-widevinecdm']['platforms']['Linux_x86_64-gcc3']['$field'])"
        fi
    else
        print_error "No JSON parser available"
        exit 1
    fi
}

get_widevine_info() {
    local temp_json
    temp_json=$(mktemp --suffix=.json)
    trap 'rm -f "$temp_json"' RETURN

    print_info "Fetching Widevine metadata from Firefox repository..."
    download_silent "$FIREFOX_WIDEVINE_JSON" > "$temp_json"

    if [ ! -s "$temp_json" ]; then
        print_error "Failed to download Widevine metadata"
        exit 1
    fi

    WIDEVINE_URL=$(parse_json "$temp_json" "fileUrl")
    WIDEVINE_VERSION=$(parse_json "$temp_json" "version")
    WIDEVINE_HASH=$(parse_json "$temp_json" "hashValue")

    if [ -z "$WIDEVINE_URL" ] || [ -z "$WIDEVINE_VERSION" ]; then
        print_error "Failed to parse Widevine metadata"
        exit 1
    fi
}

install_widevine() {
    print_info "Checking dependencies..."
    check_dependencies

    print_info "Checking if Unify Flatpak is installed..."
    check_flatpak_installed

    # Get Widevine info from Firefox repository
    get_widevine_info

    print_info "Latest Widevine version: $WIDEVINE_VERSION"

    INSTALL_DIR="$WIDEVINE_BASE_DIR/$WIDEVINE_VERSION"
    LIB_DIR="$INSTALL_DIR/_platform_specific/linux_x64"
    LIB_PATH="$LIB_DIR/libwidevinecdm.so"

    # Check if already installed
    if [ -f "$LIB_PATH" ]; then
        print_warn "Widevine $WIDEVINE_VERSION is already installed."
        print_info "Use './install-widevine.sh uninstall' to remove it first if you want to reinstall."
        exit 0
    fi

    # Create temporary directory for extraction
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT

    # Download Widevine .crx3 file
    print_info "Downloading Widevine CDM from Firefox repository..."
    TEMP_CRX="$TEMP_DIR/widevine.crx3"
    download_file "$WIDEVINE_URL" "$TEMP_CRX"

    # Verify download
    if [ ! -f "$TEMP_CRX" ] || [ ! -s "$TEMP_CRX" ]; then
        print_error "Failed to download Widevine CDM"
        exit 1
    fi

    # Extract .crx3 file (it's just a zip archive)
    # Note: CRX3 files have a header, so unzip will show a warning about "extra bytes"
    # This is expected and normal behavior
    print_info "Extracting Widevine CDM..."
    unzip -o "$TEMP_CRX" -d "$TEMP_DIR" >/dev/null 2>&1 || {
        if [ ! -d "$TEMP_DIR/_platform_specific" ]; then
            print_error "Failed to extract CRX3 archive"
            exit 1
        fi
    }

    # Verify extracted files exist
    if [ ! -f "$TEMP_DIR/_platform_specific/linux_x64/libwidevinecdm.so" ]; then
        print_error "Failed to extract libwidevinecdm.so from archive"
        print_error "Expected location: $TEMP_DIR/_platform_specific/linux_x64/libwidevinecdm.so"
        print_info "Directory contents:"
        ls -la "$TEMP_DIR" >&2
        exit 1
    fi

    # Create installation directories
    print_info "Installing Widevine files..."
    mkdir -p "$LIB_DIR"

    # Copy files to installation directory
    cp "$TEMP_DIR/_platform_specific/linux_x64/libwidevinecdm.so" "$LIB_PATH"

    # Copy manifest.json and LICENSE if they exist
    if [ -f "$TEMP_DIR/manifest.json" ]; then
        cp "$TEMP_DIR/manifest.json" "$INSTALL_DIR/manifest.json"
    fi

    if [ -f "$TEMP_DIR/LICENSE" ]; then
        cp "$TEMP_DIR/LICENSE" "$INSTALL_DIR/LICENSE.txt"
    elif [ -f "$TEMP_DIR/LICENSE.txt" ]; then
        cp "$TEMP_DIR/LICENSE.txt" "$INSTALL_DIR/LICENSE.txt"
    fi

    # Set permissions
    chmod 644 "$LIB_PATH"
    [ -f "$INSTALL_DIR/manifest.json" ] && chmod 644 "$INSTALL_DIR/manifest.json"
    [ -f "$INSTALL_DIR/LICENSE.txt" ] && chmod 644 "$INSTALL_DIR/LICENSE.txt"

    # Configure Flatpak environment override
    print_info "Configuring Flatpak environment..."

    CHROMIUM_FLAGS="--autoplay-policy=no-user-gesture-required"
    CHROMIUM_FLAGS="$CHROMIUM_FLAGS --enable-features=HardwareMediaDecoding,PlatformEncryptedDolbyVision,PlatformHEVCEncoderSupport"
    CHROMIUM_FLAGS="$CHROMIUM_FLAGS --enable-widevine-cdm"
    CHROMIUM_FLAGS="$CHROMIUM_FLAGS --widevine-path=$LIB_PATH"
    CHROMIUM_FLAGS="$CHROMIUM_FLAGS --no-sandbox"

    flatpak_cmd override --user --env=QTWEBENGINE_CHROMIUM_FLAGS="$CHROMIUM_FLAGS" "$APP_ID"

    print_info "Widevine $WIDEVINE_VERSION installed successfully!"
    echo ""
    print_info "Please restart Unify for changes to take effect."
    echo ""
    print_warn "Note: The --no-sandbox flag is required because Flatpak's sandbox"
    print_warn "conflicts with Chromium's internal sandbox."
}

uninstall_widevine() {
    print_info "Uninstalling Widevine..."

    # Remove Widevine files
    if [ -d "$WIDEVINE_BASE_DIR" ]; then
        rm -rf "$WIDEVINE_BASE_DIR"
        print_info "Widevine files removed."
    else
        print_warn "Widevine directory not found."
    fi

    # Reset Flatpak environment override
    print_info "Resetting Flatpak environment..."
    flatpak_cmd override --user --unset-env=QTWEBENGINE_CHROMIUM_FLAGS "$APP_ID" 2>/dev/null || true

    print_info "Widevine uninstalled successfully!"
    print_info "Please restart Unify for changes to take effect."
}

show_help() {
    echo "Widevine CDM Installation Script for Unify"
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  install     Install Widevine CDM (default)"
    echo "  uninstall   Remove Widevine CDM"
    echo "  help        Show this help message"
    echo ""
    echo "This script downloads the Widevine Content Decryption Module from"
    echo "Firefox's official repository and configures Unify to use it for"
    echo "DRM-protected content playback."
    echo ""
    echo "Supported services: Spotify, Prime Video, Netflix, Tidal, and others."
    echo ""
    echo "Dependencies: wget/curl, unzip, flatpak (only when outside Flatpak), jq/python"
}

# Main
case "${1:-install}" in
    install)
        install_widevine
        ;;
    uninstall)
        uninstall_widevine
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        print_error "Unknown command: $1"
        show_help
        exit 1
        ;;
esac
