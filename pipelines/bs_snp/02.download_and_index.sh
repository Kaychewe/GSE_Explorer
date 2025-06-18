#!/usr/bin/env bash
#SBATCH --job-name=bs_download
#SBATCH --output=logs/download_%j.out
#SBATCH --error=logs/download_%j.err

# === Activate environment ===
eval "$(conda shell.bash hook)"
conda activate bsseq_env

# === Logging Setup ===
timestamp=$(date +"%m-%d-%Y_%H-%M-%S")
mkdir -p logs
LOG_FILE="logs/download_fastq_${timestamp}.log"
export LOG_FILE

# === Import Utility Functions ===
source utils.sh
message "Logger initialized" >> "$LOG_FILE" 2>&1

# === Check for Genome Index ===
GENOME_FASTA=/mnt/f/Research_Drive/01.raw/01.methylation/fastq/ref/hg38/hg38.fa
GENOME_DIR=~/genomes/hg38
GENOME_INDEX_CHECK="$GENOME_DIR/Bisulfite_Genome/BS_CT/BS_CT.1.bt2"

if [[ ! -f "$GENOME_INDEX_CHECK" ]]; then
    mkdir -p "$GENOME_DIR"
    if [[ ! -f "$GENOME_FASTA" ]]; then
        message "Downloading hg38 genome..." >> "$LOG_FILE" 2>&1
        wget -O "$GENOME_FASTA.gz" http://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz
        gunzip "$GENOME_FASTA.gz"
    fi
    cp "$GENOME_FASTA" "$GENOME_DIR/hg38.fa"
    message "Building Bismark genome index..." >> "$LOG_FILE" 2>&1
    bismark_genome_preparation --verbose "$GENOME_DIR" >> "$LOG_FILE" 2>&1
else
    message "Bismark genome index already exists. Skipping index generation." >> "$LOG_FILE" 2>&1
fi

# === Setup ===
SHARED_BASE="/ifs/groups/sacanGrp/kc3745/pipelines/bs_snp"
GSE_FILE="gse.txt"
INPUT_DIR="$SHARED_BASE/data/fastq"
OUTPUT_DIR="$SHARED_BASE/data/bam"
mkdir -p "$OUTPUT_DIR"
TMP_DIR="$SHARED_BASE/tmp"
mkdir -p "$TMP_DIR"

# === Download and Align ===
message "Starting FASTQ processing..." >> "$LOG_FILE" 2>&1
NTHREADS=$(nproc)
HALF_NTHREADS=$((NTHREADS / 2))

for metadata_tsv in "$SHARED_BASE/metadata/"*_run_metadata.tsv; do
    GSE=$(basename "$metadata_tsv" | cut -d'_' -f1)
    message "Processing metadata file: $metadata_tsv" >> "$LOG_FILE" 2>&1

    SRR_LIST=$(awk -F'\t' 'NR > 1 {print $22}' "$metadata_tsv" | sort -u)

    for SRR in $SRR_LIST; do
        [[ -z "$SRR" ]] && continue

        OUT_DIR="$INPUT_DIR/$GSE/$SRR"
        mkdir -p "$OUT_DIR"

        message "Downloading $SRR to $OUT_DIR" >> "$LOG_FILE" 2>&1
        START_TIME=$(date +%s)

        fasterq-dump "$SRR" \
            --split-files \
            -O "$OUT_DIR" \
            --temp "$TMP_DIR" \
            --threads "$HALF_NTHREADS" >> "$LOG_FILE" 2>&1

        END_TIME=$(date +%s)
        RUNTIME=$((END_TIME - START_TIME))

        if [[ -f "$OUT_DIR/${SRR}_1.fastq" && -f "$OUT_DIR/${SRR}_2.fastq" ]]; then
            message "Download complete for $SRR in $RUNTIME seconds" >> "$LOG_FILE" 2>&1

            message "Aligning $SRR with Bismark..." >> "$LOG_FILE" 2>&1
            bismark \
              --genome "$GENOME_DIR" \
              -1 "$OUT_DIR/${SRR}_1.fastq" \
              -2 "$OUT_DIR/${SRR}_2.fastq" \
              -o "$OUTPUT_DIR/$GSE" \
              --bowtie2 \
              --multicore "$HALF_NTHREADS" >> "$LOG_FILE" 2>&1

            message "Alignment complete for $SRR" >> "$LOG_FILE" 2>&1

            rm -rf "$OUT_DIR"/* "$TMP_DIR"/*
            message "Cleaned up FASTQ and TMP for $SRR" >> "$LOG_FILE" 2>&1
        else
            message "Failed to download or find FASTQ for $SRR" >> "$LOG_FILE" 2>&1
        fi
    done

done

message "🎉 Pipeline completed." >> "$LOG_FILE" 2>&1
