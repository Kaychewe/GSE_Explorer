#!/bin/bash
# file: setup.sh
# author: Kasonde Chewe
# date: 6/16/2025

# === Parse Arguments ===
PACKAGES=()

while [[ "$#" -gt 0 ]]; do
    case $1 in
        -p|--packages) shift; IFS=',' read -ra PACKAGES <<< "$1" ;;
        *) echo "Unknown parameter passed: $1"; exit 1 ;;
    esac
    shift
done

# === Timestamped Log Setup ===
timestamp=$(date +"%m-%d-%Y_%H-%M-%S")
mkdir -p logs
LOG_FILE="logs/log_${timestamp}.txt"

# === Import Utility Functions ===
source ./utils.sh

message "Setup started"

# === Install Python Packages from requirements.txt ===
if [[ -f requirements.txt ]]; then
    message "📦 Installing Python packages from requirements.txt"
    pip install -r requirements.txt >> "$LOG_FILE" 2>&1
else
    message "⚠️ requirements.txt not found"
fi

# === Create Conda Environment and Core Tools ===
ENV_NAME="bsseq_env"
message "🐍 Creating conda environment: $ENV_NAME"
conda create -n "$ENV_NAME" -c bioconda bismark bowtie2 samtools sra-tools -y >> "$LOG_FILE" 2>&1

# === Install Any Extra Packages Passed via CLI ===
if [[ ${#PACKAGES[@]} -gt 0 ]]; then
    message "➕ Installing additional packages: ${PACKAGES[*]}"
    conda activate "$ENV_NAME"
    for pkg in "${PACKAGES[@]}"; do
        conda install -c bioconda "$pkg" -y >> "$LOG_FILE" 2>&1
    done
fi

message "✅ Setup completed"
message "📄 Log saved to: $LOG_FILE"
