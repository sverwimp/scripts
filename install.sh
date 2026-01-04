#!/bin/bash

set -e

# Default installation directory
DEFAULT_INSTALL_DIR="$HOME/.scripts"
INSTALL_DIR=""
FORCE_INSTALL=false

# Get the directory where this script is located (repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

show_help() {
    cat << EOF
Install bioinformatics scripts to a directory and add it to PATH.

Usage: $(basename "$0") [OPTIONS] [install_directory]

Options:
  -f, --force          Force reinstall all scripts (ignore timestamps)
  -h, --help           Show this help message

Arguments:
  install_directory    Target directory (default: ~/.scripts)

Examples:
  $(basename "$0")                    # Install/update to ~/.scripts
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

# Parse arguments
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
script_count=0
updated_count=0
skipped_count=0

should_copy() {
    local src="$1"
    local dst="$2"
    
    if [ "$FORCE_INSTALL" = true ]; then
        return 0  # Always copy in force mode
    fi
    
    if [ ! -f "$dst" ]; then
        return 0  # Copy if destination doesn't exist
    fi
    
    # Copy if source is newer than destination
    if [ "$src" -nt "$dst" ]; then
        return 0
    fi
    
    return 1  # Don't copy
}

# Find all files, but exclude hidden paths, the installer, and metadata
while IFS= read -r -d '' script; do
    filename="$(basename "$script")"
    rel_path="${script#$SCRIPT_DIR/}"
    
    # Skip metadata and the installer itself
    if [[ "$filename" == "install.sh" ]] || \
       [[ "${filename,,}" == "readme.md" ]] || \
       [[ "${filename,,}" == "license" ]] || \
       [[ "$rel_path" == .* ]] || \
       [[ "$filename" == *.c ]]; then # Skip C files here; handled in the next loop
        continue
    fi
    
    dest_file="$INSTALL_DIR/$filename"
    
    # Check update status BEFORE the copy
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
        ((updated_count++)) || true
    else
        echo "  - $filename (up to date)"
        ((skipped_count++)) || true
    fi
    
    ((script_count++)) || true

done < <(find "$SCRIPT_DIR" -type f ! -path "*/.*" -print0)


# Find and compile C programs
echo
echo "Looking for C programs to compile..."
c_count=0
c_updated=0

while IFS= read -r -d '' c_file; do
    filename="$(basename "$c_file" .c)"
    dest_file="$INSTALL_DIR/$filename"
    
    if should_copy "$c_file" "$dest_file"; then
        echo "  Compiling $filename..."
        
        if gcc -O2 -Wall "$c_file" -o "$dest_file" -lz; then
            chmod +x "$dest_file"
            echo "  ✓ $filename (compiled)"
            ((c_updated++)) || true
        else
            echo "  ✗ Failed to compile $filename" >&2
        fi
    else
        echo "  - $filename (up to date)"
    fi
    
    ((c_count++)) || true
done < <(find "$SCRIPT_DIR" -type f -name "*.c" ! -path "*/.*" -print0)

if [ $c_count -eq 0 ]; then
    echo "  No C programs found"
fi

total_count=$((script_count + c_count))
total_updated=$((updated_count + c_updated))

if [ $total_count -eq 0 ]; then
    echo
    echo "Warning: No scripts found to install!" >&2
    exit 1
fi

echo
if [ $total_updated -gt 0 ]; then
    echo "Installed/Updated $total_updated of $total_count script(s) to $INSTALL_DIR"
    if [ $skipped_count -gt 0 ]; then
        echo "($skipped_count script(s) already up to date)"
    fi
else
    echo "All $total_count script(s) are already up to date in $INSTALL_DIR"
fi

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
    
    # Add PATH export to shell config
    if [ "$SHELL_NAME" = "fish" ]; then
        # Fish shell uses different syntax
        echo "" >> "$RC_FILE"
        echo "# Added by scripts installer" >> "$RC_FILE"
        echo "set -gx PATH $INSTALL_DIR \$PATH" >> "$RC_FILE"
    else
        echo "" >> "$RC_FILE"
        echo "# Added by scripts installer" >> "$RC_FILE"
        echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$RC_FILE"
    fi
    
    echo "  ✓ Updated $RC_FILE"
    echo
    echo "  To use the scripts immediately, run:"
    echo "    source $RC_FILE"
    echo "  Or simply open a new terminal."
fi

echo
echo "=== Installation Complete ==="
echo
echo "Installed scripts:"
ls -1 "$INSTALL_DIR" | sed 's/^/  - /'
echo
echo "You can now run these commands from anywhere!"
