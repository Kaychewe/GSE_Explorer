#!/bin/bash

# Example usage: ./extract_gse_metadata.sh GSE210218

set -e

GSE_ID=$1
OUT_DIR="../metadata"
OUT_FILE="${OUT_DIR}/${GSE_ID}_run_metadata.csv"

mkdir -p "$OUT_DIR"

echo "🔍 Converting GSE to SRP..."
SRP_ID=$(pysradb gse-to-srp $GSE_ID | awk 'NR==2 {print $2}')

if [ -z "$SRP_ID" ]; then
    echo "❌ No SRP found for $GSE_ID"
    exit 1
fi

echo "✅ Found SRP: $SRP_ID"

echo "📋 Fetching run metadata for $SRP_ID..."
pysradb metadata $SRP_ID --detailed --saveto "$OUT_FILE"

echo "✅ Metadata saved to $OUT_FILE"
