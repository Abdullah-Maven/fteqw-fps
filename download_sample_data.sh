#!/bin/bash
#
# FTEQW Sample Data Download Script
# Downloads and sets up test content for game testing
#
# Usage: ./download_sample_data.sh [option]
# Options:
#   all         - Download all available test content
#   quake       - Download Quake shareware (required base)
#   xonotic     - Download Xonotic 0.8.5
#   fortressone - Download Fortress One
#   hexen2      - Download Hexen II demo
#   clean       - Remove all downloaded content
#   status      - Show download status
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GAMES_DIR="$SCRIPT_DIR/games"
DOWNLOAD_DIR="$SCRIPT_DIR/downloads"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_status() {
    log_info "Checking download status..."
    echo ""
    
    if [ -f "$GAMES_DIR/quake-demo.fmf" ]; then
        if [ -d "$SCRIPT_DIR/quake/id1" ]; then
            log_success "✓ Quake Shareware: Installed"
        else
            log_warning "⚠ Quake Shareware: Manifest available, not downloaded"
        fi
    fi
    
    if [ -f "$GAMES_DIR/xonotic_85.fmf" ]; then
        if [ -d "$SCRIPT_DIR/xonotic" ]; then
            log_success "✓ Xonotic 0.8.5: Installed"
        else
            log_warning "⚠ Xonotic 0.8.5: Manifest available, not downloaded"
        fi
    fi
    
    if [ -f "$GAMES_DIR/fortressone.fmf" ]; then
        if [ -d "$SCRIPT_DIR/fortressone" ]; then
            log_success "✓ Fortress One: Installed"
        else
            log_warning "⚠ Fortress One: Manifest available, not downloaded"
        fi
    fi
    
    if [ -f "$GAMES_DIR/hexen2-demo.fmf" ]; then
        if [ -d "$SCRIPT_DIR/hexen2" ]; then
            log_success "✓ Hexen II Demo: Installed"
        else
            log_warning "⚠ Hexen II Demo: Manifest available, not downloaded"
        fi
    fi
    
    echo ""
    log_info "To download content, run: $0 <game-name>"
    log_info "Available games: quake, xonotic, fortressone, hexen2, all"
}

download_quake() {
    log_info "Downloading Quake Shareware..."
    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR"
    
    # Download using FTE engine's manifest system
    if [ -f "$SCRIPT_DIR/engine/release/fteqw-sdl2" ]; then
        log_info "Using FTE engine to download Quake shareware..."
        "$SCRIPT_DIR/engine/release/fteqw-sdl2" -manifest "$GAMES_DIR/quake-demo.fmf" -quit
        log_success "Quake shareware downloaded successfully!"
    else
        log_warning "FTE engine not built yet. Building first..."
        cd "$SCRIPT_DIR/engine"
        gmake makelibs FTE_TARGET=SDL2
        gmake gl-rel FTE_TARGET=SDL2
        cd "$DOWNLOAD_DIR"
        "$SCRIPT_DIR/engine/release/fteqw-sdl2" -manifest "$GAMES_DIR/quake-demo.fmf" -quit
        log_success "Quake shareware downloaded successfully!"
    fi
}

download_xonotic() {
    log_info "Downloading Xonotic 0.8.5..."
    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR"
    
    if [ -f "$SCRIPT_DIR/engine/release/fteqw-sdl2" ]; then
        log_info "Using FTE engine to download Xonotic..."
        "$SCRIPT_DIR/engine/release/fteqw-sdl2" -manifest "$GAMES_DIR/xonotic_85.fmf" -quit
        log_success "Xonotic 0.8.5 downloaded successfully!"
    else
        log_warning "FTE engine not built yet. Please build engine first."
        log_info "Run: cd engine && gmake makelibs FTE_TARGET=SDL2 && gmake gl-rel FTE_TARGET=SDL2"
        return 1
    fi
}

download_fortressone() {
    log_info "Downloading Fortress One..."
    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR"
    
    if [ -f "$SCRIPT_DIR/engine/release/fteqw-sdl2" ]; then
        log_info "Using FTE engine to download Fortress One..."
        "$SCRIPT_DIR/engine/release/fteqw-sdl2" -manifest "$GAMES_DIR/fortressone.fmf" -quit
        log_success "Fortress One downloaded successfully!"
    else
        log_warning "FTE engine not built yet. Please build engine first."
        return 1
    fi
}

download_hexen2() {
    log_info "Downloading Hexen II Demo..."
    mkdir -p "$DOWNLOAD_DIR"
    cd "$DOWNLOAD_DIR"
    
    if [ -f "$SCRIPT_DIR/engine/release/fteqw-sdl2" ]; then
        log_info "Using FTE engine to download Hexen II Demo..."
        "$SCRIPT_DIR/engine/release/fteqw-sdl2" -manifest "$GAMES_DIR/hexen2-demo.fmf" -quit
        log_success "Hexen II Demo downloaded successfully!"
    else
        log_warning "FTE engine not built yet. Please build engine first."
        return 1
    fi
}

clean_all() {
    log_warning "Removing all downloaded content..."
    rm -rf "$DOWNLOAD_DIR"
    rm -rf "$SCRIPT_DIR/quake"
    rm -rf "$SCRIPT_DIR/xonotic"
    rm -rf "$SCRIPT_DIR/fortressone"
    rm -rf "$SCRIPT_DIR/hexen2"
    log_success "All downloaded content removed!"
}

download_all() {
    log_info "Downloading all available test content..."
    download_quake
    download_xonotic || log_warning "Xonotic download failed, continuing..."
    download_fortressone || log_warning "Fortress One download failed, continuing..."
    download_hexen2 || log_warning "Hexen II download failed, continuing..."
    log_success "Download complete!"
}

show_help() {
    echo "FTEQW Sample Data Download Script"
    echo ""
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  all          - Download all available test content"
    echo "  quake        - Download Quake shareware (recommended starting point)"
    echo "  xonotic      - Download Xonotic 0.8.5"
    echo "  fortressone  - Download Fortress One"
    echo "  hexen2       - Download Hexen II demo"
    echo "  clean        - Remove all downloaded content"
    echo "  status       - Show download status"
    echo "  help         - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 quake              # Download only Quake shareware"
    echo "  $0 all                # Download everything"
    echo "  $0 status             # Check what's installed"
    echo ""
    echo "After downloading, run the game with:"
    echo "  ./engine/release/fteqw-sdl2 -game quake"
    echo "  ./engine/release/fteqw-sdl2 -game xonotic"
}

# Main script
case "${1:-help}" in
    all)
        download_all
        ;;
    quake)
        download_quake
        ;;
    xonotic)
        download_xonotic
        ;;
    fortressone)
        download_fortressone
        ;;
    hexen2)
        download_hexen2
        ;;
    clean)
        clean_all
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        log_error "Unknown option: $1"
        echo ""
        show_help
        exit 1
        ;;
esac

exit 0
