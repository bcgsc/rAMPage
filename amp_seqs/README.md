# AMP Sequences

This directory holds the AMP sequences collated on July 20, 2020, using the script [`scripts/homology-db.sh`](../scripts/homology-db.sh). The sequences were downloaded from APD3, DADP, and NCBI.

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
