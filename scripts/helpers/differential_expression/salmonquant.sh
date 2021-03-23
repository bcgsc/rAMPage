#!/usr/bin/env bash

set -euo pipefail
PROGRAM=$(basename $0)
args="$PROGRAM $*"

# if wrong number arguments given
if [[ "$#" -ne 6 ]]; then
        echo "Incorrect number of arguments"
        echo "Example of usage: ./salmonquant.sh <path/to/refgenome> <paired/unpaired> <stranded/unstranded> <threads> <outdir> <path/to/input.processed.txt>"
  exit 1      
fi

ref=$1
paired=$2
strand=$3
threads=$4
outdir=$5
readlist=$6

# make the output directory if it doesn't exist already
if [ ! -d "$outdir" ]; then
  mkdir "$outdir"
  echo "Creating the output directory $outdir"
  
fi


# index the reference transcriptome
echo "Creating an index from the reference transcriptome..." 1>&2
echo -e "COMMAND: salmon index --transcripts $ref --index $outdir/index --threads $threads &> $outdir/index.log\n" 1>&2
salmon index --transcripts $ref --index $outdir/index --threads $threads &>$outdir/index.log

echo "Quantifying expression..." 1>&2


# assuming that read1 and read2 are in that order in the input.processed.txt
# before you specify stranded/unstranded need to check readlist txt and order of read2 and read1 
# do per replicate

while read case read1 read2; do
        
        if [ ! -d "$outdir/$case" ]; then
                mkdir "$outdir/$case"
                echo "Creating the output directory $outdir/$case"
  
        fi
 
        if [[ $paired = paired ]]; then
                if [[ $strand = stranded ]]; then
                        libtype=ISR
                        echo -e "COMMAND: salmon quant --index $outdir/index --threads $threads -l $libtype -1 $read1 -2 $read2 -o $outdir/$case &> $outdir/$case/quant.log\n" 1>&2
                        salmon quant --index $outdir/index --threads $threads -l $libtype -1 $read1 -2 $read2 -o $outdir/$case &>$outdir/$case/quant.log
                else
                # for unstranded 
                        libtype=IU
                        echo -e "COMMAND: salmon quant --index $outdir/index --threads $threads -l $libtype -1 $read1 -2 $read2 -o $outdir/$case &> $outdir/$case/quant.log\n" 1>&2
                        salmon quant --index $outdir/index --threads $threads -l $libtype -1 $read1 -2 $read2 -o $outdir/$case &>$outdir/$case/quant.log
                fi

        # for unpaired
        else
                if [[ $strand = stranded ]]; then
                        libtype=SR
                else
                        libtype=U
                fi
                echo -e "COMMAND: salmon quant --index $outdir/index --threads $threads -l $libtype -r $read1 -o $outdir/$case &> $outdir/$case/quant.log\n" 1>&2
                salmon quant --index $outdir/index --threads $threads -l $libtype -r $read1 -o $outdir/$case &>$outdir/$case/quant.log
        fi

done < "$readlist"


