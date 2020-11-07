#!/bin/bash

set -uo pipefail

PROGRAM=$(basename $0)

function get_help() {
	# DESCRIPTION
	echo "DESCRIPTION:" 1>&2
	echo -e "\
		\tDownloads the reads for one single accession, using fasterq-dump.\n \
		\tFor more information: https://github.com/ncbi/sra-tools/wiki/HowTo:-fasterq-dump\n \
		" | column -s $'\t' -t 1>&2
	echo 1>&2

	# USAGE
	echo "USAGE(S):" 1>&2
	echo -e "\
		\t$PROGRAM [OPTIONS] -o <output directory> <SRR accession>\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	# OPTIONS
	echo "OPTION(S):" 1>&2
	echo -e "\
		\t-a <address>\temail alert\n \
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n \
		\t-t <int>\tnumber of threads\t(default = 2)\n \
		" | column -s$'\t' -t 1>&2
	exit 1
}

threads=2
custom_threads=false
email=false
while getopts :a:ho:t: opt
do
	case $opt in
		a) address="$OPTARG"; email=true;;
		h) get_help;;
		o) outdir="$(realpath $OPTARG)";;
		t) threads="$OPTARG"; custom_threads=true;;
		\?) echo "ERROR: Invalid option: -$OPTARG" 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2; get_help;;
	esac
done

shift $((OPTIND-1))

if [[ "$#" -eq 0 ]]
then
	get_help
fi

if [[ "$#" -ne 1 ]]
then
	echo "ERROR: Incorrect number of arguments." 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2
	get_help
fi

if [[ "$1" == *RR* ]]
then
	accession=$1
else
	echo "ERROR: Input is not an SRR accession." 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2
	get_help
fi

logfile=$outdir/${accession}.log
templog=$outdir/${accession}_temp.log

if [[ -e "$logfile" ]]
then
	rm $logfile
fi
temp=/dev/shm
function set_temp() {
	if [[ "$(df -h $temp | tail -n1 | awk '{print $5}' | tr -d '%')" -eq 100 ]]
	then
		temp=/var/tmp
		if [[ "$(df -h $temp | tail -n1 | awk '{print $5}' | tr -d '%')" -eq 100 ]]
		then
				echo "Out of temporary disk space in $temp while downloading ${accession} to $outdir" >> $logfile
			if [[ "$email" = true ]]
			then
				echo "Out of temporary disk space in $temp while downloading ${accession} to $outdir" | mail -s "PGID terminated." $address
			fi
			kill -SIGTERM -- -$(ps -o pgid $$ | tail -n 1 | tr -d ' ')
		fi
	fi

	if [[ "$(df -h $ROOT_DIR | tail -n1 | awk '{print $5}' | tr -d '%')" -eq 100 ]]
	then
			echo "Out of disk space in $ROOT_DIR while downloading ${accession} to $outdir" >> $logfile
		if [[ "$email" = true ]]
		then
			echo "Out of disk space in $ROOT_DIR while downloading ${accession} to $outdir" | mail -s "PGID terminated" $address	
		fi
		kill -SIGTERM -- -$(ps -o pgid $$ | tail -n 1 | tr -d ' ')
	fi
}

set_temp

echo "First attempt at ${accession}..." >> $logfile
echo -e "Temporary disk space: $temp\n" >> $logfile

# get reads
echo -e "PATH=$PATH\n" >> $logfile

echo "PROGRAM: $(command -v $FASTERQ_DUMP)" &>> $logfile
echo -e "VERSION: $($FASTERQ_DUMP --version | awk '/version/ {print $NF}')\n" &>> $logfile
echo -e "COMMAND: $FASTERQ_DUMP -x -3 -e $threads -p -f -t $temp  -O $outdir $accession &> $templog\n" >> $logfile
$FASTERQ_DUMP -x -3 -e $threads -p -f -t $temp  -O $outdir $accession &> $templog
code=$?
scratch=$(awk '/scratch-path/{print $3}' $templog | tr -d \')
rm -rf $scratch
while [[ "$(grep -c "connection busy" $templog)" -gt 0 || "$code" -ne 0 || "$(grep -c "invalid" $templog)" -gt 0 ]]
do
	set_temp

	echo "FAILED! Attempting to redownload ${accession}..." >> $logfile
	echo "Temporary disk space: $temp" >> $logfile
	# get reads
	
	echo -e "COMMAND: $FASTERQ_DUMP -x -3 -e $threads -p -f -t $temp  -O $outdir $accession &> $templog\n" >> $logfile
	$FASTERQ_DUMP -x -3 -e $threads -p -f -t $temp  -O $outdir $accession &> $templog
	code=$?	
	scratch=$(awk '/scratch-path/{print $3}' $templog | tr -d \')
	rm -rf $scratch
	echo "Exit code: $code" >> $logfile
done

cat $templog >> $logfile
rm $templog

echo -e "SUCCESS! ${accession} downloaded.\n" >> $logfile

if command -v pigz &> /dev/null
then
	if [[ "$custom_threads" = true ]]
	then
		compress="pigz -p $threads"
	else
		compress=pigz
	fi
else
	compress=gzip
fi

echo "Compressing ${accession}..." >> $logfile
${compress} -f $outdir/$accession*.fastq
echo "Finished compressing ${accession}." | tee -a $logfile 1>&2
