#!/bin/bash
set -euo pipefail
PROGRAM=$(basename $0)

function get_help() {
	echo "DESCRIPTION:" 1>&2
	echo -e "\
		\tParses the raw SABLE output into a TSV file.\n \
		" | column -s $'\t' -t 1>&2
	echo 1>&2

	echo "USAGE(S):" 1>&2
	echo -e "\
		\t$PROGRAM [OPTIONS] <SABLE Output TXT file>\n \
		" | column -s $'\t' -t 1>&2
	echo 1>&2

	echo "OPTION(S):" 1>&2
	echo -e "\
		\t-h\tshow this help menu\n \
		" | column -s $'\t' -t 1>&2
	echo 1>&2
	exit 1
}

while getopts :h opt
do
	case $opt in
		h) get_help;;
		\?) echo "ERROR: Invalid option: -$opt" 1>&2; printf '%.0s=' $(seq $(tput cols)) 1>&2; echo 1>&2; get_help;;
	esac
done

shift $((OPTIND-1))

infile=$(realpath $1)
if [[ ! -s $infile ]]
then
	if [[ ! -f $infile ]]
	then
		echo "ERROR: Input file $infile does not exist." 1>&2; printf '%.0s=' $(seq $(tput cols)) 1>&2; echo 1>&2; get_help
	else
		echo "ERROR: Input file $infile is empty." 1>&2; printf '%.0s=' $(seq $(tput cols)) 1>&2; echo 1>&2; get_help
	fi
fi

outfile=$(dirname $infile)/sable_output.tsv
echo -e "Sequence ID\tSequence\tStructure\tStructure Confidence\tRSA\tRSA Confidence\tAlpha Helix\tLongest Helix\tBeta Strand\tLongest Strand" > $outfile
while read line
do 
	seqname=$(echo "$line" | awk '{print $2}')
	read sequence
	read structure
	read str_conf
	read rsa
	read rsa_conf

	ss=$($ROOT_DIR/scripts/longest-ss.py "$structure")
	echo -e "$seqname\t$sequence\t$structure\t${str_conf}\t${rsa}\t${rsa_conf}\t${ss}" >> $outfile
done < $infile
