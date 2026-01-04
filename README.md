# Scripts

A personal collection of standalone, portable command-line utilities for bioinformatics and data analysis.

## Categories

- **`fasta/`** - Scripts working with FASTA sequence files
- **`file_formats/`** - Scripts modifying or converting file formats

## Installation

### **Option 1: Install all scripts**

Clone the repository and run the installer:

```bash
git clone https://github.com/sverwimp/scripts.git
cd scripts
./install.sh
```

This will:
- Install all scripts to `~/.scripts` (or a custom directory of your choice)
- Compile any C programs automatically
- Add the directory to your PATH
- Make all scripts executable

**Custom installation directory:**
```bash
./install.sh                    # Install to ~/.scripts
./install.sh ~/bin              # Install to ~/bin
./install.sh /usr/local/bin     # System-wide (requires sudo)
```

**Updating:**

After pulling new changes or adding scripts, simply run the installer again:
```bash
git pull
./install.sh
```

Only modified or new scripts will be copied. Use `./install.sh -f` to force reinstall everything.

### **Option 2: Use individual scripts**

Each script is self-contained. You can copy any single script directly and use it without installing the entire collection.

## Requirements

Most scripts use standard Unix tools (bash, awk, grep) or Python and should work on Linux/macOS without additional dependencies.
