#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <stdbool.h>
#include <zlib.h>
#include <sys/stat.h>
#include <errno.h>
#include <ctype.h>

#define BUFFER_SIZE (16 * 1024 * 1024)  // 16MB buffer
#define MAX_FILES 100
#define MAX_LINE 65536

typedef struct {
    long long bases;
    long long reads;
} fastq_result_t;

bool file_exists(const char *filename) {
    struct stat buffer;
    return (stat(filename, &buffer) == 0);
}

// Format number with thousand separators
void format_number(long long num, char *buf, size_t bufsize) {
    char temp[64];
    snprintf(temp, sizeof(temp), "%lld", num);
    int len = strlen(temp);
    int commas = (len - 1) / 3;
    int new_len = len + commas;
    
    if (new_len >= bufsize) {
        snprintf(buf, bufsize, "%lld", num);
        return;
    }
    
    buf[new_len] = '\0';
    int src = len - 1;
    int dst = new_len - 1;
    int count = 0;
    
    while (src >= 0) {
        buf[dst--] = temp[src--];
        count++;
        if (count == 3 && src >= 0) {
            buf[dst--] = ',';
            count = 0;
        }
    }
}

// Extract basename from path
const char* get_basename(const char *path) {
    const char *base = strrchr(path, '/');
    return base ? base + 1 : path;
}

// Unified genome length reader supporting FASTA and GenBank
long long genome_length(const char *filename) {
    gzFile fp = gzopen(filename, "rb");
    if (!fp) {
        fprintf(stderr, "Error: Cannot open file %s: %s\n", filename, strerror(errno));
        return -1;
    }
    
    gzbuffer(fp, BUFFER_SIZE);
    
    long long total = 0;
    char line[MAX_LINE];
    bool in_sequence = false;
    bool is_genbank = false;
    bool format_detected = false;
    
    while (gzgets(fp, line, MAX_LINE)) {
        // Skip whitespace
        char *p = line;
        while (*p == ' ' || *p == '\t') p++;
        
        // Detect format on first meaningful line
        if (!format_detected && *p != '\0' && *p != ';' && *p != '#') {
            if (*p == '>') {
                format_detected = true;
                is_genbank = false;
                continue;  // Skip FASTA header
            } else if (strncmp(p, "LOCUS", 5) == 0) {
                format_detected = true;
                is_genbank = true;
                continue;
            }
        }
        
        if (is_genbank) {
            // GenBank format
            if (strncmp(p, "ORIGIN", 6) == 0) {
                in_sequence = true;
                continue;
            }
            if (p[0] == '/' && p[1] == '/') {
                in_sequence = false;
                continue;
            }
            
            if (in_sequence) {
                // Skip line numbers
                while (*p && isdigit(*p)) p++;
                while (*p == ' ') p++;
                
                // Count bases
                for (; *p; p++) {
                    if (isalpha(*p)) {
                        total++;
                    }
                }
            }
        } else {
            // FASTA format
            if (*p == '>' || *p == ';') continue;
            
            // Count bases
            for (; *p; p++) {
                if (isalpha(*p)) {
                    total++;
                }
            }
        }
    }
    
    gzclose(fp);
    
    if (!format_detected) {
        fprintf(stderr, "Error: Could not determine format for %s (expected FASTA or GenBank)\n", filename);
        return -1;
    }
    
    return total;
}

fastq_result_t fastq_bases(const char *filename) {
    fastq_result_t result = {-1, 0};
    
    gzFile fp = gzopen(filename, "rb");
    if (!fp) {
        fprintf(stderr, "Error: Cannot open file %s: %s\n", filename, strerror(errno));
        return result;
    }
    
    // Set larger internal buffer for gzgets
    gzbuffer(fp, BUFFER_SIZE);
    
    long long total_bases = 0;
    long long num_reads = 0;
    char line[MAX_LINE];
    
    // Read FASTQ in groups of 4 lines
    while (gzgets(fp, line, MAX_LINE)) {  // Header line
        // Read sequence line
        if (!gzgets(fp, line, MAX_LINE)) break;
        
        // Count bases (strlen - 1 to exclude newline)
        int len = strlen(line);
        if (len > 0 && line[len-1] == '\n') len--;
        total_bases += len;
        
        // Skip '+' line
        if (!gzgets(fp, line, MAX_LINE)) break;
        
        // Skip quality line
        if (!gzgets(fp, line, MAX_LINE)) break;
        
        num_reads++;
    }
    
    gzclose(fp);
    result.bases = total_bases;
    result.reads = num_reads;
    return result;
}

void print_usage(const char *prog_name) {
    fprintf(stderr, "Calculates average sequencing read depth from FASTQ files against a reference genome.\n\n");
    fprintf(stderr, "Usage: %s -g <genome.(fasta|gbk)(.gz)> [options] <reads.fq(.gz)> [<reads2.fq(.gz)> ...]\n\n", prog_name);
    fprintf(stderr, "Required:\n");
    fprintf(stderr, "  -g, --genome FILE      Reference genome (FASTA or GenBank, optionally gzipped)\n");
    fprintf(stderr, "  <reads.fq(.gz)> ...    One or more FASTQ files (optionally gzipped)\n\n");
    fprintf(stderr, "Options:\n");
    fprintf(stderr, "  -v, --verbose          Show detailed statistics\n");
    fprintf(stderr, "  -h, --help             Show this help message\n\n");
    fprintf(stderr, "Default output: coverage as a single number (e.g., 45.23)\n");
    fprintf(stderr, "Verbose output: formatted summary of reads and bases per file\n\n");
    fprintf(stderr, "Examples:\n");
    fprintf(stderr, "  %s -g ref.fasta reads_R1.fq.gz reads_R2.fq.gz\n", prog_name);
    fprintf(stderr, "  %s -g ref.gbk.gz -v sample1.fq sample2.fq sample3.fq\n", prog_name);
}

