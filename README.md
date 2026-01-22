# GSE_Explorer
Utility scripts to fetch GEO/SRA run metadata, download FASTQs, and run a basic Bismark alignment.

## Quickstart
```bash
git clone https://github.com/Kaychewe/GSE_Explorer.git
cd GSE_Explorer

# install Python deps + create conda env "bsseq_env"
# (run from scripts/ due to relative paths used by setup.sh)
cd scripts
bash setup.sh
```

## Requirements
- Bash + common Unix tools (`awk`, `cut`, `sort`)
- Python 3.9+ (for Python utilities and `pysradb`)
- Conda/Miniconda (used for the `bsseq_env` environment)
- SRA-Tools (`fasterq-dump`) and aligner deps (installed by `scripts/setup.sh`)

Note: `scripts/gse_extract_metadata.sh` uses `pysradb`. Install it if you don’t already have it:
```bash
pip install pysradb
```

## Typical workflow
### 1) Extract run metadata from a GEO series (GSE → SRP → SRR list)
This writes a CSV file to `metadata/`.
```bash
cd scripts
bash gse_extract_metadata.sh GSE210218
# output: ../metadata/GSE210218_run_metadata.csv
```

### 2) Download FASTQs for all SRRs in the metadata CSV
```bash
cd scripts
bash 01.download_fastqs.sh ../metadata/GSE210218_run_metadata.csv
```

Important: `scripts/01.download_fastqs.sh` currently writes to hard-coded paths:
- `OUT_DIR="/mnt/f/research_drive/methylation/fastq"`
- `TMP_DIR="/mnt/f/tmp/fasterq"`

Edit those variables in the script to match your system before running.

### 3) Alignment example (Bismark)
`scripts/02.alignment.sh` is an example alignment run. It currently assumes:
- WSL + a Windows `F:` drive mount at `/mnt/f` (requires `sudo mount ...`)
- A local genome at `GENOME_DIR=~/genomes/hg38`
- A single sample hard-coded as `SRR20731213`

Edit `GENOME_DIR`, `INPUT_DIR`, `OUTPUT_DIR`, and the SRR filename(s) before running:
```bash
cd scripts
bash 02.alignment.sh
```

## Logs
`scripts/setup.sh` writes logs to `scripts/logs/`.
