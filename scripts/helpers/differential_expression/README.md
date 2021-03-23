# Differential Expression Analysis Pipeline

Written by [Sambina Islam Aninta](mailto:sambina.islam@gmail.com).

## Description
This differential expression analysis pipeline uses RNA-seq reads and assembled reference genome and outputs a FASTA file of confident, charged, short and upregulated and downregulated putative AMPs.

## Workflow

    1. Obtain assembled reference genome and RNA-seq reads from the rAMPage pipeline  
    2. Quantify using salmon 
    3. Create the metadata file to run DESeq
    - Create a 3-column comma separated file in the format sample,treatment,/path/to/quant.sf
    4. Perform differential expression analysis using DESeq2 – must have replicates in the dataset
    5. Create volcano plot, ma plot and pheatmap and generate fasta file with upregulated AMPs
    

## Criteria to choose datasets
    Datasets must have replicates

## Dependencies 
### Basics

|Dependency| Tested Version |
|----------|----------------|
| salmon | v1.3.0 |
| R | v4.0.2 |


### R packages for the scripts

|Dependency| Tested Version |
|----------|----------------|
| DESeq2 | v1.20.0 |
| tidyverse | v1.3.0 |
| tximport | v1.8.0 |
| glue | v1.4.2 |
| docopt | v0.7.1 |
| ggplot2 | v3.3.3 |
| scales | v1.1.1 |
| ggnewscale | v0.4.5 |
| pheatmap | v1.0.12 |
| edgeR | v3.28.1 |
| dplyr | v1.0.4 |
| seqRFLP | v1.0.1 |   
## Usage

### Quantify using Salmon

```
PROGRAM: salmonquant.sh

DESCRIPTION: Quantifies the expression of each transcript using Salmon

USAGE(S):
    salmonquant.sh <reference transcriptome (assembly)> <paired/unpaired> <stranded/unstranded> <threads> <output directory> <readslist TXT file>

EXAMPLE(S):
    salmonquant.sh /path/to/assembly/rnabloom.transcripts.all.fa paired/unpared stranded/unstranded threads /path/to/output /path/to/input.processed.txt 
```


### Differential Expression Analysis

```
PROGRAM: DESeq2-replicates.R

DESCRIPTION: Performs differential expression analysis using DESeq

USAGE(S):
    Rscript DESeq2-replicates.R <metadata file>

EXAMPLE(S):
    Rscript DESeq2-replicates.R /path/to/metadata.csv
```


### Visualizing the results

```
PROGRAM: plots.R

DESCRIPTION: Creates heatmap, volcano plot and MA plot from DESeq results and a FASTA file with upregulated and downregulated putative AMPs

USAGE(S):
    DESeq2-plots.R <DESeq results> <txi results> <AMPlify results> <Name of the dataset>"

EXAMPLE(S):
    plots.R /path/to/filtering/DESeq2/metadata/treatmentvscontrol.RDS /path/to/filtering/DESeq2/metadata/txi.salmon.RDS /path/to/AMPlify_results.nr.tsv data_name

```





 

