# Scripts

This directory holds all the scripts used in the rAMPage pipeline.

### Quick Links

1. [Downloading Metadata](#downloading-metadata)
1. [Downloading Reads](#downloading-reads)
1. [Trimming Reads](#trimming-reads)
1. [Making A Reads List](#making-a-reads-list)
1. [Transcriptome Assembly](#transcriptome-assembly)
1. [Filtering By Expression](#filtering-by-expression)
1. [_in silico_ Translation](#in-silico-translation)
1. [Homology Search](#homology-search)
1. [Cleavage](#cleavage)
1. [AMPlify](#amplify)

## Downloading Metadata

```
PROGRAM: get-runs.sh

DESCRIPTION:
       Gets the SRA RUN (i.e. SRR) accessions using wget.
       
       OUTPUT:
       -------
         - runs.txt
         - metadata.tsv
         - RUNS.DONE
         - METADATA.DONE
       
       
       EXIT CODES:
       -------------
         - 0: successfully completed
         - 1: general error
       
USAGE(S):
      get-runs.sh [OPTIONS] -o <output directory> <SRA accessions TXT file>
      
OPTION(S):
       -h              show this help menu  
       -o <directory>  output directory     (required)
                                            
EXAMPLE(S):
      get-runs.sh -o /path/to/sra /path/to/accessions.txt
```

## Downloading Reads

```
PROGRAM: get-reads.sh

DESCRIPTION:
       Gets reads for one single organism, using fasterq-dump.
       
       OUTPUT:
       -------
         - *.fastq.gz
         - RUNS.DONE or RUNS.FAIL
       
       EXIT CODES:
       -------------
         - 0: successfully completed
         - 1: general error
         - 2: failed to download
       
       For more information: https://github.com/ncbi/sra-tools/wiki/HowTo:-fasterq-dump
       
USAGE(S):
      get-reads.sh [OPTIONS] -o <output directory> <SRA RUN (i.e. SRR) accession list>
      
OPTION(S):
       -a <address>    email alert                    
       -h              show this help menu            
       -o <directory>  output directory               (required)
       -p              download each run in parallel  
       -t <int>        number of threads              (default = 2)
                                                      
EXAMPLE(S):
      get-reads.sh -o /path/to/raw_reads /path/to/sra/runs.txt
```

## Trimming Reads

```
PROGRAM: trim-reads.sh

DESCRIPTION:
       Preprocesses and trims reads with fastp.

       OUTPUT:
       -------
         - *.[paired.]fastq.gz
         - TRIM.DONE

       EXIT CODES:
       -----------
         - 0: successfully completed
         - 1: general error
         - 2: trimming failed
         - 3: core dumped

       For more information: https://github.com/OpenGene/fastp

USAGE(S):
      trim-reads.sh [OPTIONS] -i <input directory> -o <output directory>

OPTION(S):
       -a <address>    email alert
       -h              show this help menu
       -i <directory>  input directory for raw reads       (required)
       -o <directory>  output directory for trimmed reads  (required)
       -p              trim each run in parallel
       -t <int>        number of threads                   (default = 4)

EXAMPLE(S):
      trim-reads.sh -i /path/to/raw_reads -o /path/to/trimmed_reads
```

## Making a Reads List

```
PROGRAM: make-reads-list.sh

DESCRIPTION:
       Makes the pooled reads lists for RNA-Bloom. Filters given TSV for relevant information.
       
       OUTPUT:
       -------
         - reads.txt
         - READSLIST.DONE
       
       EXIT CODES:
       -----------
         - 0: successfully completed
         - 1: general error
       
       For more information: https://github.com/bcgsc/RNA-Bloom
       
USAGE(S):
      make-reads-list.sh [OPTIONS] -d <I/O directory> <metadata TSV file>
      
OPTION(S):
       -d <directory>  Input directory (trimmed reads) and output directory for reads list  (required)
       -h              Show this help menu                                                  
                                                                                            
EXAMPLE(S):
      make-reads-list.sh -d /path/to/trimmed_reads /path/to/sra/metadata.tsv
```

## Transcriptome Assembly

```
PROGRAM: run-rnabloom.sh

DESCRIPTION:
       Uses RNA-Bloom to assembly trimmed reads into transcripts. Strandedness of the library is determined by the *.LIB file in the working directory. If a reference-guided assembly is desired, please place the reference transcriptome(s) (e.g. *.fna) in the working directory. In this case, the working directory is inferred to be the parent directory of your specified output directory.

       OUTPUT:
       -------
         - rnabloom.transcripts.all.fa
         - ASSEMBLY.DONE or ASSEMBLY.FAIL

       EXIT CODES:
       -----------
         - 0: successfully completed
         - 1: general error

       For more information: https://github.com/bcgsc/RNA-Bloom

USAGE(S):
      run-rnabloom.sh [OPTIONS] -o <output directory> <reads list>

OPTION(S):
       -a <address>    email alert
       -h              show help menu
       -m <int K/M/G>  allotted memory for Java (e.g. 500G)
       -o <directory>  output directory
       -t <int>        number of threads                     (default = 8)

EXAMPLE READS LIST (NONSTRANDED):
       tissue1 path/to/read1.fastq.gz path/to/read2.fastq.gz
       tissue2 path/to/read1.fastq.gz path/to/read2.fastq.gz
       ...     ...                    ...
       ...     ...                    ...
       ...     ...                    ...

EXAMPLE READS LIST (STRANDED):
       tissue1 path/to/read2.fastq.gz path/to/read1.fastq.gz
       tissue2 path/to/read2.fastq.gz path/to/read1.fastq.gz
       ...     ...                    ...
       ...     ...                    ...
       ...     ...                    ...

EXAMPLE(S):
      run-rnabloom.sh -o /path/to/assembly /path/to/trimmed_reads/reads.txt
```

## Filtering By Expression

```
PROGRAM: filter-expression.sh

DESCRIPTION:
       Quantifies the expression of each transcript using Salmon and filters out lowly expressed transcripts specified by the given TPM cut-off.

       OUTPUT:
       -------
         - rnabloom.transcripts.filtered.fa
         - FILTERING.DONE or FILTERING.FAIL

       EXIT CODES:
       -----------
         - 0: successfully completed
         - 1: general error
         - 2: filtering failed

       For more information: https://combine-lab.github.io/salmon/

USAGE(S):
      filter-expression.sh [OPTIONS] -o <output directory> -r <reference transcriptome (assembly)> <readslist TXT file>

OPTION(S):
       -a <address>     email alert
       -c <dbl>         TPM cut-off                         (default = 0.50)
       -h               show this help menu
       -o <directory>   output directory                    (required)
       -r <FASTA file>  reference transcriptome (assembly)  (required)
       -t <int>         number of threads                   (default = 2)

EXAMPLE(S):
      filter-expression.sh -o /path/to/filtering -r /path/to/assembly/rnabloom.transcripts.all.fa /path/to/trimmed_reads/reads.txt
```

## _in silico_ Translation

```
PROGRAM: translate.sh

DESCRIPTION:
       Takes transcripts and translates them into protein sequences.

       OUTPUT:
       -------
         - rnabloom.transcripts.filtered.transdecoder.faa
         - TRANSLATION.DONE or TRANSLATION.FAIL

       EXIT CODES:
       -----------
         - 0: successfully completed
         - 1: general error
         - 2: translation failed

       For more information: http://transdecoder.github.io

USAGE(S):
      translate.sh [OPTIONS] -o <output directory> <input FASTA file>

OPTION(S):
       -a <address>    email alert
       -h              show this help menu
       -o <DIRECTORY>  output directory     (required)

EXAMPLE(S):
      translate.sh -o /path/to/translation /path/to/filtering/rnabloom.transcripts.filtered.fa
```

## Homology Search

```
PROGRAM: run-jackhmmer.sh

DESCRIPTION:
       Runs jackhmmer from the HMMER package to find AMPs via homology search of protein sequences.

       OUTPUT:
       -------
         - jackhmmer.nr.faa
         - HOMOLOGY.DONE or HOMOLOGY.FAIL
         - JACKHMMER.DONE or JACKHMMER.FAIL
         - SEQUENCES.DONE or SEQUENCES.FAIL
         - SEQUENCES_NR.DONE or SEQUENCES_NR.FAIL

       EXIT CODES:
       -----------
         - 0: successfully completed
         - 1: general error
         - 2: homology search failed
         - 3: sequence fetch failed
         - 4: homology search yielded 0 results
         - 5: sequence redundancy removal failed

       For more information: http://eddylab.org/software/hmmer/Userguide.pdf

USAGE(S):
      run-jackhmmer.sh [OPTIONS] -o <output directory> <input FASTA file>

OPTION(S):
       -a <address>    email alert
       -e <E-value>    E-value threshold                           (default = 1e-3)
       -h              show this help menu
       -o <directory>  output directory                            (required)
       -s <0 to 1>      CD-HIT global sequence similarity cut-off  (default = 0.90)
       -t <int>        number of threads                           (default = 8)

EXAMPLE(S):
      run-jackhmmer.sh -o /path/to/homology /path/to/translation/rnabloom.transcripts.filtered.transdecoder.faa
```

## Cleavage

```
PROGRAM: cleave.sh

DESCRIPTION:
       Uses ProP (and SignalP, if available) to predict prepropeptide cleavage sites, and obtain the mature peptide sequence.

       OUTPUT:
       -------
         - cleaved.mature.len.faa
         - CLEAVE.DONE or CLEAVE.FAIL
         - CLEAVE_LEN.DONE or CLEAVE_LEN.FAIL

       EXIT CODES:
       -----------
         - 0: successfully completed
         - 1: general error
         - 2: SignalP not found
         - 3: cleavage failed
         - 4: length filtering failed

       For more information on ProP: https://services.healthtech.dtu.dk/service.php?ProP-1.0

USAGE(S):
      cleave.sh [OPTIONS] -o <output directory> <input FASTA file>

OPTION(S):
       -a <address>    email alert
       -c              allow consecutive (i.e. adjacent) segments to be recombined
       -h              show this help menu
       -o <directory>  output directory                                             (required)

EXAMPLE(S):
      cleave.sh -o /path/to/cleavage /path/to/homology/jackhmmer.nr.faa
```

## AMPlify

```
PROGRAM: run-amplify.sh

DESCRIPTION:
       Predicts AMP vs. non-AMP from the peptide sequence using AMPlify.

       OUTPUT:
       -------
         - amps.conf.short.charge.nr.faa
         - AMPlify_results.conf.short.charge.tsv

       EXIT CODES:
       -----------
         - 0: successfully completed
         - 1: general errors
         - 2: AMPlify failed

       For more information on AMPlify: https://github.com/bcgsc/amplify

USAGE(S):
      run-amplify.sh [OPTIONS] -o <output directory> <input FASTA file>

OPTION(S):
       -a <address>    email address alert
       -c <INT>        charge cut-off (i.e. keep charge(sequences >= INT)         (default = 2)
       -h              show this help menu
       -l <INT>        length cut-off (i.e. keep len(sequences) <= INT)           (default = 50)
       -o <directory>  output directory                                           (required)
       -s <0 to 1>     AMPlify score cut-off (i.e. keep score(sequences) >= DBL)  (default = 0.99)
       -t <INT>        number of threads                                          (default = 8)

EXAMPLE(S):
      run-amplify.sh -o /path/to/amplify /path/to/cleavage/cleaved.mature.len.faa
```
