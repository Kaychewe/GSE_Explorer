#!/usr/bin/env bash
# file: genome_setup.sh
# TODO: do not delete the genome. bismark needs to find a .fa file

GENOME_DIR="/ifs/groups/sacanGrp/kc3745/pipelines/bs_snp/genome"
GENOME_FASTA="$GENOME_DIR/genome.fa"
GENOME_FASTA_GZ="$GENOME_DIR/genome.fa.gz"
GENOME_INDEX_CHECK="$GENOME_DIR/Bisulfite_Genome"
NTHREADS=$(nproc)
HALF_THREADS=$((NTHREADS / 2))

mkdir -p "$GENOME_DIR"

if [[ ! -d "$GENOME_INDEX_CHECK" || -z "$(ls -A "$GENOME_INDEX_CHECK" 2>/dev/null)" ]]; then
    echo "[INFO] No Bismark index found. Preparing reference..."
    
    if [[ ! -f "$GENOME_FASTA" ]]; then
        if [[ ! -f "$GENOME_FASTA_GZ" ]]; then
            echo "[INFO] Downloading genome FASTA..."
            wget -O "$GENOME_FASTA_GZ" http://hgdownload.soe.ucsc.edu/goldenPath/hg38/bigZips/hg38.fa.gz
        fi
        echo "[INFO] Decompressing genome FASTA..."
        gunzip -f "$GENOME_FASTA_GZ"
    fi

    echo "[INFO] Running bismark_genome_preparation with $HALF_THREADS threads..."
    bismark_genome_preparation --verbose --parallel "$HALF_THREADS" "$GENOME_DIR"

    echo "[INFO] Cleaning up FASTA..."
    rm -f "$GENOME_FASTA"
    
    echo "[INFO] Genome indexing complete."
else
    echo "[INFO] Genome already indexed. Skipping."
fi

