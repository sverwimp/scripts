#!/bin/bash

set -e

# Default installation directory
DEFAULT_INSTALL_DIR="$HOME/.bioutils"
INSTALL_DIR=""
FORCE_INSTALL=false

# Get the directory where this script is located (repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Counters
SCRIPT_COUNT=0
UPDATED_COUNT=0
SKIPPED_COUNT=0
C_COUNT=0
C_UPDATED=0

show_help() {
    cat << EOF
Install bioinformatics scripts to a directory and add it to PATH.

Usage: $(basename "$0") [OPTIONS] [install_directory]

Options:
  -f, --force          Force reinstall all bioutils scripts (ignore timestamps)
  -h, --help           Show this help message

Arguments:
  install_directory    Target directory (default: ~/.bioutils)

Examples:
  $(basename "$0")                    # Install/update to ~/.bioutils
  $(basename "$0") ~/bin              # Install/update to ~/bin
  $(basename "$0") -f                 # Force reinstall everything
  $(basename "$0") -f ~/bin           # Force reinstall to ~/bin

What this script does:
  1. Creates the target directory if it doesn't exist
  2. Copies all scripts from subdirectories (fasta/, etc.)
  3. Only copies files that are newer than destination (unless -f is used)
  4. Compiles any C programs found
  5. Makes all scripts executable
  6. Adds the directory to PATH in your shell config

Update mode:
  Run the same command again to update. Only modified scripts will be copied.
  Use -f to force reinstall everything.
EOF
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--force)
                FORCE_INSTALL=true
                shift
                ;;
            -*)
                echo "Error: Unknown option '$1'" >&2
                show_help >&2
                exit 1
                ;;
            *)
                if [ -z "$INSTALL_DIR" ]; then
                    INSTALL_DIR="$1"
                else
                    echo "Error: Too many arguments" >&2
                    show_help >&2
                    exit 1
                fi
                shift
                ;;
        esac
    done
    INSTALL_DIR="${INSTALL_DIR:-$DEFAULT_INSTALL_DIR}"
}

should_copy() {
    local src="$1"
    local dst="$2"
    [[ "$FORCE_INSTALL" == true ]] && return 0      # Always copy in force mode
    [[ ! -f "$dst" ]] && return 0                   # Copy if destination doesn't exist
    [[ "$src" -nt "$dst" ]] && return 0             # Copy if source is newer than destination
    return 1                                        # Don't copy           
}

# ✓ Alt + 10003
# ↻ Alt + 8635 
# ✗ Alt + 10007
install_basic_scripts() {
    while IFS= read -r -d '' script; do
        filename="$(basename "$script")"
        rel_path="${script#$SCRIPT_DIR/}"
        
        # Filter logic: don't copy install script, readme files, license, 
        # hidden files, and C files (compiled later)
        [[ "$filename" == "install.sh" ]] && continue
        [[ "${filename,,}" == "readme.md" ]] && continue
        [[ "${filename,,}" == "license" ]] && continue
        [[ "$rel_path" == .* ]] && continue
        [[ "$filename" == *.c ]] && continue

        dest_file="$INSTALL_DIR/$filename"

        is_update=false
        if [ -f "$dest_file" ] && [ "$script" -nt "$dest_file" ]; then
            is_update=true
        fi
        
        if should_copy "$script" "$dest_file"; then
            cp "$script" "$dest_file"
            chmod +x "$dest_file"

            if [ "$is_update" = true ]; then
                echo "  ↻ $filename (updated)"
            else
                echo "  ✓ $filename"
            fi
            # SAFE INCREMENT: The || true prevents set -e from killing the script
            ((UPDATED_COUNT++)) || true
        else
            echo "  - $filename (up to date)"
            ((SKIPPED_COUNT++)) || true
        fi

        ((SCRIPT_COUNT++)) || true

    done < <(find "$SCRIPT_DIR" -type f ! -path "*/.*" -print0)
}

check_gcc_installed() {
    if ! command -v gcc &> /dev/null; then
        echo
        echo "Warning: gcc is required to compile C programs." >&2
        return 1
    fi
    return 0
}

check_zlib_installed() {
    if ! printf "#include <zlib.h>\nint main(){return 0;}\n" | gcc -x c - -o /dev/null -lz >/dev/null 2>&1; then
        echo
        echo "Warning: zlib development package is required to compile C programs." >&2
        echo "Please install it (e.g., 'sudo apt-get install zlib1g-dev' on Debian/Ubuntu)." >&2
        return 1
    fi
    return 0
}

