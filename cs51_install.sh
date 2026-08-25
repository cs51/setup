#!/bin/bash

# OCaml Development Environment Setup Script for CS51
# Version: 2.0

# This script automates the setup of an OCaml development environment
# for CS51 on macOS or Linux. It installs OPAM (OCaml Package Manager),
# sets up OCaml, installs necessary packages, and sets up VSCode with
# the OCaml Platform extension.
#
# Usage:
#   ./cs51_install.sh [-dry-run] [-dev]
#
# Options:
#   -dry-run  Run in dry-run mode. This will print commands without
#             executing them.
#   -dev      Install development tools (dune, cppo) - for course staff only.
#             Students typically don't need these.
#
# What this script does:
# 1. Checks and installs Xcode Command Line Tools (on macOS only)
# 2. Checks and installs Homebrew (on macOS only)
# 3. Installs git and build tools if not already present
# 4. Installs OPAM if not already present
# 5. Initializes OPAM
# 6. Creates and switches to the CS51 opam switch (see OCAML_VERSION below)
# 7. Installs required OCaml packages (idempotent - skips already installed)
# 8. Installs CS51Utils and ANSITerminal
# 9. Installs or sets up Visual Studio Code
# 10. Installs OCaml Platform extension for VSCode
# 11. Sets up persistent opam environment in shell config
# 12. Verifies the OCaml installation
# 13. Runs a graphics check
#
# Note: This script is idempotent - it can be run multiple times safely.
#       It requires an internet connection and may take some time to complete.
#       It may prompt for your password for certain installation steps.
#
# Supported Operating Systems:
# - macOS (including Apple Silicon)
# - Debian-based Linux distributions (e.g., Ubuntu)
#
# Prerequisites:
# - On macOS: None (Xcode Command Line Tools will be installed if needed)
# - On Linux: sudo privileges and basic build tools
#
# After running this script:
# - The opam environment is automatically configured in your shell
# - Restart your terminal for all changes to take effect
# - Use `opam switch cs51` to switch to the CS51 environment
#
# For any issues or questions, please contact your course staff.

# OCaml version to install
OCAML_VERSION="5.2.1"

# Opam switch name (semantic naming instead of version number)
SWITCH_NAME="cs51"

# Initialize flags
DRY_RUN=false
INSTALL_DEV_TOOLS=false

# Set environment variables for non-interactive installations
export OPAMYES=1  # Auto-answer yes to opam prompts
export OPAMCONFIRMLEVEL=unsafe-yes  # Be maximally non-interactive
export DEBIAN_FRONTEND=noninteractive  # Make apt-get non-interactive
export APT_LISTCHANGES_FRONTEND=none  # Suppress apt changelog prompts

# Suppress opam update warnings (informational only, not errors)
export OPAMNOTES=0

# Function to execute or echo commands based on dry-run flag
run_command() {
    if [ "$DRY_RUN" = true ]; then
        echo "DRY-RUN: Would run: $*"
        return 0
    else
        echo "Running: $*"
        if ! eval "$@"; then
            echo ""
            echo "❌ ERROR: Command failed: $*"
            echo "Please check the error message above and try again."
            echo ""
            exit 1
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
        -dev) INSTALL_DEV_TOOLS=true ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# Check and install Xcode Command Line Tools (for macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! xcode-select -p &> /dev/null; then
        echo "Installing Xcode Command Line Tools..."
        run_command "xcode-select --install"
        # Wait for the installation to complete
        echo "Please complete the Xcode Command Line Tools installation and press any key to continue..."
        read -n 1
    fi
fi

# Check and install Homebrew (for macOS)
if [[ "$OSTYPE" == "darwin"* ]]; then
    if ! command_exists brew; then
        echo "Installing Homebrew..."
        run_command '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
        
        # Fix Homebrew PATH on Apple Silicon
        if [[ $(uname -m) == "arm64" ]]; then
            echo "Setting up Homebrew PATH for Apple Silicon..."
            if [ -f /opt/homebrew/bin/brew ]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
        fi
    fi
fi

