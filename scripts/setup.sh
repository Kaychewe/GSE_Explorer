#!/bin/bash

timestamp=$(date +"%m-%d-%Y %H:%M:%S")
mkdir -p logs
LOG_FILE="logs/log_${timestamp}.txt"

message() {
    # Function for timestamp message
    echo "[$(date +"%m-%d-%Y %H:%M:%S")]: $1" | tee -a "$LOG_FILE"
}

# Start logging
message "Installing GEOparse and other requirements..."
pip install -r ./../requirements.txt >> "$LOG_FILE" 2>&1

# Create conda environment
message "Creating conda env "bsseq_env". See logs for stdout & stderr"
conda create -n bsseq_env -c bioconda bismark bowtie2 samtools -y >> "$LOG_FILE" 2>&1

message "Installing SRA-Tools..."
conda install -c bioconda sra-tools -y >> "$LOG_FILE" 2>&1
message "Setup completed."

message "Output saved to $LOG_FILE"