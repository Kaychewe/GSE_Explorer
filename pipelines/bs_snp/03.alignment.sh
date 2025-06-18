#!/usr/bin/env bash

# === Activate environment ====
eval "$(conda shell.bash hook)"
conda activate bsseq_env

# === Variable ==== 
SHARED_BASE="/ifs/groups/sacanGrp/kc3745/pipelines/bs_snp"
GENOME_DIR="/ifs/groups/sacanGrp/kc3745/pipelines/bs_snp/genome"
OUT_DIR=$SHARED_BASE/data/bam
mkdir -p $OUT_DIR
SRR_1=$SHARED_BASE/data/fastq/GSE210218/SRR20731213/SRR20731213_1.fastq
SRR_2=$SHARED_BASE/data/fastq/GSE210218/SRR20731213/SRR20731213_2.fastq

cd $OUT_DIR

# === Logging Setup ===
timestamp=$(date +"%m-%d-%Y_%H-%M-%S")
mkdir -p logs
LOG_FILE="logs/download_fastq_${timestamp}.log"
export LOG_FILE

# === Import Utility Functions ===
source $SHARED_BASE/utils.sh
message "Logger initialized" >> "$LOG_FILE" 2>&1

# GLOBAL VARIABLES
NTHREADS=$(nproc)
HALF_NTHREADS=$((NTHREADS / 2))
message "Total available threads: ${NTHREADS}"
message "Using ${HALF_NTHREADS}"

# === Alignment (e.g., Bismark) ===
message "Running alignment ... "
bismark --genome "$GENOME_DIR" \
        -1 "$SRR_1" \
        -2 "$SRR_2" \
        -o "$OUT_DIR" \
        --bowtie2 --multicore $HALF_NTHREADS >> "$LOG_FILE" 2>&1

message "Bismark alignment completed."