# Install prerequisites and OPAM
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS: Install git and opam via Homebrew
    if ! command_exists git; then
        echo "Installing git..."
        run_command "brew install git"
    else
        echo "git is already installed."
    fi
    
    if ! command_exists opam; then
        run_command "brew install opam"
    else
        echo "opam is already installed."
    fi

    # Install system dependencies needed by OCaml packages below (conf-pkg-config,
    # conf-gmp, conf-libX11 via the graphics package). Installing these explicitly
    # rather than relying on opam's depext auto-install keeps this reliable even
    # if that mechanism doesn't handle the xquartz cask on a given opam version.
    echo "Installing system dependencies (pkg-config, gmp, XQuartz)..."
    run_command "brew install pkg-config pkgconf gmp"
    if [ ! -d "/opt/X11" ]; then
        run_command "brew install --cask xquartz"
    else
        echo "XQuartz is already installed."
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Linux: Install build tools, git, X11 libraries, and opam
    echo "Installing required packages for Linux..."
    run_command "sudo apt-get update"
    # Install system dependencies needed by OCaml packages
    # libgmp-dev: Required by zarith (needed by mirage-crypto-pk, tls, etc.)
    run_command "sudo apt-get install -y gcc make patch unzip m4 git xorg libx11-dev libxft-dev pkg-config libgmp-dev opam"
else
    echo "Unsupported operating system. Please install OPAM manually."
    exit 1
fi

# Initialize OPAM
# Detect if running in a container (Docker, etc.) where sandboxing won't work
# Also check if running as root (common in containers)
OPAM_INIT_FLAGS="-a"
if [ -f /.dockerenv ] || [ -f /run/.containerenv ] || [ "$(id -u)" -eq 0 ]; then
    echo "Detected container environment or root user, disabling opam sandboxing..."
    OPAM_INIT_FLAGS="$OPAM_INIT_FLAGS --disable-sandboxing"
fi
run_command "opam init $OPAM_INIT_FLAGS"

# Configure opam to automatically handle system dependencies without prompting
echo "Configuring opam to auto-install system dependencies..."
run_command "opam option depext-run-installs=true --yes --global"
run_command "opam option depext-bypass=[] --yes --global"

# Check if switch already exists
if opam switch list | grep -q "^. *$SWITCH_NAME"; then
    echo "Switch '$SWITCH_NAME' already exists, switching to it..."
    run_command "opam switch $SWITCH_NAME"
else
    echo "Creating new switch '$SWITCH_NAME' with OCaml $OCAML_VERSION..."
    run_command "opam switch create $SWITCH_NAME $OCAML_VERSION"
fi

# Update OPAM repositories in the switch
run_command "opam update --yes"

# Update the current shell environment to use the new switch
eval $(opam env)

# On Apple Silicon, prioritize arm64 Homebrew paths for pkg-config
# This ensures graphics and other packages find the correct architecture libraries
if [[ "$OSTYPE" == "darwin"* ]] && [[ "$(uname -m)" == "arm64" ]]; then
    echo "Configuring pkg-config paths for Apple Silicon..."
    export PKG_CONFIG_PATH="/opt/homebrew/lib/pkgconfig:/opt/homebrew/share/pkgconfig:$PKG_CONFIG_PATH"
fi

# Verify which switch we're actually in
echo "Current switch: $(opam switch show)"

# Get list of all installed packages once (for efficiency)
installed_packages=$(opam list --installed --switch="$SWITCH_NAME" --short 2>/dev/null)

# Define base packages (always needed)
base_packages=(
    "graphics.5.1.2"
    "ocamlbuild"
    "ocamlfind"
    "yojson"
    "merlin"
    "utop"
    "menhir"
)

# Add dev tools if requested (for course staff)
if [ "$INSTALL_DEV_TOOLS" = true ]; then
    echo "Development mode: including dune and cppo..."
    dev_packages=("dune" "cppo")
else
    dev_packages=()
fi

# Combine all packages
all_packages=("${base_packages[@]}" "${dev_packages[@]}")

# Filter out already installed packages for idempotency
packages_to_install=()
for pkg in "${all_packages[@]}"; do
    if echo "$installed_packages" | grep -qx "$pkg"; then
        echo "✓ Package '$pkg' already installed"
    else
        packages_to_install+=("$pkg")
    fi
