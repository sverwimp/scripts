# File Formats

Utilities to modify or convert file formats used in bioinformatics.

## Scripts

### `prokkify`
Create a Prokka-like GFF3 file with embedded FASTA sequence(s) from common genome annotation formats.

Coverts either a **Genbank** file or a combination of a **GFF3 and FASTA** file into a single GFF3 file containing a `##FASTA` section, suitable for downstream tools that expect Prokka-style input.

```bash
prokkify --genbank genome.gbk --out genome.gff
prokkify --gff annotations.gff --fasta genome.fna --out genome.gff

# Without --out, the output will print to the standard output
prokkify --genbank genome.gbk.gz | gzip > genome.gff.gz
```