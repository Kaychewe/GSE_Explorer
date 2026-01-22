#!/bin/bash

set -e

usage() {
    cat <<'EOF'
Download FASTQs for SRR accessions listed in a run metadata CSV.

Usage:
  ./01.download_fastqs.sh --gseid GSE210218 --out /path/to/fastq
  ./01.download_fastqs.sh --csv ../metadata/GSE210218_run_metadata.csv --out /path/to/fastq

Options:
  --gseid <GSE_ID>         GEO series id (expects ../metadata/<GSE_ID>_run_metadata.csv)
  --csv <PATH>             Path to *_run_metadata.csv (overrides --gseid)
  --out <DIR>              Output directory for FASTQs (required)
  --tmp <DIR>              Temporary directory for fasterq-dump (default: <out>/.tmp_fasterq)
  --max-parallel <N>        Max concurrent downloads (default: 3)
  --threads <N>             Threads per fasterq-dump (default: 8)
  -h, --help               Show this help

Notes:
  - Activates conda env "bsseq_env" if conda is available.
  - The run metadata CSV is typically created by: ./gse_extract_metadata.sh <GSE_ID>
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_METADATA_DIR="${SCRIPT_DIR}/../metadata"

# Inputs
GSEID=""
CSV_FILE=""
OUT_DIR=""
TMP_DIR=""
MAX_PARALLEL=3
THREADS=8

while [[ $# -gt 0 ]]; do
    case "$1" in
        --gseid)
            GSEID="${2:-}"; shift 2;;
        --csv)
            CSV_FILE="${2:-}"; shift 2;;
        --out)
            OUT_DIR="${2:-}"; shift 2;;
        --tmp)
            TMP_DIR="${2:-}"; shift 2;;
        --max-parallel)
            MAX_PARALLEL="${2:-}"; shift 2;;
        --threads)
            THREADS="${2:-}"; shift 2;;
        -h|--help)
            usage; exit 0;;
        --)
            shift; break;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            exit 2;;
        *)
            if [[ -z "$CSV_FILE" ]]; then
                CSV_FILE="$1"
                shift
            else
                echo "Unexpected argument: $1" >&2
                usage
                exit 2
            fi
            ;;
    esac
done

if [[ -z "$CSV_FILE" && -n "$GSEID" ]]; then
    CSV_FILE="${DEFAULT_METADATA_DIR}/${GSEID}_run_metadata.csv"
fi

if [[ -z "$OUT_DIR" ]]; then
    echo "Missing required --out <DIR>" >&2
    usage
    exit 2
fi

if [[ -z "$CSV_FILE" ]]; then
    echo "Provide either --csv <PATH> or --gseid <GSE_ID>" >&2
    usage
    exit 2
fi

if [[ ! -f "$CSV_FILE" ]]; then
    echo "CSV file not found: $CSV_FILE" >&2
    if [[ -n "$GSEID" ]]; then
        echo "Tip: generate it with: (cd \"$SCRIPT_DIR\" && bash gse_extract_metadata.sh \"$GSEID\")" >&2
    fi
    exit 1
fi

if [[ -z "$TMP_DIR" ]]; then
    TMP_DIR="${OUT_DIR}/.tmp_fasterq"
fi

# Activate conda environment (if available)
if command -v conda >/dev/null 2>&1; then
    eval "$(conda shell.bash hook)"
    conda activate bsseq_env
fi

if ! command -v fasterq-dump >/dev/null 2>&1; then
    echo "fasterq-dump not found in PATH. Install sra-tools (or run scripts/setup.sh) and try again." >&2
    exit 1
fi

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
        --threads "$THREADS"

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
