#!/bin/bash
# Major updates 
# Enhanced command-line interface 
# Enabled multi-threading (still needs testing)
# [PLANNED]: downloader for EGA, ENCODE 
# [PLANNED]: get experimental metadata for complimentary analysis 
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
  --source <auto|sra|ena>  Download via sra-tools (fasterq-dump) or ENA URLs in metadata (default: auto)
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
SOURCE="auto"

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
        --source)
            SOURCE="${2:-}"; shift 2;;
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

mkdir -p "$OUT_DIR"
mkdir -p "$TMP_DIR"

echo "📥 Reading SRR accessions from $CSV_FILE..."

# Get unique SRRs (robust to CSV/TSV and to pysradb output variations)
mapfile -t SRRS < <(LC_ALL=C grep -Eo 'SRR[0-9]{6,}' "$CSV_FILE" | sort -u)
if [[ ${#SRRS[@]} -eq 0 ]]; then
    echo "❌ No SRR accessions found in: $CSV_FILE" >&2
    exit 1
fi

echo "🔽 Downloading FASTQs to $OUT_DIR (temporary storage in $TMP_DIR)"

LOG_DIR="${TMP_DIR}/logs"
mkdir -p "$LOG_DIR"

# Create a lookup table of ENA URLs (if present in the metadata file).
ENA_MAP_FILE="${TMP_DIR}/ena_urls.tsv"
python - "$CSV_FILE" >"$ENA_MAP_FILE" <<'PY'
import csv
import sys

path = sys.argv[1]
with open(path, "r", newline="") as f:
    first = f.readline()
    f.seek(0)
    dialect = csv.excel_tab if "\t" in first else csv.excel
    reader = csv.DictReader(f, dialect=dialect)
    for row in reader:
        srr = (row.get("run_accession") or "").strip()
        if not srr:
            continue
        def get(key: str) -> str:
            return (row.get(key) or "").strip()

        def normalize(url: str) -> str:
            if not url:
                return ""
            # Some HPCs block plain HTTP (port 80); ENA supports HTTPS.
            if url.startswith("http://"):
                return "https://" + url[len("http://") :]
            return url

        def pick_http(*keys: str) -> str:
            for k in keys:
                v = get(k)
                if v.startswith("http://") or v.startswith("https://"):
                    return normalize(v)
            return ""

        url1 = pick_http("ena_fastq_http_1", "ena_fastq_ftp_1", "ena_fastq_http", "ena_fastq_ftp")
        url2 = pick_http("ena_fastq_http_2", "ena_fastq_ftp_2")
        sys.stdout.write(f"{srr}\t{url1}\t{url2}\n")
PY

normalize_url() {
    # Prefer HTTPS for ENA/SRA endpoints (HPC often blocks plain HTTP).
    local url="$1"
    if [[ "$url" == http://* ]]; then
        printf '%s\n' "https://${url#http://}"
    else
        printf '%s\n' "$url"
    fi
}

download_ena() {
    local srr="$1"
    local line url1 url2 dest1 dest2

    line="$(awk -F'\t' -v s="$srr" '$1==s{print;exit}' "$ENA_MAP_FILE")"
    url1="$(printf '%s' "$line" | awk -F'\t' '{print $2}')"
    url2="$(printf '%s' "$line" | awk -F'\t' '{print $3}')"
    url1="$(normalize_url "${url1:-}")"
    url2="$(normalize_url "${url2:-}")"

    if [[ -z "${url1:-}" ]]; then
        echo "❌ No ENA URL found for $srr in $ENA_MAP_FILE" >&2
        return 1
    fi

    if command -v curl >/dev/null 2>&1; then
        dest1="${OUT_DIR}/$(basename "$url1")"
        curl -L --fail --retry 5 --retry-connrefused --connect-timeout 30 --max-time 0 -C - -o "$dest1" "$url1"
        if [[ -n "${url2:-}" ]]; then
            dest2="${OUT_DIR}/$(basename "$url2")"
            curl -L --fail --retry 5 --retry-connrefused --connect-timeout 30 --max-time 0 -C - -o "$dest2" "$url2"
        fi
    elif command -v wget >/dev/null 2>&1; then
        dest1="${OUT_DIR}/$(basename "$url1")"
        wget -O "$dest1" -c "$url1"
        if [[ -n "${url2:-}" ]]; then
            dest2="${OUT_DIR}/$(basename "$url2")"
            wget -O "$dest2" -c "$url2"
        fi
    else
        echo "❌ Neither curl nor wget found; cannot download ENA FASTQs." >&2
        return 1
    fi
}

have_fastq_output() {
    local srr="$1"
    local found=0
    shopt -s nullglob
    for f in "${OUT_DIR}/${srr}"*.fastq "${OUT_DIR}/${srr}"*.fastq.gz; do
        if [[ -s "$f" ]]; then
            found=1
            break
        fi
    done
    shopt -u nullglob
    [[ "$found" -eq 1 ]]
}

download_srr() {
    SRR=$1
    echo "➡️ Downloading $SRR ..."

    case "$SOURCE" in
        auto|sra|ena) ;;
        *)
            echo "❌ Invalid --source: $SOURCE (expected auto|sra|ena)" >&2
            return 2;;
    esac

    if [[ "$SOURCE" == "ena" ]]; then
        if download_ena "$SRR" >>"${LOG_DIR}/${SRR}.ena.log" 2>&1; then
            echo "✅ Downloaded (ENA) $SRR"
            return 0
        fi
        echo "❌ Failed (ENA) $SRR"
        return 1
    fi

    if ! command -v fasterq-dump >/dev/null 2>&1; then
        echo "❌ fasterq-dump not found in PATH. Install sra-tools (or run scripts/setup.sh)." >&2
        return 1
    fi

    if fasterq-dump "$SRR" \
        --split-files \
        -O "$OUT_DIR" \
        --temp "$TMP_DIR" \
        --threads "$THREADS" >>"${LOG_DIR}/${SRR}.fasterq.log" 2>&1; then
        if have_fastq_output "$SRR"; then
            echo "✅ Downloaded (SRA) $SRR"
            return 0
        fi
        echo "❌ No FASTQ output produced for $SRR (see ${LOG_DIR}/${SRR}.fasterq.log)" >&2
    else
        echo "❌ Failed (SRA) $SRR (see ${LOG_DIR}/${SRR}.fasterq.log)" >&2
    fi

    if [[ "$SOURCE" == "auto" ]]; then
        echo "↪ Falling back to ENA for $SRR ..."
        if download_ena "$SRR" >>"${LOG_DIR}/${SRR}.ena.log" 2>&1; then
            echo "✅ Downloaded (ENA) $SRR"
            return 0
        fi
        echo "❌ Failed (ENA) $SRR (see ${LOG_DIR}/${SRR}.ena.log)" >&2
    fi
    return 1
}

export OUT_DIR TMP_DIR
export THREADS
export SOURCE ENA_MAP_FILE LOG_DIR
export -f download_srr
export -f download_ena have_fastq_output normalize_url

# Use GNU parallel if available
if command -v parallel &>/dev/null; then
    # Silence GNU Parallel's citation notice without interactive prompts.
    export PARALLEL_HOME="${TMP_DIR}/.parallel"
    mkdir -p "$PARALLEL_HOME" >/dev/null 2>&1 || true
    : >"${PARALLEL_HOME}/will-cite" 2>/dev/null || true

    echo "🚀 Running downloads in parallel using GNU parallel..."
    PARALLEL_ARGS=(-j "$MAX_PARALLEL")
    if parallel --will-cite --help >/dev/null 2>&1; then
        PARALLEL_ARGS=(--will-cite "${PARALLEL_ARGS[@]}")
    fi
    printf '%s\n' "${SRRS[@]}" | parallel "${PARALLEL_ARGS[@]}" download_srr
else
    echo "⚠️ GNU parallel not found. Falling back to background jobs..."

    JOBS=0
    for SRR in "${SRRS[@]}"; do
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
