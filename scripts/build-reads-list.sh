#!/usr/bin/env bash
set -euo pipefail
FULL_PROGRAM=$0
PROGRAM=$(basename $FULL_PROGRAM)
args="$FULL_PROGRAM $*"

# 0 - table function
function table() {
	if column -L <(echo) &>/dev/null; then
		cat | column -s $'\t' -t -L
	else
		cat | column -s $'\t' -t
		echo
	fi
}

# 1 - get_help function
function get_help() {
	{
		echo -e "PROGRAM: $PROGRAM\n"
		# DESCRIPTION
		echo "DESCRIPTION:"
		echo -e "\
		\tUses the input.processed.txt (produced by check-reads.sh) and builds a reads list for RNA-Bloom.\n \
		" | table

		# USAGE
		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-a <address>] [-h] [-s] -i <input directory> <input reads TXT file>\n \
		" | table

		# OPTIONS
		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail address for alerts\n \
		\t-h\tshow help menu\n \
		\t-i <directory>\tinput directory (i.e. directory of trimmed reads)\t(required)\n \
		\t-s\tstrand-specific library construction\t(default = false)\n \
		" | table

		# EXAMPLE
		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com -s -i /path/to/trimmed_reads input.txt\n \
		" | table

	} 1>&2

	exit 1
}

# 1.5 - print_line function
function print_line() {
	if command -v tput &>/dev/null; then
		end=$(tput cols)
	else
		end=50
	fi
	{
		printf '%.0s=' $(seq 1 $end)
		echo
	} 1>&2
}

# 2 - print_error function
function print_error() {
	{
		echo -e "CALL: $args (wd: $(pwd))\n"
		message="$1"
		echo "ERROR: $message"
		print_line
		get_help
	} 1>&2
}

# 3 - no arguments given
if [[ "$#" -eq 0 ]]; then
	get_help
fi

email=false
indir=""
stranded=false
# 4 - get options
while getopts :ha:i:s opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	h) get_help ;;
	i) indir="$(realpath $OPTARG)" ;;
	s) stranded=true ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

# 5 - wrong arguments given
if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 - check input file(s)
if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) is empty."
fi

# check that outdir is provided
if [[ -z $indir ]]; then
	print_error "Required argument -i <input directory> missing."
fi

if [[ ! -d $indir ]]; then
	print_error "Given input directory does not exist."
fi

if [[ -v STRANDED ]]; then
	# if the env variable is set, override the command line one
	stranded=$STRANDED
fi

if [[ ! -v WORKDIR ]]; then
	workdir=$(dirname $indir)
else
	workdir=$(realpath $WORKDIR)
fi

if [[ ! -v SPECIES ]]; then
	# get species from workdir
	species=$(echo "$workdir" | awk -F "/" '{print $(NF-1)}')
else
	species=$SPECIES
fi
# 7 - remove status files - DO NOT remove the files so time stamp can be used.
rm -f $indir/READSLIST.DONE
rm -f $indir/readslist.txt # needs to be removed because append is used

# 8 - print env details
{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo -e "CALL: $args (wd: $(pwd))\n"
} 1>&2

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

input=$(realpath $1)

if [[ ! -v PAIRED ]]; then
	# if env var not set, infer from input file
	num_cols=$(awk '{print NF}' $input | sort -u)
	if [[ "$num_cols" -eq 2 ]]; then
		paired=false
	elif [[ "$num_cols" -eq 3 ]]; then
		paired=true
	else
		print_error "There are too many columns in the input TXT file."
	fi
else
	paired=$PAIRED
fi
echo -e "Making the reads list for RNA-Bloom...\n" 1>&2
if [[ "$paired" = true ]]; then
	while read pool read1 read2; do
		#		run=$(basename $read1 | sed 's/_\?[1-2]\?\.fastq\.gz//')
		# 		read1_trimmed=$(find $(basename $indir) -maxdepth 1 -name "${run}_1.fastq.gz")
		run1=$(basename $read1)
		run2=$(basename $read2)
		read1_trimmed=$(find $indir -maxdepth 1 -name "${run1}")
		read2_trimmed=$(find $indir -maxdepth 1 -name "${run2}")
		if [[ "$stranded" = true ]]; then
			echo "$pool $read2_trimmed $read1_trimmed" >>$indir/readslist.txt
		else
			echo "$pool $read1_trimmed $read2_trimmed" >>$indir/readslist.txt
		fi
	done <$input
else
	while read pool read1; do
		# run=$(basename $read1 | sed 's/_\?[1-2]\?\.fastq\.gz//')
		run=$(basename $read1)
		read1_trimmed=$(find $indir -maxdepth 1 -name "${run}")
		echo "$pool $read1_trimmed" >>$indir/readslist.txt
	done <$input

fi

echo -e "END: $(date)\n" 1>&2

echo -e "STATUS: DONE.\n" 1>&2
touch $indir/READSLIST.DONE

echo "Output: $indir/readslist.txt" 1>&2

if [[ "$email" = true ]]; then
	# org=$(echo "$indir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
	species=$(echo "$species" | sed 's/^./\u&. /')
	#	echo "$indir" | mail -s "${species^}: STAGE 04: MAKING A READS LIST: SUCCESS" "$address"
	echo "$indir" | mail -s "${species}: STAGE 04: MAKING A READS LIST: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
