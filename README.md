# rAMPage: Rapid/Robust AMP Annotation and Gene Estimation

Written by [Diana Lin](mailto:dlin@bcgsc.ca).


## Description

rAMPage is a _de novo_ AMP discovery pipeline...TODO

## Quick Links

1. [Setup](#setup)
1. [Dependencies](#dependencies)
	1. [Basics](#basics)
	1. [Tools](#tools)
	1. [Optional](#optional)
1. [Input](#input)
1. [Usage](#usage)
1. [Directory Structure](#directory-structure)
1. [Citation](#citation)


## Setup

1. Clone this repository:
	```
	git clone https://github.com/bcgsc/rAMPage.git
	```
1. Download and install the dependencies (specified in the [Dependencies](#dependencies) section below), into [`rAMPage/src`](src/).
1. Update _all_ the paths in [`rAMPage/scripts/config.sh`](scripts/config.sh) to reflect dependencies in [`rAMPage/src`](src/) and dependencies pre-installed elsewhere.
1. Source [`scripts/config.sh`](scripts/config.sh) in the root of the repository.
	```shell
	cd rAMPage
	source scripts/config.sh
	```
1. Create working directories for each dataset using this convention: 
	`taxonomic-class/species/tissue-or-condition`
	- **NOTE**: the top-level parent directory _must_ correspond to the taxonomic class of the dataset. This class is used to choose which file in `amp_seqs` to use for homology search.
	- e.g. _M. gulosa_: `insecta/mgulosa/venom-gland`
	- e.g. _P. toftae_: `amphibia/ptoftae/skin-liver`
1. Move all reads and reference FASTA files to the respective working directories for each dataset. See below for an example.
1. Create a 2 or 3-column space-delimited text file as specified by the [Input](#input) section below, called `input.txt`, in the working directory of each dataset.

At the end of setup, you should have a directory structure similar to below (excludes other directories, like `scripts/`):

```
rAMPage
├── amphibia
│   └── ptoftae
│       └── skin-liver
│           ├── input.txt
│           ├── SRR8288040_1.fastq.gz
│           ├── SRR8288040_2.fastq.gz
│           ├── SRR8288041_1.fastq.gz
│           ├── SRR8288041_2.fastq.gz
│           ├── SRR8288056_1.fastq.gz
│           ├── SRR8288056_2.fastq.gz
│           ├── SRR8288057_1.fastq.gz
│           ├── SRR8288057_2.fastq.gz
│           ├── SRR8288058_1.fastq.gz
│           ├── SRR8288058_2.fastq.gz
│           ├── SRR8288059_1.fastq.gz
│           ├── SRR8288059_2.fastq.gz
│           ├── SRR8288060_1.fastq.gz
│           ├── SRR8288060_2.fastq.gz
│           ├── SRR8288061_1.fastq.gz
│           └── SRR8288061_2.fastq.gz
└── insecta
    └── mgulosa
        └── venom
            ├── input.txt
            ├── SRR6466797_1.fastq.gz
            ├── SRR6466797_2.fastq.gz
            └── tsa.GGFG.1.fsa_nt.gz
```

## Dependencies

### Basics

|Dependency| Tested Version |
|----------|----------------|
| GNU `bash`| v5.0.11(1) |
| GNU `awk` | v5.0.1 |
| GNU `sed` | v4.8 |
| GNU `grep` | v3.4 |
| GNU `make` | v4.3 |
| GNU `column` | 2.36 |
| `python` | v3.7.7
<!-- - [ ] Perl v5.32.0 -->

### Tools

|Dependency| Tested Version |
|----------|----------------|
| [SRA toolkit](https://github.com/ncbi/sra-tools/releases/tag/2.10.5) | v2.10.5 |
| [EDirect](https://www.ncbi.nlm.nih.gov/books/NBK179288/) | v13.8 |
| [fastp](https://github.com/OpenGene/fastp/releases/tag/v0.20.0) | v0.20.0|
| [RNA-Bloom](https://github.com/bcgsc/RNA-Bloom/releases/tag/v1.3.1) |v1.3.1|
| [salmon](https://github.com/COMBINE-lab/salmon/releases/tag/v1.3.0) | v1.3.0 |
| [TransDecoder](https://github.com/TransDecoder/TransDecoder/releases/tag/TransDecoder-v5.5.0) |v5.5.0|
| [HMMER](https://github.com/EddyRivasLab/hmmer/releases/tag/hmmer-3.3.1) |v3.3.1|
| [cd-hit](https://github.com/weizhongli/cdhit/releases/tag/V4.8.1) | v4.8.1|
| [seqtk](https://github.com/lh3/seqtk/releases/tag/v1.1)| v1.1-r91 |
| [SignalP](https://services.healthtech.dtu.dk/services/SignalP-5.0/9-Downloads.php#) | v3.0
| [ProP](https://services.healthtech.dtu.dk/services/ProP-1.0/9-Downloads.php#) | v1.0c |
| [AMPlify](https://github.com/bcgsc/AMPlify/releases/tag/v1.0.0) |v1.0.0|
| [SABLE](https://sourceforge.net/projects/meller-sable/) | v4.0 |

### Optional

|Dependency| Tested Version |
|----------|----------------|
| [pigz](https://github.com/madler/pigz/releases/tag/v2.4) |v2.4|

## Input

A 2 or 3-column space-delimited text file named `input.txt`, located in the working directory of each dataset.

| Column | Attribute |
|--------|-----------|
| 1 | Pooling ID: generally a condition, tissue, or sex, etc. |
| 2 | Path to read 1 |
| 3 | Path to read 2 (if paired-end reads) |

Read paths in this input text file should be relative to the location of the input text file.

#### Example: _M. gulosa_

| POOLING ID | READ 1 | READ 2 |
|---------------------|--------|--------|
| venom | SRR6466797_1.fastq.gz | SRR6466797_2.fastq.gz |

`insecta/mgulosa/venom/input.txt`:

```
venom SRR6466797_1.fastq.gz SRR6466797_2.fastq.gz
```

#### Example: _P. toftae_

| POOLING ID | READ 1 | READ 2 |
|---------------------|--------|--------|
|KST695_liver|SRR8288040_1.fastq.gz|SRR8288040_2.fastq.gz|
|KST695_skin|SRR8288041_1.fastq.gz|SRR8288041_2.fastq.gz|
|KST688_liver|SRR8288056_1.fastq.gz|SRR8288056_2.fastq.gz|
|KST685_skin|SRR8288057_1.fastq.gz|SRR8288057_2.fastq.gz|
|KST685_liver|SRR8288058_1.fastq.gz|SRR8288058_2.fastq.gz|
|KST687_skin|SRR8288059_1.fastq.gz|SRR8288059_2.fastq.gz|
|KST687_liver|SRR8288060_1.fastq.gz|SRR8288060_2.fastq.gz|
|KST688_skin|SRR8288061_1.fastq.gz|SRR8288061_2.fastq.gz|

`amphibia/ptoftae/skin-liver/input.txt`:

```
KST695_liver SRR8288040_1.fastq.gz SRR8288040_2.fastq.gz
KST695_skin SRR8288041_1.fastq.gz SRR8288041_2.fastq.gz
KST688_liver SRR8288056_1.fastq.gz SRR8288056_2.fastq.gz
KST685_skin SRR8288057_1.fastq.gz SRR8288057_2.fastq.gz
KST685_liver SRR8288058_1.fastq.gz SRR8288058_2.fastq.gz
KST687_skin SRR8288059_1.fastq.gz SRR8288059_2.fastq.gz
KST687_liver SRR8288060_1.fastq.gz SRR8288060_2.fastq.gz
KST688_skin SRR8288061_1.fastq.gz SRR8288061_2.fastq.gz
```

### Reference Transcriptomes

To use a reference transcriptome for the assembly stage with RNA-Bloom, put the reference in the working directory or use the `-r` option of `scripts/rAMPage.sh`.

```
insecta/mgulosa/venom
├── input.txt
├── SRR6466797_1.fastq.gz
├── SRR6466797_2.fastq.gz
└── tsa.GGFG.1.fsa_nt.gz
```

In this case, the reference transcriptome is a **Transcriptome Shotgun Assembly** for _M. gulosa_, downloaded from [`ftp://ftp.ncbi.nlm.nih.gov/genbank/tsa/G/tsa.GGFG.1.fsa_nt.gz`](ftp://ftp.ncbi.nlm.nih.gov/genbank/tsa/G/tsa.GGFG.1.fsa_nt.gz).

Multiple references can be used as long as they are placed in the working directory.

### Sources of References

**Representative Genomes** can be found by searching the Genome database on [NCBI](https://www.ncbi.nlm.nih.gov/genome/), using these search terms (_A. mellifera_, for example):

```
"Apis mellifera"[orgn]
```

**Transcriptome Shotgun Assemblies** can be found by searching the Nucleotide database on [NCBI](https://www.ncbi.nlm.nih.gov/nucleotide), using these search terms:

```
tsa-master[prop] "Apis mellifera"[orgn] midgut[All Fields]
```

## Usage

The `rAMPage.sh` script in `scripts/` runs the pipeline using a `Makefile`.

```
DESCRIPTION:
      Runs the rAMPage pipeline, using the Makefile.
      
USAGE(S):
      rAMPage.sh [-s] [-o <output directory>] [-r <reference>] <input reads TXT file>
      
OPTIONS:
       -a <address>    email alert                    
       -h              show help menu                 
       -o <directory>  output directory               (default = directory of input reads TXT file)
       -p              run processes in parallel      
       -r <FASTA.gz>   reference transcriptome        (accepted multiple times, *.fna.gz *.fsa_nt.gz)
       -s              stranded library construction  (default = nonstranded)
       -t <INT>        number of threads              (default = 48)
                                                      
EXAMPLE(S):
      rAMPage.sh -s -o /path/to/output/directory -r /path/to/reference.fna.gz -r /path/to/reference.fsa_nt.gz /path/to/input.txt 
      
INPUT EXAMPLE:
       tissue /path/to/readA_1.fastq.gz /path/to/readA_2.fastq.gz
       tissue /path/to/readB_1.fastq.gz /path/to/readB_2.fastq.gz
```

### Running from the root of the repository

Example: _M. gulosa_ (stranded library construction)

```shell
scripts/rAMPage.sh -s -o insecta/mgulosa/venom -r insecta/mgulosa/venom/tsa.GGFG.1.fsa_nt.gz insecta/mgulosa/venom/input.txt
```

In the example above, the `-o insecta/mgulosa/venom` argument is _optional_, since the default will be set as parent directory of the `input.txt` file. This option is a safeguard for the scenario where `input.txt` is _not_ located in the working directory. In this case, the `-o` option will move `input.txt` and provided references to the working directory.

rAMPage will use all `*.fsa_nt*` and `*.fna*` files located in the working directory as references in the assembly stage, _regardless of if the `-r` option is used or not._ This option is a safeguard for the scenario where the references provided are _not_ located in the working directory. In this case, the `-r` option will _move_ the references to the working directory.

### Running from the working directory of the dataset

Example: _M. gulosa_ (stranded library construction)

```shell
$ROOT_DIR/scripts/rAMPage.sh -s -r tsa.GGFG.1.fsa_nt.gz input.txt
```

### Running multiple datasets simultaneously

TODO

## Directory Structure

```
rAMPage
├── amphibia
│   └── ptoftae
│       └── skin-liver
├── amp_seqs
├── insecta
│   └── mgulosa
│       └── venom
├── scripts
└── src
```

## Citation

Diana Lin, Ka Ming Nip, Chenkai Li, Rene L. Warren, Caren Helbing, Linda Hoang, Inanc Birol