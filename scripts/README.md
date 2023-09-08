# Scripts

This directory holds all the scripts used in the rAMPage pipeline. Each of the scripts below are used in the Makefile. Optional helper scripts can be found in the `helpers`[helpers/] directory, such as a script to help download reads from the SRA. Differential expression analysis can also be conducted using the scripts located in [`helpers/differential_expression/`](helpers/differential_expression/).

**Note**: The scripts in this directory are used by the `Makefile`. Under most circumstances, these scripts will not need to be run outside of the `Makefile`. 

**Warning**: The documentation on this page may be out of date. For most up to date documentation, use the `-h` option in the corresponding script.

### Quick Links

1. [Checking Dependencies](#checking-dependencies)
1. [Checking Reads](#checking-reads)
1. [Trimming Reads](#trimming-reads)
1. [Building A Reads List](#building-a-reads-list)
1. [Transcriptome Assembly](#transcriptome-assembly)
1. [Filtering By Expression](#filtering-by-expression)
1. [_in silico_ Translation](#in-silico-translation)
1. [Homology Search](#homology-search)
1. [Cleavage](#cleavage)
1. [AMPlify](#amplify)
1. [Annotation](#annotation)
1. [Exonerate](#exonerate)
1. [SABLE](#sable)
1. [Extras](#extras)


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
      check-reads.sh [-a <address>] [-h] [-t <int>] <input reads TXT file>
      
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
      trim-reads.sh [-a <address>] [-h] [-p] [-t <int>] -i <input directory> -o <output directory> <input reads TXT file>
      
OPTION(S):
       -a <address>    email address for alerts            
       -h              show this help menu                 
       -i <directory>  input directory for raw reads       (required)
       -o <directory>  output directory for trimmed reads  (required)
       -p              trim each run in parallel           
       -t <int>        number of threads                   (default = 4)
                                                           
EXAMPLE(S):
      trim-reads.sh -a user@example.com -p -t 8 -i /path/to/raw_reads -o /path/to/trimmed_reads/outdir /path/to/input.txt
```

## Building a Reads List

```
PROGRAM: build-reads-list.sh

DESCRIPTION:
      Uses the input.processed.txt (produced by check-reads.sh) and builds a reads list for RNA-Bloom.
      
USAGE(S):
      build-reads-list.sh [-a <address>] [-h] [-s] -i <input directory> <input reads TXT file>
      
OPTION(S):
       -a <address>    email address for alerts                           
       -h              show help menu                                     
       -i <directory>  input directory (i.e. directory of trimmed reads)  (required)
       -s              strand-specific library construction               (default = false)
                                                                          
EXAMPLE(S):
      build-reads-list.sh -a user@example.com -s -i /path/to/trimmed_reads/outdir input.txt
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
      run-rnabloom.sh [-a <address>] [-d] [-h] [-m <int K/M/G>] [-s] [-t <int>] -o <output directory> <reads list TXT file>
      
OPTION(S):
       -a <address>    email address for alerts              
       -d              debug mode                            (skips RNA-Bloom)
       -h              show help menu                        
       -m <int K/M/G>  allotted memory for Java (e.g. 500G)  
       -n              no redundancy removal                 
       -o <directory>  output directory                      (required)
       -s              strand-specific library construction  (default = false)
       -t <int>        number of threads                     (default = 8)
       -R              do not conduct redundancy removal     (used if low on memory)
                                                             
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
      run-rnabloom.sh -a user@example.com -m 500G -s -t 8 -o /path/to/assembly/outdir /path/to/trimmed_reads/readslist.txt
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
      filter-expression.sh [-a <address>] [-c <dbl>] [-h] [-t <int>] -o <output directory> -r <reference transcriptome (assembly)> <readslist TXT file>
      
OPTION(S):
       -a <address>     email alert                         
       -c <dbl>         TPM cut-off                         (default = 1.0)
       -h               show this help menu                 
       -o <directory>   output directory                    (required)
       -r <FASTA file>  reference transcriptome (assembly)  (required)
       -t <int>         number of threads                   (default = 2)
                                                            
EXAMPLE(S):
      filter-expression.sh -a user@example.com -c 1.0 -s -t 8 -o /path/to/filtering/outdir -r /path/to/assembly/rnabloom.transcripts.all.fa /path/to/trimmed_reads/readslist.txt
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
      translate.sh [-a <address>] [-h] -o <output directory> <input FASTA file>
      
OPTION(S):
       -a <address>    email address for alerts  
       -h              show this help menu       
       -o <directory>  output directory          (required)
                                                 
EXAMPLE(S):
      translate.sh -a user@example.com -o /path/to/translation/outdir /path/to/filtering/rnabloom.transcripts.filtered.fa
```

## Homology Search

```
PROGRAM: run-jackhmmer.sh

DESCRIPTION:
       Runs jackhmmer from the HMMER package to find AMPs via homology search of protein sequences.
       Requires $ROOT_DIR/amp_seqs/amps.$CLASS.prot.combined.faa file.
       
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
      run-jackhmmer.sh [-a <address>] [-e <E-value>] [-h] [-s <0 to 1>] [-t <int>] -o <output directory> <input FASTA file>
      
OPTION(S):
       -a <address>    email address for alerts                   
       -e <E-value>    E-value threshold                          (default = 1e-5)
       -h              show this help menu                        
       -o <directory>  output directory                           (required)
       -s <0 to 1>     CD-HIT global sequence similarity cut-off  (default = 1.00)
       -t <int>        number of threads                          (default = 8)
                                                                  
EXAMPLE(S):
      run-jackhmmer.sh -a user@example.com -e 1e-3 -s 0.90 -t 8 -o /path/to/homology/outdir /path/to/translation/rnabloom.transcripts.filtered.transdecoder.faa
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
         - CLEAVE_LEN_NR.DONE or CLEAVE_LEN_NR.FAIL
       
       EXIT CODES:
       -----------
         - 0: successfully completed
         - 1: general error
         - 2: cleavage failed
         - 3: length filtering failed
         - 4: redundancy removal failed
       
       For more information on ProP: https://services.healthtech.dtu.dk/service.php?ProP-1.0
       
USAGE(S):
      cleave.sh [-a <address>] [-c] [-d] [-h] -o <output directory> <input FASTA file>
      
OPTION(S):
       -a <address>    email address for alerts                                     
       -c              allow consecutive (i.e. adjacent) segments to be recombined  
       -d              debug mode (skips running ProP)                              
       -h              show this help menu                                          
       -o <directory>  output directory                                             (required)
                                                                                    
EXAMPLE(S):
      cleave.sh -a user@example.com -c -o /path/to/cleavage/outdir /path/to/homology/jackhmmer.nr.faa
```

## AMPlify

```
PROGRAM: run-amplify.sh

DESCRIPTION:
       Predicts AMP vs. non-AMP from the peptide sequence using AMPlify.
       
       OUTPUT:
       -------
         - amps.final.faa
         - AMPlify_results.final.tsv
       
       EXIT CODES:
       -----------
         - 0: successfully completed
         - 1: general errors
         - 2: AMPlify failed
       
       For more information on AMPlify: https://github.com/bcgsc/amplify
       
USAGE(S):
      run-amplify.sh [-a <address>] [-c <int>] [-d] [-f] [-h] [-l <int>] [-s <3.0103 to 80>] [-t <int>] -o <output directory> <input FASTA file>
      
OPTION(S):
       -a <address>       email address for alerts                                                                  
       -c <int>           charge cut-off (multiple accepted for sweeps) [i.e. keep charge(sequences >= int]         (default = 2, 4, 6, 8)
       -d                 downstream filtering only                                                                 (skips running AMPlify)
       -e <str>           explicitly force final AMPs to be specified cut-offs [overrides -f, -F]                   (default = AMP::, e.g. Score:Length:Charge, AMP:Length:Charge, AMP::)
       -f                 force final AMPs to be the least number of non-zero AMPs*                                 
       -F                 force final AMPs to be those passing the most lenient cut-offs [overrides -f]             
       -h                 show this help menu                                                                       
       -l <int>           length cut-off (multiple accepted for sweeps) [i.e. keep len(sequences) <= int]           (default = 50, 30)
       -o <directory>     output directory                                                                          (required)
       -s <3.0103 to 80>  AMPlify score cut-off (multiple accepted for sweeps) [i.e. keep score(sequences) >= dbl]  (default = 10, 7, 5 or 7, 5, 4)
       -t <int>           number of threads                                                                         (default = all)
       -T                 stop after obtaining AMPlify TSV file                                                     
                                                                                                                    
EXAMPLE(S):
       run-amplify.sh -a user@example.com -c 2 -l 30 -l 50 -s 10 -s 7 -t 8 -o /path/to/amplify/outdir /path/to/cleavage/cleaved.mature.len.rmdup.nr.faa
       run-amplify.sh -a user@example.com -c 2 -l 30 -l 50 -s 10 -s 7 -e 10:30:2 -t 8 -o /path/to/amplify/outdir /path/to/cleavage/cleaved.mature.len.rmdup.nr.faa
       run-amplify.sh -a user@example.com -c 2 -l 30 -l 50 -s 10 -s 7 -e AMP:30:2 -t 8 -o /path/to/amplify/outdir /path/to/cleavage/cleaved.mature.len.rmdup.nr.faa
       
*i.e. if filtering by score >= 10, length <= 30, and charge >= 2 yields zero AMPs, then score >= 10, length <= 50, and charge >= 2 will be used for the next step of the pipeline, etc.
```

## Annotation

```
PROGRAM: run-entap.sh

DESCRIPTION:
       Runs the EnTAP annotation pipeline.
       For more information: https://entap.readthedocs.io/en/latest/introduction.html
       
USAGE(S):
      run-entap.sh [-a <address>] [-h] [-t <int>] -i <input FASTA file> -f <input TSV file> -o <output directory> <database DMND file(s)>
      
OPTION(S):
       -a <address>    email address for alerts  
       -f <file>       input TSV file            (required)
       -h              show this help menu       
       -i <file>       input FASTA file          (required)
       -o <directory>  output directory          (required)
       -t <int>        number of threads         (default = 8)
                                                 
EXAMPLE(S):
      run-entap.sh -a user@example.com -t 8 -o /path/to/annotation/outdir -i /path/to/amplify/amps.final.faa -f /path/to/amplify/AMPlify_results.final.tsv nr.dmnd uniprot.dmnd
```

## Exonerate

```
PROGRAM: exonerate.sh

DESCRIPTION:
       Uses Exonerate to remove known AMP sequences. Known AMP sequences are:
       - amp_seqs/amps.$CLASS.prot.precursor.faa
       - amp_seqs/amps.$CLASS.prot.mature.faa
       
USAGE(S):
    exonerate.sh [-a <address>] [-h] -o <output directory> <query FASTA file> [annotation TSV file]
    
OPTION(S):
     -a <address>    email address for alerts  
     -h              show this help menu       
     -o <directory>  output directory          (required)
                                               
EXAMPLE(S):
    exonerate.sh -a user@example.com -o /path/to/exonerate/outdir /path/to/annotation/amps.final.annotated.faa /path/to/annotation/final_annotation.final.tsv
```

## SABLE

```
PROGRAM: run-sable.sh

DESCRIPTION:
      Takes a protein FASTA file as input and predicts a secondary structure and RSA score.
      
USAGE(S):
      run-sable.sh [-a <address>] [-h] [-t <int>] -o <output directory> <protein FASTA file> <protein TSV file>
      
OPTION(S):
       -a <address>    email address for alert  
       -h              show this help menu      
       -o <directory>  output directory         (required)
       -t <INT>        number of threads        (default = 8)
                                                
EXAMPLE(S):
      run-sable.sh -o /path/to/sable/outdir /path/to/exonerate/amps.exonerate.some_none.nr.faa  /path/to/exonerate/final_annotation.tsv
```

## Extras

### Cluster

```
PROGRAM: cluster.sh

DESCRIPTION:
       Selects AMPs for synthesis by SpeciesCount, TopInsect, and TopAMPlifyCluster.
       
       OUTPUT:
       -------
         - AMPsForSynthesis.tsv
         - OneEachCluster.tsv
         - ThreeEachCluster.tsv
       
       EXIT CODES:
       -----------
         - 0: successfully completed
         - 1: general errors
       
       
USAGE(S):
      cluster.sh [-o <outdir>] [-c <int>] [-i <int>] [-C <int>] [-s <float>] [-n <int>] [-r <int>] <final annotation directory paths>
      
OPTION(S):
       -h              Show this help menu                                  
       -o <directory>  Output directory                                     
       -c <int>        Species count (at least) threshold for SpeciesCount  (default = 3)
       -i <int>        Number of insect sequences to select for TopInsect   (default = 30)
       -C <int>        Species count (at most) thresold for TopInsect       (default = 1)
       -s <float>      AMPlify score threshold for TopInsect                (default = 20)
       -n <int>        Number of sequences to select for TopAMPlifyCluster  (default = 30)
       -r <int>        Number of arginines that is too hard to synthesize   (default = 5)
```

### BLAST

```
PROGRAM: blast.sh

DESCRIPTION:
       Characterizes the novelty of AMPs using BLASTp.
       
       OUTPUT:
       -------
         - amps.blast.summary.novel.final.tsv
         - amps.blast.summary.known.final.tsv
       
       EXIT CODES:
       -----------
         - 0: successfully completed
         - 1: general errors
       
       
USAGE(S):
          blast.sh [-o <outdir>] [-t <int>] -f <rAMPage AMPlify TSV> -d <preformatted BLAST nr database> <AMP FASTA file>
          
OPTION(S):
           -b <BLAST executable>  Path to BLAST executable if not in PATH                                                                 
           -d <database>          Pre-fromatted BLAST nr database          (e.g. /path/to nr)                                             
           -f <TSV file>          rAMPage AMPlify TSV                      (NOTE: Must be rAMPage's AMPlify output for headers to match)  
           -h                     Show this help menu
           -o <directory>         Output directory 
           -t <int>               Number of threads                        (default = 8)    
```