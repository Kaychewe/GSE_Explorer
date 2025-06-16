#!/usr/bin/env python3

# file:         gpw.py (geo-parse-wrapper.py)
# author:       Kasonde Chewe 
# description:  A simple set of utility commands to use the NCBI geoparser module
# Note-to-self: Add caching to get_gse_data function for faster data reload 
# Note-to-self: How to handle SRA controlled data appropriately
# Basic workflow, get GSE from paper, fetch metadata, download raw fastq or aligned bams 

import os
import json
import argparse
import GEOparse
import logging
import pandas as pd
from pysradb.sraweb import SRAweb


DATA_DIR = "../data"
JSON_DIR = "../data/json"

def get_gse_data(geo_id: str, destdir: str = DATA_DIR):
    """
        Function to download and parse a GSE dataset
        Usage
        get_gse_data("GEO12345", "data")
    """
    os.makedirs(destdir, exist_ok=True)
    print(f"Downloading GEO series: {geo_id}")
    gse = GEOparse.get_GEO(geo=geo_id, destdir=destdir)
    return gse


def export_gsm_metadata_to_json(gse, json_dir: str = JSON_DIR):
    """
        # Function to extract and save GSM metadata as JSON files
        gse = get_gse_data("GSE123456")
        export_gsm_metadata_to_json(gse)

    """
    os.makedirs(json_dir, exist_ok=True)
    for gsm_id, gsm in gse.gsms.items():
        metadata = {k: v for k, v in gsm.metadata.items()}
        with open(os.path.join(json_dir, f"{gsm_id}.json"), "w") as f:
            json.dump(metadata, f, indent=4)
        print(f"Saved metadata for {gsm_id}")


def export_metadata_table(gse, output_csv: str = "../data/gse_metadata_summary.csv"):
    df = pd.DataFrame([
        {
            'GSM_ID': gsm_id,
            'SRX_ID': extract_srx_and_link(gsm)[0],
            'SRX_Link': extract_srx_and_link(gsm)[1],
            'SRR_ID': "; ".join(get_srr_from_srx_pysradb(extract_srx_and_link(gsm)[0]))
                        if extract_srx_and_link(gsm)[0] != "N/A" else "N/A",
            'title': gsm.metadata.get('title', [''])[0],
            'source': gsm.metadata.get('source_name_ch1', [''])[0],
            'type': "; ".join(gsm.metadata.get('characteristics_ch1', [])),
        }
        for gsm_id, gsm in gse.gsms.items()
    ])
    df.to_csv(output_csv, index=False)
    print(f"Exported metadata summary to {output_csv}")
    return df


def extract_srx_and_link(gsm):
    """
    Extract SRX ID and full SRA link from the 'relation' metadata field.
    Returns a tuple (SRX_ID, full_link) or ("N/A", "N/A") if not found.
    """
    for r in gsm.metadata.get('relation', []):
        if r.startswith("SRA:"):
            srx_url = r.split("SRA:")[1].strip()
            if "http" in srx_url:
                # Already full link (edge case)
                srx_id = srx_url.split("term=")[-1]
                return srx_id, srx_url
            else:
                srx_id = srx_url
                return srx_id, f"https://www.ncbi.nlm.nih.gov/sra?term={srx_id}"
    return "N/A", "N/A"


def get_srr_from_srx_pysradb(srx_id):
    """
    Given an SRX ID, return associated SRR IDs using pysradb metadata().
    """
    try:
        db = SRAweb()
        df = db.metadata(srx_id, detailed=True)
        if df.empty or 'run_accession' not in df.columns:
            print(f"⚠️ No SRR found for {srx_id}")
            return []
        return df['run_accession'].dropna().unique().tolist()
    except Exception as e:
        print(f"Error fetching SRR for {srx_id}: {e}")
        return []

