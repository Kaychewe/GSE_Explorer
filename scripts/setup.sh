#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
mkdir -p logs
LOG_FILE="logs/log_${timestamp}.txt"

message() {
    # Function for timestamp message
    echo "[$(date +"%m-%d-%Y %H:%M:%S")]: $1" | tee -a "$LOG_FILE"
}

# Start logging
message "Installing GEOparse and other requirements..."
pip install -r "${REPO_DIR}/requirements.txt" >> "$LOG_FILE" 2>&1

# Create conda environment
message "Creating conda env \"bsseq_env\" (bismark/bowtie2/samtools/sra-tools). See logs for stdout & stderr"
conda create -n bsseq_env -c bioconda bismark bowtie2 samtools sra-tools -y >> "$LOG_FILE" 2>&1

message "Setup completed."

message "Output saved to $LOG_FILE"