done

# Install only missing packages
if [ ${#packages_to_install[@]} -gt 0 ]; then
    echo "Installing missing packages: ${packages_to_install[*]}"
    run_command "opam install -y --assume-depexts ${packages_to_install[*]}"
else
    echo "✓ All required packages are already installed"
fi

# Install CS51 packages
# ANSITerminal: CS51 fork with CI environment color support (rebased on OCaml 5.x compatible upstream)
run_command "opam pin add ANSITerminal https://github.com/cs51-staff/ANSITerminal.git#master -y"
run_command "opam pin add CS51Utils https://github.com/cs51/utils.git -y"

# Install cs51-staff-utils in dev mode. If this script is running from
# staff-utils/scripts/ (a local staff-utils checkout), install from that
# local directory so staff can iterate on it live; otherwise (e.g. a
# standalone Setup clone) pin it from GitHub instead, since there's no
# local checkout to install from.
if [ "$INSTALL_DEV_TOOLS" = true ]; then
    SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
    STAFF_UTILS_DIR="$(dirname "$SCRIPT_DIR")"
    if [ -f "$STAFF_UTILS_DIR/cs51-staff-utils.opam" ]; then
        echo "Installing cs51-staff-utils from local directory..."
        run_command "opam install -y $STAFF_UTILS_DIR"
    else
        echo "Installing cs51-staff-utils from GitHub (no local staff-utils checkout found)..."
        run_command "opam pin add cs51-staff-utils https://github.com/CS51-Staff/staff-utils.git -y"
    fi
fi

# Install or setup Visual Studio Code
if [[ "$OSTYPE" == "darwin"* ]]; then
    if [ ! -d "/Applications/Visual Studio Code.app" ] && [ ! -d "$HOME/Applications/Visual Studio Code.app" ]; then
        echo "Installing Visual Studio Code..."
        run_command "brew install --cask visual-studio-code"
    else
        echo "Visual Studio Code is already installed."
    fi
    # Ensure the 'code' command is available
    if ! command_exists code; then
        echo "Setting up 'code' command..."
        # Add to PATH via shell config instead of symlink
        VSCODE_PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin"
        
        # Detect shell and add to appropriate config file
        if [[ "$SHELL" == *"zsh"* ]]; then
            SHELL_CONFIG="$HOME/.zshrc"
        elif [[ "$SHELL" == *"bash"* ]]; then
            SHELL_CONFIG="$HOME/.bashrc"
        else
            SHELL_CONFIG="$HOME/.profile"
        fi
        
        # Add to PATH if not already present
        if ! grep -q "$VSCODE_PATH" "$SHELL_CONFIG" 2>/dev/null; then
            echo "export PATH=\"\$PATH:$VSCODE_PATH\"" >> "$SHELL_CONFIG"
            echo "Added VSCode to PATH in $SHELL_CONFIG"
        fi
        
        # Also export for current session
        export PATH="$PATH:$VSCODE_PATH"
    fi
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    # Skip VSCode installation in containers (won't work without display)
    if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
        echo "⚠️  Skipping VSCode installation (running in container)"
    elif ! command_exists code; then
        echo "Installing Visual Studio Code..."
        # Detect architecture
        ARCH=$(dpkg --print-architecture)
        run_command "sudo apt-get install -y software-properties-common apt-transport-https wget gpg"
        # Use new signed-by method instead of deprecated apt-key
        run_command "wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/packages.microsoft.gpg > /dev/null"
        run_command "echo \"deb [arch=$ARCH signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main\" | sudo tee /etc/apt/sources.list.d/vscode.list"
        run_command "sudo apt-get update"
        run_command "sudo apt-get install -y code"
    else
        echo "Visual Studio Code is already installed."
    fi
else
    echo "Unsupported operating system. Please install Visual Studio Code manually."
fi

# Install OCaml Platform extension for VSCode
if command_exists code; then
    # Check if extension is already installed (idempotency)
    if code --list-extensions 2>/dev/null | grep -q "ocamllabs.ocaml-platform"; then
        echo "✓ OCaml Platform extension already installed"
    else
        echo "Installing OCaml Platform extension for VSCode..."
        if ! code --install-extension ocamllabs.ocaml-platform 2>&1; then
            echo "⚠️  WARNING: VSCode extension installation failed. You may need to install it manually:"
            echo "   Open VSCode and search for 'OCaml Platform' in Extensions"
        fi
    fi
else
    echo "⚠️  WARNING: 'code' command not found. Please install the OCaml Platform extension manually in VS Code."
fi

# Verify OCaml installation
echo ""
echo "Verifying OCaml installation..."
run_command "opam exec -- ocaml -version"

# Run graphics check
# GRAPHICS_OK tracks the outcome so the final summary can report it honestly
# instead of always declaring success. It stays "true" when the check is
# skipped (container, or cs51-graphics-check missing) since there's nothing
# to report as failed in those cases.
GRAPHICS_OK=true
echo ""
echo "=========================================="
echo "Graphics Check"
echo "=========================================="
# Skip graphics check in containers (no display available)
if [ -f /.dockerenv ] || [ -f /run/.containerenv ]; then
    echo "⚠️  Skipping graphics check (running in container without display)"
    echo ""
elif command_exists cs51-graphics-check; then
    echo "Opening graphics test window..."
    echo ""
    echo "Look for a small window with a white exclamation mark on a red background."
    echo "Click the window and press any key to close it."
    echo ""
    # Run in the foreground (not backgrounded) so we can check the exit code
    # and report a real result instead of always claiming success.
    if opam exec -- cs51-graphics-check; then
        echo ""
        echo "✓ Graphics check passed!"
    else
        GRAPHICS_OK=false
        echo ""
        echo "⚠️  Graphics check failed."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo "  This is common on a freshly set up Mac: XQuartz's graphics server"
            echo "  needs a full logout/login (or restart) before it's available for"
            echo "  the very first time, even though it's now installed."
        else
            echo "  Make sure you're running this from a terminal inside your logged-in"
            echo "  desktop session; not over SSH, and not before you've logged in."
            echo "  A running desktop session provides the display that this check needs."
        fi
    fi
    echo ""
else
    echo "⚠️  Note: Skipping graphics check (cs51-graphics-check not installed)"
    echo ""
fi

# Set up persistent opam environment in shell config
echo ""
echo "Setting up persistent opam environment..."

# Detect shell and add to appropriate config file
if [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_CONFIG="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
    SHELL_CONFIG="$HOME/.bashrc"
else
    SHELL_CONFIG="$HOME/.profile"
fi

# Add opam initialization if not already present
OPAM_INIT_LINE='eval "$(opam env)"'
if ! grep -q "opam env" "$SHELL_CONFIG" 2>/dev/null; then
    echo "" >> "$SHELL_CONFIG"
    echo "# Initialize opam environment (added by CS51 setup script)" >> "$SHELL_CONFIG"
    echo "$OPAM_INIT_LINE" >> "$SHELL_CONFIG"
    echo "✓ Added opam environment initialization to $SHELL_CONFIG"
else
    echo "✓ Opam environment already configured in $SHELL_CONFIG"
fi

echo ""
echo "=========================================="
if [ "$GRAPHICS_OK" = true ]; then
    echo "Setup complete!"
else
    echo "Setup mostly complete -- graphics check needs another look"
fi
echo "=========================================="
echo ""
echo "The CS51 OCaml environment (opam switch '$SWITCH_NAME') is ready!"
echo ""
if [ "$GRAPHICS_OK" = false ]; then
    echo "IMPORTANT: The graphics check above failed. Please log out and log back"
    echo "in (or restart your computer), then run this to confirm it's fixed:"
    echo "    opam exec -- cs51-graphics-check"
    echo ""
fi
echo "IMPORTANT: Please restart your terminal for all changes to take effect."
echo ""
echo "The opam environment will be automatically activated when you open a new terminal."
echo "You can also activate it immediately by running:"
echo "    eval \$(opam env)"
echo ""
echo "To switch to the CS51 environment in the future, run:"
echo "    opam switch $SWITCH_NAME"
echo ""