int main(int argc, char *argv[]) {
    char *genome = NULL;
    bool verbose = false;
    
    static struct option long_options[] = {
        {"genome",   required_argument, 0, 'g'},
        {"verbose",  no_argument,       0, 'v'},
        {"help",     no_argument,       0, 'h'},
        {0, 0, 0, 0}
    };
    
    int opt;
    while ((opt = getopt_long(argc, argv, "g:vh", long_options, NULL)) != -1) {
        switch (opt) {
            case 'h':
                print_usage(argv[0]);
                return 0;
            case 'g':
                genome = optarg;
                break;
            case 'v':
                verbose = true;
                break;
            default:
                print_usage(argv[0]);
                return 1;
        }
    }
    
    // Validate inputs
    if (!genome) {
        fprintf(stderr, "Error: Genome file is required (-g)\n\n");
        print_usage(argv[0]);
        return 1;
    }
    
    // Remaining arguments are FASTQ files
    int fastq_count = argc - optind;
    if (fastq_count == 0) {
        fprintf(stderr, "Error: At least one FASTQ file is required\n\n");
        print_usage(argv[0]);
        return 1;
    }
    
    if (fastq_count > MAX_FILES) {
        fprintf(stderr, "Error: Too many FASTQ files (max %d)\n", MAX_FILES);
        return 1;
    }
    
    // Check if genome file exists
    if (!file_exists(genome)) {
        fprintf(stderr, "Error: Genome file not found: %s\n", genome);
        return 1;
    }
    
    // Check if all FASTQ files exist and detect duplicates
    for (int i = optind; i < argc; i++) {
        if (!file_exists(argv[i])) {
            fprintf(stderr, "Error: FASTQ file not found: %s\n", argv[i]);
            return 1;
        }
        // Check for duplicates
        for (int j = i + 1; j < argc; j++) {
            if (strcmp(argv[i], argv[j]) == 0) {
                fprintf(stderr, "Warning: File '%s' appears multiple times in input\n", argv[i]);
            }
        }
    }
    
    // Process genome
    long long genome_len = genome_length(genome);
    if (genome_len < 0) {
        return 1;
    }
    if (genome_len == 0) {
        fprintf(stderr, "Error: Genome length is zero\n");
        return 1;
    }
    
    // Track all files for verbose output
    typedef struct {
        const char *filename;
        long long bases;
        long long reads;
    } file_stats_t;
    
    file_stats_t *stats = malloc(sizeof(file_stats_t) * fastq_count);
    if (!stats) {
        fprintf(stderr, "Error: Memory allocation failed\n");
        return 1;
    }
    
    long long total_bases = 0;
    long long total_reads = 0;
    
    // Process all FASTQ files
    for (int i = 0; i < fastq_count; i++) {
        const char *filename = argv[optind + i];
        fastq_result_t res = fastq_bases(filename);
        if (res.bases < 0) {
            free(stats);
            return 1;
        }
        total_bases += res.bases;
        total_reads += res.reads;
        stats[i] = (file_stats_t){filename, res.bases, res.reads};
    }
    
    double coverage = (double)total_bases / genome_len;
    
    if (verbose) {
        char buf[64];
        
        // Find maximum widths for alignment
        int max_reads_width = 0;
        int max_bases_width = 0;
        
        for (int i = 0; i < fastq_count; i++) {
            format_number(stats[i].reads, buf, sizeof(buf));
            int w = strlen(buf);
            if (w > max_reads_width) max_reads_width = w;
            
            format_number(stats[i].bases, buf, sizeof(buf));
            w = strlen(buf);
            if (w > max_bases_width) max_bases_width = w;
        }
        
        format_number(total_reads, buf, sizeof(buf));
        int w = strlen(buf);
        if (w > max_reads_width) max_reads_width = w;
        
        format_number(total_bases, buf, sizeof(buf));
        w = strlen(buf);
        if (w > max_bases_width) max_bases_width = w;
        
        // Print genome
        format_number(genome_len, buf, sizeof(buf));
        printf("Reference genome: %s bp\n", buf);
        
        // Print reads
        format_number(total_reads, buf, sizeof(buf));
        printf("Total reads:                     %*s\n", max_reads_width, buf);
        for (int i = 0; i < fastq_count; i++) {
            format_number(stats[i].reads, buf, sizeof(buf));
            printf("  %-30s %*s\n", get_basename(stats[i].filename), 
                   max_reads_width, buf);
        }
        
        // Print bases
        format_number(total_bases, buf, sizeof(buf));
        printf("Total bases:                     %*s bp\n", max_bases_width, buf);
        for (int i = 0; i < fastq_count; i++) {
            format_number(stats[i].bases, buf, sizeof(buf));
            printf("  %-30s %*s bp\n", get_basename(stats[i].filename), 
                   max_bases_width, buf);
        }
        
        printf("Average coverage: %.2fx\n", coverage);
    } else {
        printf("%.2f\n", coverage);
    }
    
    free(stats);
    return 0;
}
