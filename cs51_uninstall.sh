#!/bin/bash

# OCaml Development Environment Uninstall Script for CS51
# Version: 2.0

# This script attempts to uninstall the OCaml development environment
# set up by the CS51 installation script (v2.0). It removes the cs51
# opam switch, cleans up shell configurations, and optionally VS Code.
#
# Usage:
#   ./cs51_uninstall.sh [-dry-run] [-remove-vscode] [-remove-opam]
#
# Options:
#   -dry-run         Run in dry-run mode. This will print commands without
#                    executing them.
#   -remove-vscode   Also remove Visual Studio Code (use with caution).
#   -remove-opam     Also remove OPAM completely (removes all switches).
#
# Note: This script may require administrator privileges to remove
#       certain components.

# Initialize flags
DRY_RUN=false
REMOVE_VSCODE=false
REMOVE_OPAM=false

# Function to execute or echo commands based on dry-run flag
run_command() {
    if [ "$DRY_RUN" = true ]; then
        echo "DRY-RUN: Would run: $*"
        return 0
    else
        echo "Running: $*"
        if ! eval "$@"; then
            echo "⚠️  WARNING: Command failed: $*"
            return 1
        fi
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Parse command line arguments
while [[ "$#" -gt 0 ]]; do
    case $1 in
        -dry-run) DRY_RUN=true ;;
        -remove-vscode) REMOVE_VSCODE=true ;;
        -remove-opam) REMOVE_OPAM=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

echo "Warning: This script will uninstall the CS51 OCaml development environment."
echo "It will remove the 'cs51' opam switch and clean up shell configurations."
if [ "$REMOVE_OPAM" = true ]; then
    echo "⚠️  WARNING: -remove-opam flag set. This will remove OPAM and ALL switches!"
fi
if [ "$REMOVE_VSCODE" = true ]; then
    echo "⚠️  WARNING: -remove-vscode flag set. This will remove Visual Studio Code!"
fi
echo ""
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo "Uninstallation cancelled."
    exit 1
fi

# Remove CS51 opam switch
if command_exists opam; then
    if opam switch list 2>/dev/null | grep -q "cs51"; then
        echo "Removing CS51 opam switch..."
        run_command "opam switch remove cs51 -y"
    else
        echo "✓ CS51 switch not found (already removed or never installed)"
    fi
fi

# Clean up shell configuration files
echo ""
echo "Cleaning up shell configuration files..."
for config in "$HOME/.zshrc" "$HOME/.bashrc" "$HOME/.profile"; do
    if [ -f "$config" ]; then
        # Check if file contains CS51 setup script additions
        if grep -q "CS51 setup script" "$config" 2>/dev/null || grep -q "Visual Studio Code.app.*bin" "$config" 2>/dev/null; then
            echo "Cleaning $config..."
            # Create backup
            cp "$config" "$config.backup-$(date +%Y%m%d-%H%M%S)"
            # Remove CS51 additions
            sed -i.tmp '/# Initialize opam environment (added by CS51 setup script)/d' "$config"
            sed -i.tmp '/eval "$(opam env)"/d' "$config"
            sed -i.tmp '/Visual Studio Code.app\/Contents\/Resources\/app\/bin/d' "$config"
            rm -f "$config.tmp"
            echo "✓ Cleaned $config (backup created)"
        fi
    fi
done

# Remove OPAM completely if requested
if [ "$REMOVE_OPAM" = true ] && command_exists opam; then
    echo ""
    echo "Removing OPAM and all OCaml versions..."
    run_command "opam switch remove -a -y"
    run_command "rm -rf ~/.opam"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        run_command "brew uninstall opam"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        run_command "sudo apt-get remove --auto-remove opam -y"
    fi
fi

# Remove OCaml-related packages installed via package manager (only with -remove-opam)
if [[ "$OSTYPE" == "linux-gnu"* ]] && [ "$REMOVE_OPAM" = true ]; then
    echo ""
    echo "Removing OCaml-related system packages..."
    run_command "sudo apt-get remove --auto-remove ocaml ocaml-nox ocaml-native-compilers camlp4 -y"
fi

# Remove VS Code and extensions if requested
if [ "$REMOVE_VSCODE" = true ]; then
    echo "Removing Visual Studio Code and extensions..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        run_command "rm -rf '/Applications/Visual Studio Code.app'"
        run_command "rm -rf '$HOME/Library/Application Support/Code'"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        run_command "sudo apt-get remove --auto-remove code"
        run_command "rm -rf '$HOME/.config/Code'"
        run_command "rm -rf '$HOME/.vscode'"
    fi
else
    echo "Removing OCaml Platform extension for VS Code..."
    if command_exists code; then
        run_command "code --uninstall-extension ocamllabs.ocaml-platform"
    fi
fi

# Remove Homebrew (on macOS)
if [[ "$OSTYPE" == "darwin"* ]] && command_exists brew && [ "$REMOVE_OPAM" = true ]; then
    echo ""
    echo "Homebrew was used to install some components."
    echo "If you want to remove Homebrew completely, run:"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)\""
fi

echo ""
echo "=========================================="
echo "Uninstallation complete!"
echo "=========================================="
echo ""
echo "What was removed:"
echo "  ✓ CS51 opam switch"
echo "  ✓ Shell configuration additions (backups created)"
if [ "$REMOVE_VSCODE" = true ]; then
    echo "  ✓ Visual Studio Code"
fi
if [ "$REMOVE_OPAM" = true ]; then
    echo "  ✓ OPAM and all switches"
fi
echo ""
echo "Next steps:"
echo "  1. Restart your terminal or run: source ~/.zshrc (or ~/.bashrc)"
echo "  2. Shell config backups are in your home directory (if any changes were made)"
echo ""
