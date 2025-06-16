#!/usr/bin/env bash
#SBATCH --job-name=bs_download
#SBATCH --output=logs/download_%j.out
#SBATCH --error=logs/download_%j.err
#SBATCH --time=02:00:00
#SBATCH --mem=16G
#SBATCH --cpus-per-task=4


# === Activate environment ===
eval "$(conda shell.bash hook)"
conda activate bsseq_env


# === Logging Setup ===
timestamp=$(date +"%m-%d-%Y_%H-%M-%S")
mkdir -p logs
LOG_FILE="logs/download_fastq_${timestamp}.log"
export LOG_FILE

# === Import Utility Functions ===
source utils.sh 
message "Logger initialized" #>> "$LOG_FILE" 2>&1


# === Check-1: Are required packages installed in the current conda environment ===
REQUIRED_PKGS="./pkgs.txt"
MISSING_PKGS=()

message "Checking installed conda packages..." #>> "$LOG_FILE" 2>&1
while IFS= read -r pkg || [[ -n "$pkg" ]]; do
    pkg=$(echo "$pkg" | xargs) 
    if [[ -z "$pkg" ]]; then
        continue  
    fi
    if conda list | awk '{print $1}' | grep -qx "$pkg"; then
        message "Package '$pkg' is installed." #>> "$LOG_FILE" 2>&1
    else
        message "Package '$pkg' is MISSING." #>> "$LOG_FILE" 2>&1
        MISSING_PKGS+=("$pkg")
    fi
done < "$REQUIRED_PKGS"

if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
    message "Missing packages: ${MISSING_PKGS[*]}" #>> "$LOG_FILE" 2>&1
    bash setup.sh --packages "${MISSING_PKGS[@]}"  #>> "$LOG_FILE" 2>&1

else
    message "All required packages are installed." #>> "$LOG_FILE" 2>&1
fi


# === Setup Directories ===
# SHARED_BASE="/ifs/groups/sacanGrp/kc3745/pipelines/bs_snp" # Uncomment this line for actual environment setup
SHARED_BASE="."  
GSE_FILE="gse.txt"  


mkdir -p "$SHARED_BASE/metadata"
FASTQ_DIR="$SHARED_BASE/data/fastq"
mkdir -p "$FASTQ_DIR" logs
message "Starting GSE-to-SRR metadata extraction using pysradb" #>> "$LOG_FILE" 2>&1

# === Extract metadata for each GSE ===
while IFS= read -r GSE || [[ -n "$GSE" ]]; do
    GSE=$(echo "$GSE" | xargs)  # Trim any leading/trailing spaces from GSE ID
    if [[ -z "$GSE" ]]; then
        continue  # Skip empty lines in GSE file
    fi
    message "Querying metadata for $GSE" #>> "$LOG_FILE" 2>&1
    
    SRP=$(pysradb gse-to-srp "$GSE" | awk 'NR==2 {print $2}')
    message "Found study accession $SRP for $GSE"
    pysradb metadata "$SRP" --desc --expand > "$SHARED_BASE/metadata/${GSE}_run_metadata.tsv"

    if [[ -s "$SHARED_BASE/metadata/${GSE}_run_metadata.csv" ]]; then
        message "Saved metadata to $SHARED_BASE/metadata/${GSE}_run_metadata.tsv"
    else
        message "Metadata file for $GSE is empty or failed."
    fi
done < "$GSE_FILE"


# === Download FASTQ RAW Data for each GSE ===
message "Starting FASTQ download step..."

NTHREADS=$(nproc --ignore=2)
TMP_DIR="$SHARED_BASE/tmp"
mkdir -p "$TMP_DIR"

for metadata_tsv in "$SHARED_BASE/metadata/"*_run_metadata.tsv; do
    GSE=$(basename "$metadata_tsv" | cut -d'_' -f1)
    message "Processing metadata file: $metadata_tsv"

    SRR_LIST=$(awk -F'\t' 'NR > 1 {print $22}' "$metadata_tsv" | sort -u)

    for SRR in $SRR_LIST; do
        if [[ -z "$SRR" ]]; then
            continue
        fi

        OUT_DIR="$FASTQ_DIR/$GSE/$SRR"
        mkdir -p "$OUT_DIR"

        message "Downloading $SRR to $OUT_DIR"
        START_TIME=$(date +%s)

        fasterq-dump "$SRR" \
            --split-files \
            -O "$OUT_DIR" \
            --temp "$TMP_DIR" \
            --threads $NTHREADS >> "$LOG_FILE" 2>&1

        END_TIME=$(date +%s)
        RUNTIME=$((END_TIME - START_TIME))

        if [[ -f "$OUT_DIR/${SRR}_1.fastq" || -f "$OUT_DIR/${SRR}_1.fastq.gz" ]]; then
            message "Completed download for $SRR in $RUNTIME seconds"
        else
            message "Failed to download $SRR"
        fi
    done
done






# # if [ ! -f "$LOG_FILE" ]; then
# #     echo "Sample_ID,SRR,Paired,Size_MB,Download_Time_sec,Output_Dir" > "$LOG_FILE"
# # fi

# # # === Process Each Entry ===
# # while read -r ID; do
# #     echo "🔍 Processing $ID"

# #     # Use pysradb to find SRR accessions
# #     SRRS=$(pysradb gse-to-srp $ID | tail -n +2 | awk '{print $2}' | xargs pysradb srp-to-srr | tail -n +2 | awk '{print $3}' | sort -u)

# #     for SRR in $SRRS; do
# #         START=$(date +%s)

# #         # Check layout (PE or SE)
# #         LAYOUT=$(pysradb metadata $SRR | grep "$SRR" | awk '{print $6}')
# #         [ "$LAYOUT" == "PAIRED" ] && PAIRED="yes" || PAIRED="no"

# #         # Download FASTQ
# #         fasterq-dump "$SRR" --split-files --threads 4 -O "$FASTQ_DIR"

# #         # Calculate file size
# #         SIZE=$(du -sm "$FASTQ_DIR/${SRR}"* | awk '{total+=$1} END{print total}')

# #         END=$(date +%s)
# #         TIME=$((END - START))

# #         # Log results
# #         echo "$ID,$SRR,$PAIRED,$SIZE,$TIME,$FASTQ_DIR" >> "$LOG_FILE"
# #         echo "✅ Finished $SRR — $SIZE MB in $TIME sec"
# #     done
# # done < "$INPUT_FILE"

# # echo "🎉 Download pipeline complete."
