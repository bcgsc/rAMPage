#!/usr/bin/env bash
set -euo pipefail
PROGRAM=$(basename $0)
args="$PROGRAM $*"
# 0 - table function
function table() {
	if column -L <(echo) &>/dev/null; then
		cat | column -s $'\t' -t -L
	else
		cat | column -s $'\t' -t
		echo
	fi
}
# 1 - get_help
function get_help() {
	{
		echo "DESCRIPTION:"
		echo -e "\
		\tParses the raw SABLE output into a TSV file.\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] <SABLE query FASTA file> <SABLE Output TXT file> <AMPlify TSV file>\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-h\tshow this help menu\n \
		" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM /path/to/sable/OUT_SABLE_graph /path/to/amplify/AMPlify.final.tsv\n \
		" | table
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
if [[ "$#" -ne 3 ]]; then
	print_error "Incorrect number of arguments."
fi

# {
# 	echo "HOSTNAME: $(hostname)"
# 	echo -e "START: $(date)\n"
#
# 	echo -e "PATH=$PATH\n"
#
# 	echo "CALL: $args (wd: $(pwd))"
# } 1>&2

fasta=$(realpath $1)
if [[ ! -s $fasta ]]; then
	if [[ ! -f $fasta ]]; then
		print_error "Input file does not exist."
	else
		print_error "Input file is empty!"
	fi
fi

infile=$(realpath $2)
# 6 check input files
if [[ ! -s $infile ]]; then
	if [[ ! -f $infile ]]; then
		print_error "Input file does not exist."
	else
		print_error "Input file is empty!"
	fi
fi

amplify_tsv=$(realpath $3)
if [[ ! -s $amplify_tsv ]]; then
	if [[ ! -f $amplify_tsv ]]; then
		print_error "Input file does not exist."
	else
		print_error "Input file is empty!"
	fi
elif [[ "$amplify_tsv" != *.tsv ]]; then
	print_error "Input file is not a TSV file."
fi

outdir=$(dirname $infile)
outfile=$outdir/SABLE_results.tsv

echo -e "Sequence ID\tSequence\tAnnotation\tScore\tCharge\tStructure\tStructure Confidence\tRSA\tRSA Confidence\tAlpha Helix\tLongest Helix\tBeta Strand\tLongest Strand" >$outfile
while read line; do
	seqname=$(echo "$line" | awk '{print $2}')
	read sequence
	read structure
	read str_conf
	read rsa
	read rsa_conf
	updated_seqname=$(echo "$seqname" | sed 's/-novel//' | sed 's/-annotated//' | sed 's/-known//')
	# get AMPlify score and charge
	score=$(awk -F "\t" -v var=$updated_seqname '/var\t/ {print $4}' $amplify_tsv)
	charge=$(awk -F "\t" -v var=$updated_seqname '/var\t/ {print $6}' $amplify_tsv)
	annotation=$(grep -F "${seqname} " $fasta | grep -Eo "exonerate=\S+|diamond=\S+" | tr ' ' '\n' | cut -f2 -d= | tr '\n' ' ' || true)
	if [[ -z $annotation ]]; then
		annotation=" "
	fi
	ss=$($ROOT_DIR/scripts/longest-ss.py "$structure")
	echo -e "$seqname\t$sequence\t$annotation\t$score\t$charge\t$structure\t${str_conf}\t${rsa}\t${rsa_conf}\t${ss}" >>$outfile
done <$infile
