#!/bin/bash

set -euo pipefail

usage() {
    cat <<'EOF'
Fetch run metadata for a GEO series (GSE) and write a *_run_metadata.csv file.

Usage:
  ./gse_extract_metadata.sh GSE210218
  ./gse_extract_metadata.sh --gseid GSE210218
  ./gse_extract_metadata.sh --gseid GSE210218 --out /path/to/metadata_dir

Options:
  --gseid <GSE_ID>     GEO series id (required unless provided as positional arg)
  --out <DIR>          Output directory for CSV (default: ../metadata)
  --force              Overwrite existing CSV
  -h, --help           Show this help

Output:
  <out>/<GSE_ID>_run_metadata.csv

Dependencies:
  - pysradb (CLI): pip install pysradb
EOF
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

GSE_ID=""
OUT_DIR="${SCRIPT_DIR}/../metadata"
FORCE=0

if [[ $# -ge 1 && "${1:-}" != "-"* ]]; then
    GSE_ID="$1"
    shift
fi

while [[ $# -gt 0 ]]; do
    case "$1" in
        --gseid)
            GSE_ID="${2:-}"; shift 2;;
        --out)
            OUT_DIR="${2:-}"; shift 2;;
        --force)
            FORCE=1; shift;;
        -h|--help)
            usage; exit 0;;
        -*)
            echo "Unknown option: $1" >&2
            usage
            exit 2;;
        *)
            echo "Unexpected argument: $1" >&2
            usage
            exit 2;;
    esac
done

if [[ -z "$GSE_ID" ]]; then
    echo "Missing GSE id. Provide a positional GSE (e.g. GSE210218) or --gseid." >&2
    usage
    exit 2
fi

if ! command -v pysradb >/dev/null 2>&1; then
    echo "pysradb not found in PATH. Install it with: pip install pysradb" >&2
    exit 1
fi

OUT_FILE="${OUT_DIR}/${GSE_ID}_run_metadata.csv"

mkdir -p "$OUT_DIR"

if [[ -f "$OUT_FILE" && "$FORCE" -ne 1 ]]; then
    echo "Metadata already exists: $OUT_FILE (use --force to overwrite)"
    exit 0
fi

echo "🔍 Converting GSE to SRP..."
SRP_ID="$(pysradb gse-to-srp "$GSE_ID" | awk 'NR==2 {print $2}')"

if [ -z "$SRP_ID" ]; then
    echo "[ERROR ❌]: No SRP found for $GSE_ID"
    exit 1
fi

echo "[SUCCESS ✅]: Found SRP: $SRP_ID"

echo "📋 Fetching run metadata for $SRP_ID..."
rm -f "${OUT_FILE}.tmp" 2>/dev/null || true
pysradb metadata "$SRP_ID" --detailed --saveto "${OUT_FILE}.tmp"
mv -f "${OUT_FILE}.tmp" "$OUT_FILE"

echo "[SUCCESS ✅]: Metadata saved to $OUT_FILE"
