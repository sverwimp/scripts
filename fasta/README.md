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

> [!TIP]
> If you only have a few patterns, you don't need a list file. Use the regex pipe `|` to match multiple items:
> 
> ```bash
> fasta-extract -r '(chr1|chrX|chrY)' genome.fa
> fasta-extract -r 'contig_[0-9]+' genome.fa
> ```

### `fasta-size`
Calculate total sequence length or extract/filter FASTA entries by size.
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

# Extract smallest entry
fasta-size --min genome.fa

# Extract largest entry
fasta-size --max genome.fa

# Extract and save entries >= 1000 bp
fasta-size --threshold 1000 genome.fa --out large_entries.fa

# Extract entries <= 500 bp
fasta-size --max-threshold 500 genome.fa
```

**Options:** `--min` (smallest entry), `--max` (largest entry), `--threshold SIZE` (entries ≥ SIZE), `--max-threshold SIZE` (entries ≤ SIZE), `-o` (output file), `-w` (line width)

## Notes

All scripts:
- Accept input from files or stdin
- Include `-h` flag for help documentation
- Handle gzipped files when piped through zcat