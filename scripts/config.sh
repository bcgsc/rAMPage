#!/usr/bin/env bash

export ROOT_DIR=$(pwd)

if [[ -f $ROOT_DIR/CONFIG.DONE ]]
then
	rm $ROOT_DIR/CONFIG.DONE
fi

## FOR DOWNLOADING METADATA
# export RUN_ESEARCH=$ROOT_DIR/src/edirect/13.8/bin/esearch
# export RUN_EFETCH=$ROOT_DIR/src/edirect/13.8/bin/efetch

## FOR DOWNLOADING READS
export FASTERQ_DUMP=$ROOT_DIR/src/sratoolkit.2.10.5-centos_linux64/bin/fasterq-dump

## FOR TRIMMING READS
export RUN_FASTP=$ROOT_DIR/fastp/0.20.1/bin/fastp

## FOR ASSEMBLY
export RUN_RNABLOOM=$ROOT_DIR/src/RNA-Bloom_v1.3.1/RNA-Bloom.jar
export NTCARD_DIR=$ROOT_DIR/src/ntCard
export MINIMAP_DIR=$ROOT_DIR/src/minimap2-2.17_x64-linux
export JAVA_EXEC=$ROOT_DIR/src/jdk1.8.0_101/jre/bin/java # needs to be at least 1.8
export RUN_CDHIT=$ROOT_DIR/src/cd-hit/4.8.1_1/bin/cd-hit
export RUN_SEQTK=$ROOT_DIR/src/seqtk/1.1/bin/seqtk

## QUANTIFY
export RUN_SALMON=$ROOT_DIR/src/salmon-latest_linux_x86_64/bin/salmon

## TRANSLATE
export TRANSDECODER_LONGORFS=$ROOT_DIR/src/transdecoder/5.5.0/bin/TransDecoder.LongOrfs
export TRANSDECODER_PREDICT=$ROOT_DIR/src/transdecoder/5.5.0/bin/TransDecoder.Predict

## HOMOLOGY SEARCH
export RUN_JACKHMMER=$ROOT_DIR/src/hmmer/3.3.1/bin/jackhmmer

## CLEAVAGE
export RUN_SIGNALP=$ROOT_DIR/src/signalp-3.0/signalp
export RUN_PROP=$ROOT_DIR/src/prop-1.0c/prop

## AMPLIFY
export RUN_AMPLIFY=$ROOT_DIR/src/AMPlify-1.0.0/src/AMPlify.py

## SABLE
export RUN_SABLE=$ROOT_DIR/src/sable_v4_distr/run.sable
export BLAST_DIR=$ROOT_DIR/src/blast/2.10.0/bin

touch $ROOT_DIR/CONFIG.DONE
