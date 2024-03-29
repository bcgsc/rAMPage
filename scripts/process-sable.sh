#!/usr/bin/env bash
set -euo pipefail
FULL_PROGRAM=$0
PROGRAM=$(basename $FULL_PROGRAM)
# args="$FULL_PROGRAM $*"

if [[ "$PROGRAM" == "slurm_script" ]]; then
	FULL_PROGRAM=$(scontrol show job $SLURM_JOBID | awk '/Command=/ {print $1}' | awk -F "=" '{print $2}')
	PROGRAM=$(basename ${FULL_PROGRAM})

fi
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
		\t$PROGRAM [-h] <SABLE query FASTA file> <SABLE Output TXT file>\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-h\tshow this help menu\n \
		" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM /path/to/sable/OUT_SABLE_graph /path/to/exonerate/final_annotation.tsv\n \
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
if [[ "$#" -ne 2 ]]; then
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

if [[ ! -v ROOT_DIR ]]; then
	print_error "ROOT_DIR is unbound. Please export ROOT_DIR=/path/to/rAMPage/GitHub/directory."
fi

fasta=$(realpath $1)
if [[ ! -s $fasta ]]; then
	if [[ ! -f $fasta ]]; then
		print_error "Input file $fasta does not exist."
	else
		print_error "Input file $fasta is empty!"
	fi
fi
infile=$(realpath $2)
# 6 check input files
if [[ ! -s $infile ]]; then
	if [[ ! -f $infile ]]; then
		print_error "Input file $infile does not exist."
	else
		print_error "Input file $infile is empty!"
	fi
fi

outdir=$(dirname $infile)
outfile=$outdir/SABLE_results.tsv
cp $fasta $outdir/amps.final.faa

echo -e "Sequence_ID\tSequence\tStructure\tStructure Confidence\tRSA\tRSA Confidence" >$outfile

while read line; do
	seqname=$(echo "$line" | awk '{print $2}')
	read sequence
	read structure
	read str_conf
	read rsa
	read rsa_conf
	echo -e "$seqname\t$sequence\t$structure\t$str_conf\t$rsa\t$rsa_conf" >>$outfile
	sed -i "/>${seqname} / s/$/ SS=${structure}/" $outdir/amps.final.faa
done <$infile
