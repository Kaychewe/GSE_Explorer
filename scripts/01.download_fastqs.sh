#!/bin/bash

# Usage: ./download_fastqs.sh metadata/GSE210218_run_metadata.csv
# Requires: fasterq-dump installed and accessible in PATH
# TODO: add command line menu
# TODO:

# Mount F: if needed
if ! mount | grep -q "/mnt/f"; then
    echo "📦 Mounting F: drive..."
    sudo mount -t drvfs F: /mnt/f
fi

# Inputs
CSV_FILE=$1
OUT_DIR="/mnt/f/Research_Drive/01.raw/01.methylation/fastq"
TMP_DIR="/mnt/f/tmp/fasterq"

mkdir -p "$OUT_DIR"
mkdir -p "$TMP_DIR"

echo "📥 Reading SRR accessions from $CSV_FILE..."

# Get unique SRRs
SRR_LIST=$(tail -n +2 "$CSV_FILE" | cut -d ',' -f1 | sort -u)

echo "🔽 Downloading FASTQs to $OUT_DIR (temporary storage in $TMP_DIR)"
for SRR in $SRR_LIST; do
    echo "➡️ Downloading $SRR ..."
    fasterq-dump "$SRR" \
        --split-files \
        -O "$OUT_DIR" \
        --temp "$TMP_DIR" \
        --progress \
        --threads 8

    if [ $? -eq 0 ]; then
        echo "✅ Successfully downloaded $SRR"
    else
        echo "❌ Failed to download $SRR"
    fi
done

echo "🧹 Cleaning up temporary files..."
rm -rf "$TMP_DIR"

echo "🎉 All downloads completed. FASTQs stored in: $OUT_DIR"
