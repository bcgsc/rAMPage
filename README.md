# rAMPage: Rapid/Robust AMP Annotation and Gene Estimation

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

A 3-column TSV file named `accessions.tsv`:

| PATH | SRA ACCESSION(S) | STRANDEDNESS |
|------|------------------|--------------|
|ORDER/SPECIES/TISSUE|SRX12345-67|nonstranded|

```
anura/ptoftae/skin-liver        SRX5102741-46 SRX5102761-62     nonstranded
hymenoptera/mgulosa/venom       SRX3556750      stranded
```

See `test_accessions.tsv` for an example.

## Setup

1. Download and install the dependencies, into `src`.
1. Update _all_ the paths in `scripts/config.sh` to reflect dependencies in `src` and dependencies pre-installed elsewhere.
1. Source `scripts/config.sh`.
	```
	$ source scripts/config.sh
	```
1. Create a 3-column TSV file as specified by the `Input` section above, called `accessions.tsv`.

## Usage

In the repository directory, run:

```
$ make
```

By default, the input TSV file expected is `accessions.tsv`. However, other TSV files can be specified, such as the `test_accessions.tsv` file used to test the pipeline.

To test the pipeline, run:

```
$ make TSV=test_accessions.tsv
```

To allow certain processes to run in parallel in each dataset, run:

```
$ make PARALLEL=true
```

To receive email alerts as each dataset goes through the pipeline, run:

```
$ make EMAIL=user@example.com
```

## Directory Structure


## Citation

Diana Lin, Ka Ming Nip, Chenkai Li, Rene L. Warren, Caren Helbing, Linda Hoang, Inanc Birol
