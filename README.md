# rAMPage: Rapid AMP Annotation and Gene Estimation

Written by [Diana Lin](mailto:dlin@bcgsc.ca).

## Dependencies

### Basics

|Dependency| Tested Version |
|----------|----------------|
| GNU `bash`| v5.0.11(1) |
| GNU `awk` | v5.0.1 |
| GNU `sed` | v4.8 |
| GNU `grep` | v3.4 |
| GNU `make` | v4.3 |
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
|[TransDecoder](https://github.com/TransDecoder/TransDecoder/releases/tag/TransDecoder-v5.5.0) |v5.5.0|
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

A 3-column TSV file:

| PATH | SRA ACCESSION(S) | STRANDEDNESS |
|------|------------------|--------------|
|ORDER/SPECIES/TISSUE|SRX12345-67|nonstranded|

```
anura/xlaevis/liver	SRX847156 SRX847157	nonstranded
hymenoptera/nvitripennis/venom_ovary	SRP067692	stranded
```

## Usage

```
$ cd rAMPage
$ make
```

## Directory Structure


## Installation

1. Edit the paths in `scripts/config.sh`
1. Run `scripts/config.sh`
	```
	$ source scripts/config.sh
	```

## Implementation


## Citation

Diana Lin, Ka Ming Nip, Chenkai Li, Rene L. Warren, Caren Helbing, Linda Hoang, Inanc Birol
