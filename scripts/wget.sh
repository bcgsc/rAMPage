#!/bin/bash
set -uo pipefail

PROGRAM=$(basename $0)

function get_help() {
	# DESCRIPTION
	echo "DESCRIPTION:" 1>&2
	echo -e "\
		\tUsing wget, gets draft assemblies given accession numbers.\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2 

	# USAGE
	echo "USAGE(S):" 1>&2
	echo -e "\
		\t$PROGRAM [OPTIONS] <OUTPUT DIRECTORY> <SPECIES> <ACCESSION> <tsa OR wgs>\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	# OPTIONS
	echo "OPTION(S):" 1>&2
	echo -e "\
		\t-h\tshow this help menu\n \
		" | column -s$'\t' -t 1>&2
	exit 1
}
while getopts :h opt
do
	case $opt in 
		h) get_help;;
		\?) echo "ERROR: Invalid option: -$OPTARG" 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2; get_help;;
	esac
done

shift $((OPTIND-1))
if [[ "$#" -eq 0 ]]
then
	get_help
fi

if [[ "$#" -ne 4 ]]
then
	echo "ERROR: Incorrect number of arguments." 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2
	get_help
fi

outdir=$1
species=$2
accession=$3
assembly=$4

# process accession to the short version
accession=$(echo "$accession" | sed 's/0\+\.[0-9]//')

len_accession=$(echo -n "$accession" | wc -m)
if [[ "$len_accession" -eq 4 ]]
then
	letter=${accession:0:1}
	letter=${letter^}
else
	letter=${accession:0:3}
	letter=${letter^^}
fi
logfile=$outdir/${assembly}.${species}.wget.log
url="ftp://ftp.ncbi.nlm.nih.gov/genbank/${assembly}/${letter}/${assembly}.${accession}.*.gz"

# download until successful
echo "Downloading draft assembly for ${species}..." > $logfile

wget --no-remove-listing -P $outdir -a $logfile $url
code=$?
while [[ "$code" -ne 0 ]]
do
	echo "Exit code: $code" >> $logfile	
	echo "Downloaded failed. Trying again..." >> $logfile

	wget --no-remove-listing -P $outdir -a $logfile $url
	code=$?
done
echo "Download successful!" >> $logfile
# concatenate the files
files=( fsa_nt.gz fsa_aa.gz gnp.gz gbff.gz )

for i in "${files[@]}"
do
	if [[ -e $outdir/${assembly}.${accession}.1.${i} ]]
	then
		echo "Concatenating .${i} files..." >> $logfile
		if [[ "$i" == ".gbff.gz" ]]
		then
			cat $outdir/${assembly}.${accession}.?.${i} > $outdir/${assembly}.${species}.${i} &
		else
			cat $outdir/${assembly}.${accession}.*.${i} > $outdir/${assembly}.${species}.${i} &
		fi
	fi
done

wait

for i in "${files[@]}"
do
	if [[ -e $outdir/${assembly}.${accession}.1.${i} ]]
	then
		echo "Removing .${i} files..." >> $logfile
		rm $outdir/${assembly}.${accession}.?.${i} &
	fi
done

wait
if [[ "$assembly" == "wgs" ]]
then
	if [[ -e $outdir/${assembly}.${species}.fsa_nt.gz ]]
	then
		echo "Calculating stats..." >> $logfile
		abyss-fac -j $outdir/${assembly}.${species}.fsa_nt.gz > $outdir/${assembly}.${species}.fac.jira &
	fi

	if [[ -e $outdir/${assembly}.${accession}.mster.gbff.gz ]]
	then
		mv $outdir/${assembly}.${accession}.mstr.gbff.gz $outdir/${assembly}.${species}.mstr.gbff.gz &
	fi

	wait
fi
