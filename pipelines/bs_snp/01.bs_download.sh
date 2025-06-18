#!/usr/bin/env bash
# file: 01.bs_download.sh

#SBATCH --job-name=bs_download
#SBATCH --output=logs/download_%j.out
#SBATCH --error=logs/download_%j.err


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
message "Logger initialized" >> "$LOG_FILE" 2>&1
# GLOBAL VARIABLES
NTHREADS=$(nproc)
HALF_NTHREADS=$((NTHREADS / 2))
message "Total available threads: ${NTHREADS}"
message "Using ${HALF_NTHREADS}"

# === Parse command line arguments ===
TEST_MODE=0

while getopts ":t" opt; do
  case $opt in
    t)
      TEST_MODE=1
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done


# STEP-1
# === Check-1: Are required packages installed in the current conda environment ===
REQUIRED_PKGS="./pkgs.txt"
MISSING_PKGS=()

message "Checking installed conda packages..." >> "$LOG_FILE" 2>&1
while IFS= read -r pkg || [[ -n "$pkg" ]]; do
    pkg=$(echo "$pkg" | xargs) 
    if [[ -z "$pkg" ]]; then
        continue  
    fi
    if conda list | awk '{print $1}' | grep -qx "$pkg"; then
        message "Package '$pkg' is installed." >> "$LOG_FILE" 2>&1
    else
        message "Package '$pkg' is MISSING." >> "$LOG_FILE" 2>&1
        MISSING_PKGS+=("$pkg")
    fi
done < "$REQUIRED_PKGS"

