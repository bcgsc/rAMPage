#!/usr/bin/env bash
set -euo pipefail
PROGRAM=$(basename $0)

# 1 - get_help function
function get_help() {
	{
		# DESCRIPTION
		echo "DESCRIPTION:"
		echo -e "\
		\tUses the input.txt and builds a reads list for RNA-Bloom.\n \
		" | column -s $'\t' -t -L

		# USAGE
		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] <input.txt>\n \
		" | column -s $'\t' -t -L

		# OPTIONS
		echo "OPTION(S):"
		echo -e "\
		\t-h\tshow help menu\n \
		\t-i <directory>\tinput directory (i.e. directory of trimmed reads)\n \
		\t-s\tstranded library prep\n \
		" | column -s $'\t' -t -L

		# EXAMPLE
		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -s input.txt\n \
		" | column -s $'\t' -t -L

	} 1>&2

	exit 1
}

# 2 - print_error function
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
	print_error "input file $(realpath $1) is empty."
fi

# check that outdir is provided
if [[ -z $indir ]]; then
	print_error "Required argument -i <input directory> missing."
fi

if [[ ! -d $indir ]]; then
	print_error "Given input directory does not exist."
fi

workdir=$(dirname $indir)

# Allows for use of -s to set strandedness independently of rAMPage.sh which creates *.LIB files
if [[ "$stranded" = false ]]; then
	if [[ -f $workdir/STRANDED.LIB ]]; then
		stranded=true
	elif [[ -f $workdir/NONSTRANDED.LIB ]]; then
		stranded=false
	fi
fi

# 7 - remove status files
rm -f $indir/READSLIST.DONE
rm -f $indir/readslist.txt

# 8 - print env details
echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)\n" 1>&2

echo -e "PATH=$PATH\n" 1>&2

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

input=$(realpath $1)

num_cols=$(awk '{print NF}' $input | sort -u)

if [[ "$num_cols" -eq 2 ]]; then
	paired=false
elif [[ "$num_cols" -eq 3 ]]; then
	paired=true
else
	print_error "There are too many columns in the input TXT file."
fi

if [[ "$paired" = true ]]; then
	while read pool read1 read2; do
		run=$(basename $read1 | sed 's/_\?[1-2]\?\.fastq\.gz//')
		read1_trimmed=$(find $(basename $indir) -maxdepth 1 -name "${run}_1.paired.fastq.gz")
		read2_trimmed=$(find $(basename $indir) -maxdepth 1 -name "${run}_2.paired.fastq.gz")

		if [[ "$stranded" = true ]]; then
			echo "$pool $read2_trimmed $read1_trimmed" >>$indir/readslist.txt
		else
			echo "$pool $read1_trimmed $read2_trimmed" >>$indir/readslist.txt
		fi
	done <$input
else
	while read pool read1; do
		run=$(basename $read1 | sed 's/_\?[1-2]\?\.fastq\.gz//')
		read1_trimmed=$(find $(basename $indir) -maxdepth 1 -name "${run}.fastq.gz")
		echo "$pool $read1_trimmed" >>$indir/readslist.txt
	done <$input

fi

echo -e "END: $(date)\n" 1>&2

echo "STATUS: DONE." 1>&2
touch $indir/READSLIST.DONE

if [[ "$email" = true ]]; then
	org=$(echo "$indir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
	echo "$indir" | mail -s "${org^}: STAGE 04: MAKING A READS LIST: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
