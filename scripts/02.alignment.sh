#!/bin/bash

eval "$(conda shell.bash hook)"                                      # Initialize conda shell integration
conda activate bsseq_env                                             # Activate bsseq environment

# Mount F: drive if not already mounted
if ! mount | grep -q "/mnt/f"; then
    echo "📦 Mounting F: drive..."
    sudo mount -t drvfs F: /mnt/f
fi

timestamp=$(date +"%m-%d-%Y_%H-%M-%S")                                # Timestamp for log file
mkdir -p /mnt/f/Research_Drive/01.raw/01.methylation/fastq/logs                                                        # Create logs directory
LOG_FILE="/mnt/f/Research_Drive/01.raw/01.methylation/fastq/logs/log_${timestamp}.txt"                                 # Set log file name

message() {
    echo "[$(date +"%m-%d-%Y %H:%M:%S")]: $1" | tee -a "$LOG_FILE"   # Function to log and print messages
}

message "🚀 Starting alignment pipeline"

# mkdir -p /mnt/f/Research_Drive/01.raw/01.methylation/fastq/ref       # Create reference directory
# mkdir -p /mnt/f/Research_Drive/01.raw/01.methylation/fastq/ref/hg38  # Create hg38 subdirectory
# cd /mnt/f/Research_Drive/01.raw/01.methylation/fastq/ref/hg38        # Move into hg38 directory

# GENOMEz=/mnt/f/Research_Drive/01.raw/01.methylation/fastq/ref/hg38/hg38.fa.gz      # Compressed genome path
# wget -O $GENOMEz http://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz # Download hg38 genome
# gunzip $GENOMEz                                                                     # Decompress genome

GENOME_DIR=~/genomes/hg38                                                         # Set reference directory

message "🧬 Preparing Bismark genome index"
# bismark_genome_preparation --verbose $GENOME_DIR                                   # Build Bismark index

INPUT_DIR=/mnt/f/Research_Drive/01.raw/01.methylation/fastq                         # Input FASTQ path
OUTPUT_DIR=/mnt/f/Research_Drive/01.raw/01.methylation/aligned                     # Output BAM path
mkdir -p "$OUTPUT_DIR"                                                             # Ensure output dir exists

message "📥 Aligning sample SRR20731213"
bismark \
  --genome "$GENOME_DIR" \
  -1 "$INPUT_DIR/SRR20731213_1.fastq" \
  -2 "$INPUT_DIR/SRR20731213_2.fastq" \
  -o "$OUTPUT_DIR" \
  --bowtie2 \
  --multicore 8                                                                    # Run Bismark alignment

message "✅ Alignment complete"
