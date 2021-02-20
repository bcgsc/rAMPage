# AMP Sequences

## Provided Sequences

| File | Description |
|------|-------------|
|`amps.Amphibia.prot.2020Jul20.combined.faa` | precursor and mature amphibian AMP sequences from APD3, DADP, and NCBI collated on July 20, 2020|
|`amps.Amphibia.prot.combined.mature.faa` | mature amphibian AMP sequences from APD3 and DADP |
|`amps.Amphibia.prot.combined.faa` | soft symlink to `amps.Amphibia.prot.2020Jul20.combined.faa` (used by scripts in rAMPage)|
|`amps.Insecta.prot.2020Jul20.combined.faa` | precursor and mature insect AMP sequences from APD3 and NCBI collated on July 20, 2020|
|`amps.Insecta.prot.combined.faa` | soft symlink to `amps.Insecta.prot.2020Jul20.combined.faa` (used by scripts in rAMPage)|
|`amps.Insecta.prot.mature.faa` | mature insect AMP sequences from APD3 |

This directory holds the AMP sequences collated on July 20, 2020, using the script [`rAMPage/scripts/homology-db.sh`](../scripts/helpers/homology-db.sh). The sequences were downloaded from APD3, DADP, and NCBI. Remember to update the soft symlinks if the AMP sequences are updated.

**Note**: The `rAMpage/scripts/homology-db.sh` script requires the [EDirect](https://www.ncbi.nlm.nih.gov/books/NBK179288/) dependency.

### APD3: Antimicrobial Peptide Database 3

* Website: http://aps.unmc.edu/AP/main.php
* Source: http://aps.unmc.edu/AP/APD3_update_2020_release.fasta

### DADP: Database of Anuran Defense Peptides

* Website: http://split4.pmfst.hr/dadp/
* Source: https://github.com/mark0428/Scraping/raw/master/DADP/DADP_mature_AMP_20181206.fa
	* scraped using [these scripts](https://github.com/mark0428/Scraping/tree/master/DADP) on December 6, 2018

### NCBI

* Downloaded using EDirect utilities on July 20, 2020.

	#### Amphibian AMPs
	```shell
	esearch -db protein -query "antimicrobial[All Fields] AND amphibia[organism]" < /dev/null | efetch -format fasta 
	```

	#### Insect AMPs
	```shell
	esearch -db protein -query "antimicrobial[All Fields] AND insecta[organism]" < /dev/null | efetch -format fasta 
	```
