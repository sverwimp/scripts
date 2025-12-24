# FASTA Tools

Command-line utilities for working with FASTA files.

## Scripts

### `fasta-extract`
Extract fasta records from FASTA files through pattern matching on headers.

```bash
# Basic substring search
fasta-extract 'PilB' genome.faa

# Case-insensitive with regex
fasta-extract -i -r '^chr[0-9]+' genome.fa

# Extract multiple patterns from a file
fasta-extract -l ids.txt genome.faa

# Count matches only
fasta-extract -c 'mitochondria' genome.fa
```

**Options:** `-i` (case-insensitive), `-r` (regex), `-x` (exact ID), `-l` (list file), `-v` (invert), `-n` (names only), `-c` (count)

Use `fasta-extract -h` for help or `fasta-extract -m` for more details.

### `fasta-size`
Calculate total sequence length (base pairs) from FASTA files.

```bash
# Single file (prints size only)
fasta-size genome.fa
# Output: 3141592

# Multiple files (prints filename: size)
fasta-size genome1.fa genome2.fa
# Output: genome1.fa: 3141592
#         genome2.fa: 2718281

# From stdin
cat genome.fa | fasta-size
```

## Notes

All scripts:
- Accept input from files or stdin
- Include `-h` flag for help documentation
- Handle gzipped files when piped through zcat