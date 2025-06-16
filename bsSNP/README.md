
## TODO LIST 
PIPELINE 1 
(Review methods section)

- setup pipeline 
    - download data (1 file at a time) and then run through (pysradb)
        - from .txt file read convert GSE and GSM to SRP and extract SRR <- save data input.txt
        - check if file is pair-ended or single end (log) 
        - log file size and download speed 
        - save metadata to csv 
    - check if genome aviabile 
        - if not download hg38 or paper genome 
        - index using bismark or similar 
        - note directory path to genome
        - delete genome (keep only index files and keep in local drive max 64 GB)
    - fastq -> .bam -> .bam_snp -> vcf & .wig 
        - fastqc 
        - multiqc (save into csv) 
        - run alignment (bowtie2-bisulfite mode) (.FASTQ -> .BAM-1 mapped bisulfite reads)
            - keep track of alignment memory usage and RAM
            - verify file integrity of resulting .bam
            - (in future export to ftp server -- home lab)
            - delete fastq files no longer needed (save space)
        - run bis-SNP pipeline (.BAM BS -> .BAM SNPs)
            - detect SNPs with bisulfite SNP pipeline (log speed and memory consumption in csv (start and end time ms & total time or detailed))
            - verify file integrity of resulting .bam
            - how to get .vcf & .wig from bs-SNP 
            - delete .BAM BS (original to save space)
            - keep only the resulting .vcf and .wig 

        - loop back to run next file in pipeline (next input in .txt)




