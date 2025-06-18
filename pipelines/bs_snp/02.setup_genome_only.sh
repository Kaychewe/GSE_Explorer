#!/usr/bin/env bash
#SBATCH --job-name=genome_setup
#SBATCH --output=logs/genome_setup_%j.out
#SBATCH --error=logs/genome_setup_%j.err

# === Activate environment ===
eval "$(conda shell.bash hook)"
conda activate bsseq_env

# === Logging Setup ===
timestamp=$(date +"%m-%d-%Y_%H-%M-%S")
mkdir -p logs
LOG_FILE="logs/genome_setup_${timestamp}.log"
export LOG_FILE

# === Import Utility Functions ===
source utils.sh
message "Logger initialized" >> "$LOG_FILE" 2>&1

# === Check for indexed genome ===
SHARED_BASE="/ifs/groups/sacanGrp/kc3745/pipelines/bs_snp"
GENOME_INDEX_DIR="$SHARED_BASE/genome"
GENOME_INDEX_PREFIX="$GENOME_INDEX_DIR/genome.fa"

if [[ ! -f "${GENOME_INDEX_PREFIX}.bismark.bt2" && ! -f "${GENOME_INDEX_PREFIX}.bismark.bwt2.bt2" ]]; then
    message "No Bismark-indexed genome found at $GENOME_INDEX_PREFIX. Running setup..." >> "$LOG_FILE" 2>&1
    bash bs_download.sh --only-genome >> "$LOG_FILE" 2>&1
else
    message "Indexed genome already exists at $GENOME_INDEX_DIR. Skipping download." >> "$LOG_FILE" 2>&1
fi
