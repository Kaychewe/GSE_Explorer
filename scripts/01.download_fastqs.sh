#!/bin/bash

# Usage: ./01.download_fastqs.sh ../metadata/GSE210218_run_metadata.csv

# Activate conda environment 
eval "$(conda shell.bash hook)"
conda activate bsseq_env

# Inputs
CSV_FILE=$1
OUT_DIR="/mnt/f/research_drive/methylation/fastq"
TMP_DIR="/mnt/f/tmp/fasterq"
MAX_PARALLEL=3  # Adjust this based on your system resources

mkdir -p "$OUT_DIR"
mkdir -p "$TMP_DIR"

echo "📥 Reading SRR accessions from $CSV_FILE..."

# Get unique SRRs
SRR_LIST=$(tail -n +2 "$CSV_FILE" | cut -d ',' -f1 | sort -u)

echo "🔽 Downloading FASTQs to $OUT_DIR (temporary storage in $TMP_DIR)"

download_srr() {
    SRR=$1
    echo "➡️ Downloading $SRR ..."
    fasterq-dump "$SRR" \
        --split-files \
        -O "$OUT_DIR" \
        --temp "$TMP_DIR" \
        --threads 8

    if [ $? -eq 0 ]; then
        echo "✅ Successfully downloaded $SRR"
    else
        echo "❌ Failed to download $SRR"
    fi
}

export OUT_DIR TMP_DIR
export -f download_srr

# Use GNU parallel if available
if command -v parallel &>/dev/null; then
    echo "🚀 Running downloads in parallel using GNU parallel..."
    echo "$SRR_LIST" | tr ' ' '\n' | parallel -j "$MAX_PARALLEL" download_srr
else
    echo "⚠️ GNU parallel not found. Falling back to background jobs..."

    JOBS=0
    for SRR in $SRR_LIST; do
        download_srr "$SRR" &
        ((JOBS++))
        if [ "$JOBS" -ge "$MAX_PARALLEL" ]; then
            wait
            JOBS=0
        fi
    done
    wait
fi

# echo "🧹 Cleaning up temporary files..."
# rm -rf "$TMP_DIR"

echo "✅ All downloads completed. FASTQs stored in: $OUT_DIR"