if [ ${#MISSING_PKGS[@]} -ne 0 ]; then
    message "Missing packages: ${MISSING_PKGS[*]}" >> "$LOG_FILE" 2>&1
    bash setup.sh --packages "${MISSING_PKGS[@]}"  >> "$LOG_FILE" 2>&1

else
    message "All required packages are installed." >> "$LOG_FILE" 2>&1
fi

# STEP-2
# === Setup Directories ===
SHARED_BASE="/ifs/groups/sacanGrp/kc3745/pipelines/bs_snp" 
GSE_FILE="gse.txt"  

mkdir -p "$SHARED_BASE/metadata"
FASTQ_DIR="$SHARED_BASE/data/fastq"
mkdir -p "$FASTQ_DIR" logs
message "Starting GSE-to-SRR metadata extraction using pysradb" >> "$LOG_FILE" 2>&1

# === Extract metadata for each GSE ===
while IFS= read -r GSE || [[ -n "$GSE" ]]; do
    GSE=$(echo "$GSE" | xargs)  # Trim any leading/trailing spaces from GSE ID
    if [[ -z "$GSE" ]]; then
        continue  # Skip empty lines in GSE file
    fi
    message "Querying metadata for $GSE" >> "$LOG_FILE" 2>&1
    SRP=$(pysradb gse-to-srp "$GSE" | awk 'NR==2 {print $2}')
    message "Found study accession $SRP for $GSE"
    pysradb metadata "$SRP" --desc --expand > "$SHARED_BASE/metadata/${GSE}_run_metadata.tsv"

    if [[ -s "$SHARED_BASE/metadata/${GSE}_run_metadata.tsv" ]]; then
        message "Saved metadata to $SHARED_BASE/metadata/${GSE}_run_metadata.tsv"
    else
        message "Metadata file for $GSE is empty or failed."
    fi
done < "$GSE_FILE"

# STEP-3
# === Launch genome indexing in background if not yet prepared ===
message "Launching genome setup in background (if needed)..." >> "$LOG_FILE" 2>&1

GENOME_SETUP_LOG="logs/genome_setup_${timestamp}.log"
message "Running genome setup script synchronously..."
bash genome_setup.sh >> "$GENOME_SETUP_LOG" 2>&1

if [[ $? -eq 0 ]]; then
    message "Genome setup completed successfully."
else
    message "Genome setup failed. Check $GENOME_SETUP_LOG for details."
    exit 1
fi



# STEP-4
# === Download FASTQ RAW Data for each GSE ===
message "Starting FASTQ download step..."
TMP_DIR="$SHARED_BASE/tmp"
mkdir -p "$TMP_DIR"


for metadata_tsv in "$SHARED_BASE/metadata/"*_run_metadata.tsv; do
    GSE=$(basename "$metadata_tsv" | cut -d'_' -f1)
    message "Processing metadata file: $metadata_tsv"

    SRR_LIST=$(awk -F'\t' 'NR > 1 {print $22}' "$metadata_tsv" | sort -u)

    for SRR in $SRR_LIST; do
        [[ -z "$SRR" ]] && continue

        OUT_DIR="$FASTQ_DIR/$GSE/$SRR"
        mkdir -p "$OUT_DIR"

        # === Detect layout: SINGLE or PAIRED ===
        LAYOUT=$(awk -F'\t' -v srr="$SRR" '$22 == srr {print $13}' "$metadata_tsv" | head -n 1)
        IS_PAIRED=0
        [[ "$LAYOUT" == "PAIRED" ]] && IS_PAIRED=1

        message "Downloading $SRR ($LAYOUT) to $OUT_DIR"
        START_TIME=$(date +%s)

        # === Download FASTQ(s) ===
        fasterq-dump "$SRR" \
            --split-files \
            -O "$OUT_DIR" \
            --temp "$TMP_DIR" \
            --verbose \
            --progress \
            --threads $HALF_NTHREADS >> "$LOG_FILE" 2>&1

        END_TIME=$(date +%s)
        RUNTIME=$((END_TIME - START_TIME))

        # # === Check-3 successful download ===
        # TODO: flags might not be the best here. Resolve path as check instead..
        # IDEA: save file paths to csv and run directly from there (if array length is 2 per line it is paired and if len 1 it is single end assume paired for now)
        # if [[ $IS_PAIRED -eq 1 && -f "$OUT_DIR/${SRR}_1.fastq" && -f "$OUT_DIR/${SRR}_2.fastq" ]] || \
        #    [[ $IS_PAIRED -eq 0 && -f "$OUT_DIR/${SRR}.fastq" ]]; then
        #     message "Completed download for $SRR in $RUNTIME seconds"
        # else
        #     message "Failed to download $SRR"
        #     continue
        # fi

        # # === Run FASTQC ===
        # message "Running FastQC on $SRR"
        # if [[ $IS_PAIRED -eq 1 ]]; then
        #     fastqc "$OUT_DIR/${SRR}_1.fastq" "$OUT_DIR/${SRR}_2.fastq" -o "$OUT_DIR" >> "$LOG_FILE" 2>&1
        # else
        #     fastqc "$OUT_DIR/${SRR}.fastq" -o "$OUT_DIR" >> "$LOG_FILE" 2>&1
        # fi

        # # === Alignment (e.g., Bismark) ===
        # message "Running alignment for $SRR"
        # if [[ $IS_PAIRED -eq 1 ]]; then
        #     bismark --genome "$GENOME_DIR" \
        #         -1 "$OUT_DIR/${SRR}_1.fastq" \
        #         -2 "$OUT_DIR/${SRR}_2.fastq" \
        #         -o "$OUT_DIR" \
        #         --bowtie2 --multicore $HALF_NTHREADS >> "$LOG_FILE" 2>&1
        # else
        #     bismark --genome "$GENOME_DIR" \
        #         "$OUT_DIR/${SRR}.fastq" \
        #         -o "$OUT_DIR" \
        #         --bowtie2 --multicore $HALF_NTHREADS >> "$LOG_FILE" 2>&1
        # fi

        # # === Clean up ===
        # TODO be careful
        # message "Cleaning up FASTQ and temp files for $SRR"
        # rm -f "$OUT_DIR/"*.fastq
        # rm -rf "$TMP_DIR"/*

        # === Exit immediately if in test mode ===
        if [[ $TEST_MODE -eq 1 ]]; then
            message "Test mode enabled. Completed first SRR ($SRR). Exiting early."
            exit 0
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
