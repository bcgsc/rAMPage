This folder will hold all the tools (dependencies) needed in this pipeline if they are not already installed:

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

:warning: **IMPORTANT** :warning: The path to these dependencies must be configured in `scripts/config.sh` in order to be successfully exported to the rest of the pipeline.
