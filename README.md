# GSE_Explorer
Utility scripts to fetch GEO/SRA run metadata and download FASTQs in a reproducible, parameterized way 

## Quickstart
```bash
git clone https://github.com/Kaychewe/GSE_Explorer.git
cd GSE_Explorer

# install Python deps + create conda env "bsseq_env"
bash scripts/setup.sh
```

## Requirements
- Bash + common Unix tools (`awk`, `sort`)
- Python 3.9+
- Conda/Miniconda
- `pysradb` (used by `scripts/gse_extract_metadata.sh`)
- One of:
  - SRA-Tools (`fasterq-dump`) for NCBI downloads, or
  - `curl`/`wget` for ENA downloads (HTTPS)

Install `pysradb` if you don’t already have it:
```bash
pip install pysradb
```

## Typical workflow
### 1) Extract run metadata from a GEO series (GSE → SRP → SRR list)
This writes a `*_run_metadata.csv` file.
```bash
bash scripts/gse_extract_metadata.sh --gseid GSE210218
```

To write metadata into a per-experiment folder:
```bash
bash scripts/gse_extract_metadata.sh --gseid GSE210218 --out "<EXPERIMENT_DIR>/metadata"
```

### 2) Download FASTQs for all SRRs in the metadata CSV
```bash
bash scripts/01.download_fastqs.sh --gseid GSE210218 --out "<EXPERIMENT_DIR>/fastq"
```

You can also pass a CSV directly:
```bash
bash scripts/01.download_fastqs.sh --csv "<EXPERIMENT_DIR>/metadata/GSE210218_run_metadata.csv" --out "<EXPERIMENT_DIR>/fastq"
```

### Download sources (NCBI vs ENA)
Some environments block plain HTTP or have strict TLS policies.

`scripts/01.download_fastqs.sh` supports:
- `--source sra` to use `fasterq-dump`
- `--source ena` to use ENA HTTPS URLs found in the metadata file
- `--source auto` (default) to try SRA first and fall back to ENA if needed

Example (force ENA):
```bash
bash scripts/01.download_fastqs.sh --csv "<..._run_metadata.csv>" --out "<FASTQ_DIR>" --source ena
```

## Logs
- `scripts/setup.sh` writes logs to `scripts/logs/`.
- `scripts/01.download_fastqs.sh` writes per-run logs under `--tmp/logs/`.
