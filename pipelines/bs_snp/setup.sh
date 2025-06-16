#!/usr/bin/env bash
# file: setup.sh
# date: 06-16-2025

timestamp=$(date +"%m-%d-%Y_%H-%M-%S")
mkdir -p logs
LOG_FILE="logs/setup_${timestamp}.log"
export LOG_FILE

# === Import helper ===
source utils.sh
message "setup.sh started..." #>> "$LOG_FILE" 2>&1

# === Parse command-line packages ===
PACKAGES_TO_INSTALL=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        -p|--packages)
            shift
            while [[ $# -gt 0 && ! "$1" =~ ^- ]]; do
                PACKAGES_TO_INSTALL+=("$1")
                shift
            done
            ;;
        *)
            shift
            ;;
    esac
done

# === Install packages ===
if [ ${#PACKAGES_TO_INSTALL[@]} -eq 0 ]; then
    message "No packages provided to setup.sh. Exiting." #>> "$LOG_FILE" 2>&1
    exit 0
fi

message "Installing packages: ${PACKAGES_TO_INSTALL[*]}" #>> "$LOG_FILE" 2>&1

for pkg in "${PACKAGES_TO_INSTALL[@]}"; do
    conda install -y -c bioconda "$pkg" #>> "$LOG_FILE" 2>&1 || \
    conda install -y -c conda-forge "$pkg" #>> "$LOG_FILE" 2>&1

    if conda list | awk '{print $1}' | grep -qx "$pkg"; then
        message "Successfully installed $pkg." #>> "$LOG_FILE" 2>&1
    else
        message "FAILED to install $pkg." #>> "$LOG_FILE" 2>&1
    fi
done

message "setup.sh completed." #>> "$LOG_FILE" 2>&1
message "saving environment to YML"
conda env export > environment.yml