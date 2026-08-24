# CS51 Setup

Automated setup scripts for the CS51 OCaml development environment.

## Quick Start

Run the setup script to install everything you need for CS51:

```bash
./cs51_install.sh
```

This will install:
- OPAM (OCaml Package Manager)
- OCaml 5.2.1 in a dedicated `cs51` switch
- Required packages (graphics, ocamlbuild, ocamlfind, yojson, merlin, utop, menhir)
- CS51Utils library
- ANSITerminal (CS51 fork)
- Visual Studio Code with OCaml Platform extension

## Options

### Installation

```bash
./cs51_install.sh [-dry-run] [-dev]
```

**Flags:**
- `-dry-run`: Show what would be installed without actually installing
- `-dev`: Install development tools (dune, cppo) - for course staff only

### Uninstallation

```bash
./cs51_uninstall.sh [-dry-run] [-remove-vscode] [-remove-opam]
```

**Flags:**
- `-dry-run`: Show what would be removed without actually removing
- `-remove-vscode`: Also remove Visual Studio Code (use with caution)
- `-remove-opam`: Remove OPAM completely (removes all switches)

## One-Liner Setup

For convenience, you can run the setup script directly:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/cs51/setup/main/cs51_install.sh)"
```

## System Requirements

- macOS (including Apple Silicon) or Debian-based Linux (Ubuntu, etc.)
- Internet connection
- sudo privileges for certain installation steps

## What Gets Installed

The setup script creates an isolated OCaml environment in an opam switch called `cs51`. This doesn't interfere with any other OCaml installations you might have.

After installation:
- Restart your terminal for all changes to take effect
- The opam environment is automatically activated in new terminals
- Use `opam switch cs51` to switch to the CS51 environment if needed

## Troubleshooting

If you encounter issues:

1. **Check the logs**: Error messages will indicate what failed
2. **Run in dry-run mode**: `./cs51_install.sh -dry-run` to see what would happen
3. **Try uninstalling and reinstalling**: `./cs51_uninstall.sh` then `./cs51_install.sh`

## For Staff

Install development tools with:
```bash
./cs51_install.sh -dev
```

## License

MIT License - See LICENSE file for details
