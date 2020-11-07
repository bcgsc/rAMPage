#!/bin/bash

## WORKING DIR where pipeline is extracted
## double hashtags are commented out old code
## single hashtags are lines that needd to be uncommented for the rest of the pipeline after assembly

export ROOT_DIR=$(pwd)

if [[ -f $ROOT_DIR/CONFIG.DONE ]]
then
	rm $ROOT_DIR/CONFIG.DONE
fi

## FOR DOWNLOADING METADATA
export RUN_ESEARCH=/gsc/btl/linuxbrew/bin/esearch
export RUN_EFETCH=/gsc/btl/linuxbrew/bin/efetch

## FOR DOWNLOADING READS
export FASTERQ_DUMP=$ROOT_DIR/src/sratoolkit.2.10.5-centos_linux64/bin/fasterq-dump

## FOR TRIMMING READS
export RUN_FASTP=/gsc/btl/linuxbrew/bin/fastp

## FOR ASSEMBLY
## export RUN_RNABLOOM=$(realpath $ROOT_DIR/src/RNA-Bloom/RNA-Bloom.jar)
export RUN_RNABLOOM=$ROOT_DIR/src/RNA-Bloom_v1.3.1/RNA-Bloom.jar
export NTCARD_DIR=$ROOT_DIR/src/ntCard
export MINIMAP_DIR=/home/kmnip/programs/minimap2-2.17_x64-linux
export JAVA_EXEC=/home/kmnip/jdk1.8.0_101/jre/bin/java # needs to be at least 1.8
export RUN_CDHIT=/gsc/btl/linuxbrew/bin/cd-hit
export RUN_SEQTK=/gsc/btl/linuxbrew/bin/seqtk

## QUANTIFY
export RUN_SALMON=$ROOT_DIR/src/salmon-latest_linux_x86_64/bin/salmon

## FOR ANNOTATION
## export RUN_ENTAP=$(realpath $ROOT_DIR/src/EnTAP/EnTAP)
## export RUN_DIAMOND=/projects/btl/dlin/src/diamond
## export RUN_DIAMOND=/gsc/btl/linuxbrew/bin/diamond
## export RUN_INTERPROSCAN=/projects/spruceup_scratch/dev/Src/my_interproscan/interproscan-5.30-69.0/interproscan.sh
## export TRANSDECODER_LONGORFS=/projects/btl/dlin/src/miniconda3/bin/TransDecoder.LongOrfs
export TRANSDECODER_LONGORFS=/gsc/btl/linuxbrew/bin/TransDecoder.LongOrfs
export TRANSDECODER_PREDICT=/gsc/btl/linuxbrew/bin/TransDecoder.Predict
## export TRANSDECODER_PREDICT=/projects/btl/dlin/src/miniconda3/bin/TransDecoder.Predict
export RUN_TRANSEQ=/gsc/btl/linuxbrew/bin/transeq
export RUN_JACKHMMER=/gsc/btl/linuxbrew/bin/jackhmmer

## CLEAVAGE
if [[ "$ROOT_DIR" == *saninta* ]]
then
	export RUN_PROP=/projects/amp/peptaid/src/prop-1.0c/prop
	export RUN_SIGNALP=/projects/amp/peptaid/src/signalp-3.0/signalp
else
	export RUN_SIGNALP=$ROOT_DIR/src/signalp-3.0/signalp
	export RUN_PROP=$ROOT_DIR/src/prop-1.0c/prop
fi

## SABLE
export RUN_SABLE=$ROOT_DIR/src/sable_v4_distr/run.sable
export BLAST_BIN=/gsc/btl/linuxbrew/Cellar/blast/2.10.0/bin

## AMPLIFY
export RUN_AMPLIFY=$ROOT_DIR/src/AMPlify-1.0.0/src/AMPlify.py
touch $ROOT_DIR/CONFIG.DONE
