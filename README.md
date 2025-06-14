# GSE_Explorer
Utility scripts to download sequencing metadata, raw and processed files


## Requirements
- Python 3.9+
- Conda or miniconda 
- GEOparse (see `requirements.txt`)
- SRA-tools (install with `conda install -c bioconda sra-tools` or system package manager)


1. Install Instructions
A bash script is provided to install all required tools for `GSE_Explorer`


Run the /scripts/setup.sh script command below 

```{bash}
# clone repository
git clone https://github.com/Kaychewe/GSE_Explorer.git
cd GSE_Explorer
cd scripts 
bash setup.sh
```