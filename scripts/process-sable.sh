#!/bin/bash
set -euo pipefail
PROGRAM=$(basename $0)

# 1 - get_help
function get_help() {
	{
		echo "DESCRIPTION:" 1>&2
		echo -e "\
		\tParses the raw SABLE output into a TSV file.\n \
		" | column -s $'\t' -t -L

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] <SABLE Output TXT file>\n \
		" | column -s $'\t' -t -L

		echo "OPTION(S):"
		echo -e "\
		\t-h\tshow this help menu\n \
		" | column -s $'\t' -t -L
	} 1>&2
	exit 1
}

# 2 - print_error
function print_error() {
	{
		message="$1"
		echo "ERROR: $message"
		printf '%.0s=' $(seq 1 $(tput cols))
		echo
		get_help
	} 1>&2
}

# 3 - no arguments given
if [[ "$#" -eq 0 ]]; then
	get_help
fi

# 4 - get options
while getopts :h opt; do
	case $opt in
	h) get_help ;;
	\?)
		print_error "Invalid option: -$OPTARG"
		;;
	esac
done

shift $((OPTIND - 1))

# 5 - incorrect arguments
if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 check input files
if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) is empty."
fi

infile=$(realpath $1)

outfile=$(dirname $infile)/sable_output.tsv
echo -e "Sequence ID\tSequence\tStructure\tStructure Confidence\tRSA\tRSA Confidence\tAlpha Helix\tLongest Helix\tBeta Strand\tLongest Strand" >$outfile
while read line; do
	seqname=$(echo "$line" | awk '{print $2}')
	read sequence
	read structure
	read str_conf
	read rsa
	read rsa_conf

	ss=$($ROOT_DIR/scripts/longest-ss.py "$structure")
	echo -e "$seqname\t$sequence\t$structure\t${str_conf}\t${rsa}\t${rsa_conf}\t${ss}" >>$outfile
done <$infile
