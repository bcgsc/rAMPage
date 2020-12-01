#!/usr/bin/env bash
PROGRAM=$(basename $0)
set -euo pipefail

# 1 - get_help function
function get_help() {
	{
		# DESCRIPTION
		echo "DESCRIPTION:"
		echo -e "\
		\tChecks the input.txt file to make sure the reads are present.\n
		" | column -s $'\t' -t -L

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] <input.txt>\n
		" | column -s $'\t' -t -L

		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail alert\n \
		\t-h\tshow help menu\n \
		\t-t <INT> number of threads (for compression, if needed)\n \
		" | column -s $'\t' -t -L
	} 1>&2
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

# 3 - no arguments
if [[ "$#" -eq 0 ]]; then
	get_help
fi

email=false
custom_threads=false
# 4 -  get opts
while getopts :ha:t: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	h) get_help ;;
	t)
		threads="$OPTARG"
		custom_threads=true
		;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

# 5 - wrong arguments
if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 - check inputs
if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "input file $(realpath $1) is empty."
fi

# 7 remove status files

# 8 - print env

echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)\n" 1>&2
# start_sec=$(date '+%s')

echo -e "PATH=$PATH\n" 1>&2

input=$(realpath $1)

# check that num columns is consistent
if [[ "$(awk '{print NF}' $input | sort -u | wc -l)" -ne 1 ]]; then
	print_error "Inconsistent number of columns."
fi

num_cols=$(awk '{print NF}' $input | sort -u)
if [[ "$num_cols" -eq 2 ]]; then
	paired=false
	touch SINGLE.END
elif [[ "$num_cols" -eq 3 ]]; then
	paired=true
	touch PAIRED.END
else
	print_error "There are too many columns in the input TXT file."
fi

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi
# this script is ONLY run as a part of the Makefile, so it will run in the "working directory" CLASS/SPECIES/TISSUE
mkdir -p raw_reads

# parse through the input txt and copy reads to the raw_reads dir if they aren't already there
if [[ "$paired" = true ]]; then
	while read pool read1 read2; do
		# check if the reads in the given paths exist
		if [[ -s "$(realpath ${read1} 2>/dev/null)" && -s "$(realpath ${read2} 2>/dev/null)" ]]; then
			if [[ ! -s "raw_reads/$(basename ${read1})" ]]; then
				echo "Moving $(basename ${read1}) into $(realpath raw_reads)..." 1>&2
				newname=$(realpath raw_reads/$(basename ${read1}))
				mv ${read1} ${newname}
				sed -i "s|${read1}|${newname}|" $input
			else
				echo "$(basename ${read1}) already in $(realpath raw_reads)..." 1>&2
			fi
			if [[ ! -s "raw_reads/$(basename ${read2})" ]]; then
				echo "Moving $(basename ${read2}) into $(realpath raw_reads)..." 1>&2
				newname=$(realpath raw_reads/$(basename ${read2}))
				mv ${read2} ${newname}
				sed -i "s|${read2}|${newname}|" $input
			else
				echo "$(basename ${read2}) already in $(realpath raw_reads)..." 1>&2
			fi
		else
			print_error "Reads ${read1} and ${read2} in the input file do not exist or are empty."
			exit 1
		fi
	done <$input
else
	while read pool read1; do
		if [[ -s "$(realpath ${read1} 2>/dev/null)" ]]; then
			if [[ ! -s "raw_reads/$(basename ${read1})" ]]; then
				echo "Moving $(basename ${read1}) into $(realpath raw_reads)..." 1>&2a
				newname=$(realpath raw_reads/$(basename ${read1}))
				mv ${read1} ${newname}
				sed -i "s|${read1}|${newname}|" $input

			else
				echo "$(basename ${read1}) already in $(realpath raw_reads)..." 1>&2
			fi
		else
			print_error "Reads ${read1} in the input file do not exist or are empty."
			exit 1
		fi
	done <$input
fi

if command -v pigz &>/dev/null; then
	if [[ "$custom_threads" = true ]]; then
		compress="pigz -p $threads"
	else
		compress=pigz
	fi
else
	compress=gzip
fi

for i in $(realpath raw_reads/*.f*q); do
	${compress} $i
	sed -i "s|${i}|${i}.gz|" $input
done 2>/dev/null

touch raw_reads/READS.DONE
echo -e "\nSTATUS: DONE." 1>&2

if [[ "$email" = true ]]; then
	org=$(realpath raw_reads | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
	realpath raw_reads | mail -s "${org^}: STAGE 02: GETTING READS: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