compile_c_scripts() {
    echo
    echo "Looking for C programs to compile..."

    if ! check_gcc_installed || ! check_zlib_installed; then
        echo "Skipping C program compilation." >&2
        return
    fi

    while IFS= read -r -d '' c_file; do
        filename="$(basename "$c_file" .c)"
        dest_file="$INSTALL_DIR/$filename"
        
        if should_copy "$c_file" "$dest_file"; then
            echo "  Compiling $filename..."

            if gcc -O2 -Wall "$c_file" -o "$dest_file" -lz; then
                chmod +x "$dest_file"
                echo "  ✓ $filename (compiled)"
                ((C_UPDATED++)) || true
            else
                echo "  ✗ Failed to compile $filename" >&2
            fi
        else
            echo "  - $filename (up to date)"
        fi
        ((C_COUNT++)) || true
    done < <(find "$SCRIPT_DIR" -type f -name "*.c" ! -path "*/.*" -print0)

    if [ $C_COUNT -eq 0 ]; then
        echo "  No C programs found"
    fi
}

configure_path() {
    echo
    echo "Configuring PATH..."

    SHELL_NAME="$(basename "$SHELL")"
    case "$SHELL_NAME" in
        bash)
            RC_FILE="$HOME/.bashrc"
            ;;
        zsh)
            RC_FILE="$HOME/.zshrc"
            ;;
        fish)
            RC_FILE="$HOME/.config/fish/config.fish"
            ;;
        *)
            RC_FILE="$HOME/.profile"
            echo "  Warning: Using .profile (detected shell: $SHELL_NAME)"
            ;;
    esac

    if [[ ":$PATH:" == *":$INSTALL_DIR:"* ]]; then
        echo "  ✓ $INSTALL_DIR is already in PATH" 
    else
        echo "  Adding $INSTALL_DIR to PATH in $RC_FILE"

        if [ ! -f "$RC_FILE" ]; then
            echo "  Error: Unable add $INSTALL_DIR to PATH."
            echo "         $RC_FILE does not exist. Please add $INSTALL_DIR to your PATH manually."  
            return
        fi

        # Add PATH export to shell config
        if [ "$SHELL_NAME" = "fish" ]; then
            # Fish shell uses different syntax
            echo "" >> "$RC_FILE"
            echo "# Added by bioutils installer" >> "$RC_FILE"
            echo "set -gx PATH $INSTALL_DIR \$PATH" >> "$RC_FILE"
        else
            echo "" >> "$RC_FILE"
            echo "# Added by bioutils installer" >> "$RC_FILE"
            echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$RC_FILE"
        fi
        
        echo "  ✓ Updated $RC_FILE"
        echo
        echo "  To use the bioutils immediately, run:"
        echo "    source $RC_FILE"
        echo "  Or simply open a new terminal."
    fi
}

# --- Main ---

parse_args "$@"

echo "=== Script Installation ==="
echo "Target directory: $INSTALL_DIR"
echo "Source directory: $SCRIPT_DIR"
echo

# Create installation directory
if [ ! -d "$INSTALL_DIR" ]; then
    echo "Creating directory: $INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"
else
    echo "Directory exists: $INSTALL_DIR"
fi

echo
echo "Copying scripts..."

install_basic_scripts
compile_c_scripts

TOTAL_COUNT=$((SCRIPT_COUNT + C_COUNT))
TOTAL_UPDATED=$((UPDATED_COUNT + C_UPDATED))

if [ $TOTAL_COUNT -eq 0 ]; then
    echo
    echo "Warning: No scripts found to install!" >&2
    exit 1
fi

echo
if [ $TOTAL_UPDATED -gt 0 ]; then
    echo "Installed/Updated $TOTAL_UPDATED of $TOTAL_COUNT script(s) to $INSTALL_DIR"
    if [ $SKIPPED_COUNT -gt 0 ]; then
        echo "($SKIPPED_COUNT script(s) already up to date)"
    fi
else
    echo "All $TOTAL_COUNT script(s) are already up to date in $INSTALL_DIR"
fi


echo
echo "=== Installation Complete ==="
echo
echo "Installed scripts:"
ls -1 "$INSTALL_DIR" | sed 's/^/  - /'
echo
echo "You can now run these commands from anywhere!"
