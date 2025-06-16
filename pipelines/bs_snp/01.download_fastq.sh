#!/bin/bash
#SBATCH --job-name=bs_download
#SBATCH --output=logs/download_%j.out
#SBATCH --error=logs/download_%j.err
#SBATCH --time=02:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=4


# === Activate environment ===
eval "$(conda shell.bash hook)"
conda activate bsseq_env

# === Check-1: Are packages installed? ===



# === Setup Directories ===
SHARED_BASE="/ifs/groups/sacanGrp/kc3745/pipelines/bs_snp"
INPUT_FILE="input/metadata_input.txt"
LOG_FILE="$SHARED_BASE/logs/download_metadata.csv"
FASTQ_DIR="$SHARED_BASE/data/fastq"
mkdir -p "$FASTQ_DIR" logs

# === Write CSV Header if doesn't exist ===
# Use pysradb instead 



if [ ! -f "$LOG_FILE" ]; then
    echo "Sample_ID,SRR,Paired,Size_MB,Download_Time_sec,Output_Dir" > "$LOG_FILE"
fi

# === Process Each Entry ===
while read -r ID; do
    echo "🔍 Processing $ID"

    # Use pysradb to find SRR accessions
    SRRS=$(pysradb gse-to-srp $ID | tail -n +2 | awk '{print $2}' | xargs pysradb srp-to-srr | tail -n +2 | awk '{print $3}' | sort -u)

    for SRR in $SRRS; do
        START=$(date +%s)

        # Check layout (PE or SE)
        LAYOUT=$(pysradb metadata $SRR | grep "$SRR" | awk '{print $6}')
        [ "$LAYOUT" == "PAIRED" ] && PAIRED="yes" || PAIRED="no"

        # Download FASTQ
        fasterq-dump "$SRR" --split-files --threads 4 -O "$FASTQ_DIR"

        # Calculate file size
        SIZE=$(du -sm "$FASTQ_DIR/${SRR}"* | awk '{total+=$1} END{print total}')

        END=$(date +%s)
        TIME=$((END - START))

        # Log results
        echo "$ID,$SRR,$PAIRED,$SIZE,$TIME,$FASTQ_DIR" >> "$LOG_FILE"
        echo "✅ Finished $SRR — $SIZE MB in $TIME sec"
    done
done < "$INPUT_FILE"

echo "🎉 Download pipeline complete."
