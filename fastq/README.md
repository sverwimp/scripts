# FASTQ Tools

Command-line utilities for working with FASTQ files.

## Scripts

### `fastq-depth`
Calculates **average** sequencing read depth from FASTQ files against a reference genome.

The default output is a single numeric value representing the average depth.
An optional verbose mode reports additional statistics per input file.

```bash
# Basic usage (outputs coverage as single number)
fastq-depth -g reference.fasta reads_R1.fq.gz reads_R2.fq.gz
# Output: 45.26

# Verbose output with detailed statistics
fastq-depth -g reference.gbk.gz -v sample1.fq sample2.fq
# Output:
# Reference genome: 4,641,652 bp
# Total reads:                     15,234,567
#   sample1.fq                      7,891,234
#   sample2.fq                      7,343,333
# Total bases:                     210,123,456 bp
#   sample1.fq                     108,567,890 bp
#   sample2.fq                     101,555,566 bp
# Average coverage: 45.26x

# Multiple FASTQ files
fastq-depth -g genome.fasta reads1.fq reads2.fq reads3.fq

# Works with gzipped files
fastq-depth -g reference.fasta.gz reads.fq.gz
```

**Required:**
- `-g, --genome FILE` - Reference genome (FASTA or GenBank format, optionally gzipped)
- One or more FASTQ files (optionally gzipped)

**Options:**
- `-v, --verbose` - Show detailed statistics per file
- `-h, --help` - Show help message

> [!NOTE]
> Default output is a single number (coverage value) for easy parsing in pipelines. Use `-v` for human-readable detailed output.