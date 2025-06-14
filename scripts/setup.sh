#!/bin/bash

timestamp=$(date +"%m-%d-%Y %H:%M:%S")
mkdir -p logs
LOG_FILE="logs/log.txt"

message() {
    # Function for timestamp message
    echo "[$(date +"%m-%d-%Y %H:%M:%S")]: $1" | tee -a "$LOG_FILE"
}

# Start logging
message "Installing GEOparse and other requirements..."
pip install -r ./../requirements.txt >> "$LOG_FILE" 2>&1

message "Installing SRA-Tools..."
conda install -c bioconda sra-tools -y >> "$LOG_FILE" 2>&1

message "Setup completed."