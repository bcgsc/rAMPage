# Scripts

This directory holds all the scripts used in the rAMPage pipeline. To use these scripts individually

### Quick Links

1. [Checking Dependencies](#checking-dependencies)
1. [Downloading Reads](#checking-reads)
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
PROGRAM: check-dependencies.sh

DESCRIPTION:
      Checks that all the dependencies required are have been configured.
      
USAGE(S):
      check-dependencies.sh [-a <address>]
      
OPTION(S):
       -a <address>  email address for alerts
       -h            show help menu
                     
EXAMPLE(S):
      check-dependencies.sh -a user@example.com
```

## Checking Reads

```
DESCRIPTION:
      Checks the input.txt file to make sure the reads are present.
      
USAGE(S):
      check-reads.sh [-a <address>] [-t <int>] <input reads TXT file>
      
OPTION(S):
       -a <address>  email address for alerts
       -h            show help menu
       -t <int>      number of threads (for compression, if needed)
                     
EXAMPLE(S):
      check-reads.sh -a user@example.com -t 8 input.txt
```

## Trimming Reads

```
PROGRAM: trim-reads.sh

DESCRIPTION:
       Preprocesses and trims reads with fastp.
       
       OUTPUT:
       -------
         - *.fastq.gz
         - TRIM.DONE
       
       EXIT CODES:
       -----------
         - 0: successfully completed
         - 1: general error
         - 2: trimming failed
         - 3: core dumped
       
       For more information: https://github.com/OpenGene/fastp
       
USAGE(S):
      trim-reads.sh [-a <address>] [-p] [-t <int>] -i <input directory> -o <output directory>
      
OPTION(S):
       -a <address>    email address for alerts                        
       -h              show this help menu                 
       -i <directory>  input directory for raw reads       (required)
       -o <directory>  output directory for trimmed reads  (required)
       -p              trim each run in parallel           
       -t <int>        number of threads                   (default = 4)
                                                           
EXAMPLE(S):
      trim-reads.sh -a user@example.com -p -t 8 -i /path/to/raw_reads -o /path/to/trimmed_reads
```

## Building a Reads List

```
PROGRAM: build-reads-list.sh

DESCRIPTION:
      Uses the input.processed.txt (produced by check-reads.sh) and builds a reads list for RNA-Bloom.
      
USAGE(S):
      build-reads-list.sh [-a <address>] [-s] -i <input directory> <input reads TXT file>
      
OPTION(S):
       -a <address>    email address for alerts                           
       -h              show help menu                                     
       -i <directory>  input directory (i.e. directory of trimmed reads)  (required)
       -s              strand-specific library construction               (default = false)
                                                                          
EXAMPLE(S):
      build-reads-list.sh -a user@example.com -s -i /path/to/trimmed_reads input.txt
```

## Transcriptome Assembly

```
PROGRAM: run-rnabloom.sh

DESCRIPTION:
       Uses RNA-Bloom to assembly trimmed reads into transcripts. If a reference-guided assembly is desired, please place the reference transcriptome(s) (e.g. *.fna) in the working directory. In this case, the working directory is inferred to be the parent directory of your specified output directory.
       
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
      run-rnabloom.sh [-a <address>] [-m <int K/M/G>] [-s] [-t <int>] -o <output directory> <reads list TXT file>
      
OPTION(S):
       -a <address>    email address for alerts                          
       -h              show help menu                        
       -m <int K/M/G>  allotted memory for Java (e.g. 500G)  
       -o <directory>  output directory                      (required)
       -s              strand-specific library construction  (default = false)
       -t <int>        number of threads                     (default = 8)
                                                             
EXAMPLE READS LIST (NONSTRANDED):
       tissue1 /path/to/readA_1.fastq.gz /path/to/readA_2.fastq.gz
       tissue2 /path/to/readB_1.fastq.gz /path/to/readB_2.fastq.gz
       ...     ...                       ...
       ...     ...                       ...
       ...     ...                       ...
       
EXAMPLE READS LIST (STRANDED):
       tissue1 /path/to/readA_2.fastq.gz /path/to/readB_1.fastq.gz
       tissue2 /path/to/readB_2.fastq.gz /path/to/readB_1.fastq.gz
       ...     ...                       ...
       ...     ...                       ...
       ...     ...                       ...
       
EXAMPLE(S):
      run-rnabloom.sh -a user@example.com -m 500G -s -t 8 -o /path/to/assembly /path/to/trimmed_reads/readslist.txt
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
      filter-expression.sh [-a <address>] [-c <dbl>] [-s] [-t <int>] -o <output directory> -r <reference transcriptome (assembly)> <readslist TXT file>
      
OPTION(S):
       -a <address>     email alert                           
       -c <dbl>         TPM cut-off                           (default = 0.50)
       -h               show this help menu                   
       -o <directory>   output directory                      (required)
       -r <FASTA file>  reference transcriptome (assembly)    (required)
       -s               strand-specific library construction  (default = false) 
       -t <int>         number of threads                     (default = 2)
                                                              
EXAMPLE(S):
      filter-expression.sh -a user@example.com -c 1.0 -s -t 8 -o /path/to/filtering -r /path/to/assembly/rnabloom.transcripts.all.fa /path/to/trimmed_reads/readslist.txt
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
      translate.sh [-a <address>] -o <output directory> <input FASTA file>
      
OPTION(S):
       -a <address>    email address for alerts  
       -h              show this help menu       
       -o <directory>  output directory          (required)
                                                 
EXAMPLE(S):
      translate.sh -a user@example.com -o /path/to/translation /path/to/filtering/rnabloom.transcripts.filtered.fa
```

## Homology Search

```
PROGRAM: run-jackhmmer.sh

DESCRIPTION:
       Runs jackhmmer from the HMMER package to find AMPs via homology search of protein sequences.
       Requires /projects/amp/rAMPage/amp_seqs/amps.Amphibia.prot.combined.faa or /projects/amp/rAMPage/amp_seqs/amps.Insecta.prot.combined.faa file.
       
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
      run-jackhmmer.sh [-a <address>] [-e <E-value>] [-s <0 to 1>] [-t <int>] -o <output directory> <input FASTA file>
      
OPTION(S):
       -a <address>    email address for alerts                                
       -e <E-value>    E-value threshold                          (default = 1e-3)
       -h              show this help menu                        
       -o <directory>  output directory                           (required)
       -s <0 to 1>     CD-HIT global sequence similarity cut-off  (default = 0.90)
       -t <int>        number of threads                          (default = 8)
                                                                  
EXAMPLE(S):
      run-jackhmmer.sh -a user@example.com -e 1e-3 -s 0.90 -t 8 -o /path/to/homology /path/to/translation/rnabloom.transcripts.filtered.transdecoder.faa
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
      cleave.sh [-a <address>] [-c] -o <output directory> <input FASTA file>
      
OPTION(S):
       -a <address>    email address for alerts                                                
       -c              allow consecutive (i.e. adjacent) segments to be recombined  
       -h              show this help menu                                          
       -o <directory>  output directory                                             (required)
                                                                                    
EXAMPLE(S):
      cleave.sh -a user@example.com -c -o /path/to/cleavage /path/to/homology/jackhmmer.nr.faa
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
      run-amplify.sh [-a <address>] [-c <int>] [-l <int>] [-s <0 to 1>] [-t <int>] -o <output directory> <input FASTA file>
      
OPTION(S):
       -a <address>    email address for alerts                                        
       -c <int>        charge cut-off [i.e. keep charge(sequences >= int]         (default = 2)
       -h              show this help menu                                        
       -l <int>        length cut-off [i.e. keep len(sequences) <= int]           (default = 50)
       -o <directory>  output directory                                           (required)
       -s <0 to 1>     AMPlify score cut-off [i.e. keep score(sequences) >= dbl]  (default = 0.99)
       -t <int>        number of threads                                          (default = all)
                                                                                  
EXAMPLE(S):
      run-amplify.sh -a user@example.com -c 2 -l 50 -s 0.99 -t 8 -o /path/to/amplify /path/to/cleavage/cleaved.mature.len.faa
```
