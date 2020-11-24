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
1. Create a 4 or 5-column TSV file as specified by the [Input](#input) section below, called `accessions.tsv`, in the root of the repository.

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
| [fastp](https://github.com/OpenGene/fastp/releases/tag/v0.20.0) | v0.20.0|
| [RNA-Bloom](https://github.com/bcgsc/RNA-Bloom/releases/tag/v1.3.1) |v1.3.1|
| [salmon](https://github.com/COMBINE-lab/salmon/releases/tag/v1.3.0) | v1.3.0 |
| [TransDecoder](https://github.com/TransDecoder/TransDecoder/releases/tag/TransDecoder-v5.5.0) |v5.5.0|
| [HMMER](https://github.com/EddyRivasLab/hmmer/releases/tag/hmmer-3.3.1) |v3.3.1|
| [cd-hit](https://github.com/weizhongli/cdhit/releases/tag/V4.8.1) | v4.8.1|
| [SignalP](https://services.healthtech.dtu.dk/services/SignalP-5.0/9-Downloads.php#) | v3.0
| [ProP](https://services.healthtech.dtu.dk/services/ProP-1.0/9-Downloads.php#) | v1.0c |
| [AMPlify](https://github.com/bcgsc/AMPlify/releases/tag/v1.0.0) |v1.0.0|
| [SABLE](https://sourceforge.net/projects/meller-sable/) | v4.0 |

### Optional

|Dependency| Tested Version |
|----------|----------------|
| [pigz](https://github.com/madler/pigz/releases/tag/v2.4) |v2.4|
## Input

A 4 or 5-column TSV file named `accessions.tsv`:

| PATH | SRA ACCESSION(S) | LIBRARY<br/>PREP | CLASS<br/>(TAXON) | REFERENCE<br/>([`ftp://ftp.ncbi.nlm.nih.gov`](ftp://ftp.ncbi.nlm.nih.gov))|
|------|------------------|--------------|---------------|-----------|
|ORDER/SPECIES/TISSUE|SRX12345-67|nonstranded|class| `/path/to/reference/transcriptome/gz` |

An example from [`test_accessions.tsv`](test_accessions.tsv):

```
anura/ptoftae/skin-liver   SRX5102741-46 SRX5102761-62  nonstranded  amphibia
hymenoptera/mgulosa/venom  SRX3556750                   stranded     insecta   /genbank/tsa/G/tsa.GGFG.1.fsa_nt.gz
```

In this case, the reference transcriptome is a **Transcriptome Shotgun Assembly** for _M. gulosa_, downloaded from [`ftp://ftp.ncbi.nlm.nih.gov/genbank/tsa/G/tsa.GGFG.1.fsa_nt.gz`](ftp://ftp.ncbi.nlm.nih.gov/genbank/tsa/G/tsa.GGFG.1.fsa_nt.gz).

Other reference transcriptomes can be also downloaded (must be from [`ftp://ftp.ncbi.nlm.nih.gov`](ftp://ftp.ncbi.nlm.nih.gov/)). 

### Multiple References

For example, _A. mellifera_ has multiple reference transcriptomes:

1. **Representative Genome**, downloaded from [`ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/003/254/395/GCF_003254395.2_Amel_HAv3.1/GCF_003254395.2_Amel_HAv3.1_rna.fna.gz`](ftp://ftp.ncbi.nlm.nih.gov/genomes/all/GCF/003/254/395/GCF_003254395.2_Amel_HAv3.1/GCF_003254395.2_Amel_HAv3.1_rna.fna.gz)
1. **Transcriptome Shotgun Assembly**, downloaded from [`ftp://ftp.ncbi.nlm.nih.gov/genbank/tsa/G/tsa.GAZV.1.fsa_nt.gz`](ftp://ftp.ncbi.nlm.nih.gov/genbank/tsa/G/tsa.GAZV.1.fsa_nt.gz) 

In this case, the TSV would look like this:

```
hymenoptera/amellifera/midgut	SRX12345	stranded	insecta	/genomes/all/GCF/003/254/395/GCF_003254395.2_Amel_HAv3.1/GCF_003254395.2_Amel_HAv3.1_rna.fna.gz /genbank/tsa/G/tsa.GAZV.1.fsa_nt.gz
```

## Usage

In the repository directory, run:

```shell
make
```

By default, the input TSV file expected is `accessions.tsv`. However, other TSV files can be specified, such as the `test_accessions.tsv` file used to test the rAMPage.

To test rAMPage, run:

```shell
make TSV=test_accessions.tsv
```

To run multiple datasets in parallel, run:

```shell
make MULTI=true
```

To allow parallel processes to run _in each dataset_, run:

```shell
make PARALLEL=true
```

To receive email alerts as _each dataset_ goes throuih rAMPage, run:

```shell
make EMAIL=user@example.com
```

### Examples

```
make TSV=test_accessions.tsv MULTI=true PARALLEL=true EMAIL=user@example.com
```

## Directory Structure


## Citation

Diana Lin, Ka Ming Nip, Chenkai Li, Rene L. Warren, Caren Helbing, Linda Hoang, Inanc Birol