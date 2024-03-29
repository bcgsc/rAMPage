#!/usr/bin/env bash
set -euo pipefail
PROGRAM=$(basename $0)
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
	# DESCRIPTION
	{
		echo -e "PROGRAM: $PROGRAM\n"
		echo "DESCRIPTION:"
		echo -e "\
		\tMakes the pooled reads lists for RNA-Bloom. Filters given TSV for relevant information.\n \
		\n \
		\tOUTPUT:\n \
		\t-------\n \
		\t  - reads.txt\n \
		\t  - READSLIST.DONE\n \
		\n \
		\tEXIT CODES:\n \
		\t-----------\n \
		\t  - 0: successfully completed\n \
		\t  - 1: general error\n \
		\n \
		\tFor more information: https://github.com/bcgsc/RNA-Bloom\n \
        " | table

		# USAGE
		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] -d <I/O directory> <metadata TSV file>\n \
        " | table

		# OPTIONS
		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail alert\n \
		\t-d <directory>\tInput directory (trimmed reads) and output directory for reads list\t(required)\n \
		\t-h\tShow this help menu\n \
        " | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -d /path/to/trimmed_reads /path/to/sra/metadata.tsv\n \
    	" | table
	} 1>&2

	exit 1
}
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

dir=""
email=false
# 4 - read options
while getopts :a:d:h opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	d) dir="$(realpath $OPTARG)" ;;
	h) get_help ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

# 5 - wrong number of arguments
if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 - check input files
if [[ -z $dir ]]; then
	print_error "Required argument -d <I/O directory> missing."
fi

if [[ ! -d $dir ]]; then
	print_error "Given directory $dir does not exist."
fi

if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) is empty."
fi

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

# 7 - remove status files
rm -f $dir/READSLIST.DONE

# 8 - print env details
echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)\n" 1>&2

echo -e "PATH=$PATH\n" 1>&2

infile=$(realpath $1)

outfile=$dir/readslist.txt

if [[ ! -v STRANDED ]]; then
	echo -e "\nPlease indicate whether your dataset has stranded or nonstranded library construction:" 1>&2
	echo -e "\te.g. export STRANDED=true\n" 1>&2
	exit 1
else
	stranded=$STRANDED
fi

if [[ ! -v PAIRED ]]; then
	echo "Please indicate whether your dataset has paired or single-end reads:" 1>&2
	echo -e "\te.g. export PAIRED=true\n" 1>&2
	exit 1
else
	paired=$PAIRED
fi

num_cols=$(head -n1 $infile | awk -F $'\t' '{print NF}')
num_rows=$(tail -n +2 $infile | wc -l)

if [[ "$num_cols" -eq 1 ]]; then
	# if there is only one field, do not pool
	if [[ "$paired" = true ]]; then
		if [[ "$stranded" = true ]]; then
			paste -d" " <(for i in $(seq $num_rows); do echo "no_pooling"; done) <(cut -f1 -d $'\t' $infile | tail -n +2 | sed "s|^|$dir/|" | sed 's/$/_2.fastq.gz/') <(cut -f1 -d $'\t' $infile | tail -n +2 | sed "s|^|$dir/|" | sed 's/$/_1.fastq.gz/') >$outfile
		else
			paste -d" " <(for i in $(seq $num_rows); do echo "no_pooling"; done) <(cut -f1 -d $'\t' $infile | tail -n +2 | sed "s|^|$dir/|" | sed 's/$/_1.fastq.gz/') <(cut -f1 -d $'\t' $infile | tail -n +2 | sed "s|^|$dir/|" | sed 's/$/_2.fastq.gz/') >$outfile
		fi
	else
		paste -d" " <(for i in $(seq $num_rows); do echo "no_pooling"; done) <(cut -f1 -d $'\t' $infile | tail -n +2 | sed "s|^|$dir/|" | sed 's/$/.fastq.gz/') >$outfile
	fi
else
	# else, collapse all columns, find the columns that contain unique values
	indices=()
	equal=()
	for j in $(seq 2 $num_cols); do
		num_unique=$(tail -n +2 $infile | cut -f $j -d $'\t' | sed 's/[-_ ][0-9]\+$//g' | sed 's/ *(.\+)//g' | sed 's/;.*$//g' | sort -u | wc -l)
		# to be added to the indices array, the number of unique rows must be > 1 (if equal one, then the whole column is the same
		# if the number of unique rows is < number of rows then, there is some grouping
		if [[ "$num_unique" -gt 1 && "$num_unique" -lt "$num_rows" ]]; then
			indices+=($j)
			# if every entry is unique in the column, store it in equal array
		elif [[ "$num_unique" -eq "$num_rows" ]]; then
			equal+=($j)
		fi
	done

	if [[ "${#indices[@]}" -eq 0 ]]; then
		# if no 'grouping' indices is chosen, check to see if there are equal indices
		# if there are equal indices, pick the last element in the array to act as a single index (the rightmost element should more likely be metadata tissue/treatment)
		if [[ "${#equal[@]}" -ne 0 ]]; then
			num_cols=${equal[-1]}
		fi
		if [[ "$paired" = true ]]; then
			if [[ "$stranded" = true ]]; then
				paste -d" " <(cut -f${num_cols} -d$'\t' $infile | tail -n +2 | sed 's/[-_ ][0-9]\+\t/\t/g' | sed 's/[-_ ][0-9]\+$//g' | sed 's/ *(.\+)//g' | sed 's/;.*\t/\t/g' | sed 's/;.*$//g' | sed 's/[,;\.:]//g' | sed 's/[[:space:]]/_/g') <(cut -f1 -d $'\t' $infile | tail -n +2 | sed "s|^|$dir/|" | sed 's/$/_2.fastq.gz/') <(cut -f1 -d $'\t' $infile | tail -n +2 | sed "s|^|$dir/|" | sed 's/$/_1.fastq.gz/') >$outfile
			else
				paste -d" " <(cut -f${num_cols} -d$'\t' $infile | tail -n +2 | sed 's/[-_ ][0-9]\+\t/\t/g' | sed 's/[-_ ][0-9]\+$//g' | sed 's/ *(.\+)//g' | sed 's/;.*\t/\t/g' | sed 's/;.*$//g' | sed 's/[,;\.:]//g' | sed 's/[[:space:]]/_/g') <(cut -f1 -d $'\t' $infile | tail -n +2 | sed "s|^|$dir/|" | sed 's/$/_1.fastq.gz/') <(cut -f1 -d $'\t' $infile | tail -n +2 | sed "s|^|$dir/|" | sed 's/$/_2.fastq.gz/') >$outfile
			fi
		else
			paste -d" " <(cut -f${num_cols} -d$'\t' $infile | tail -n +2 | sed 's/[-_ ][0-9]\+\t/\t/g' | sed 's/[-_ ][0-9]\+$//g' | sed 's/ *(.\+)//g' | sed 's/;.*\t/\t/g' | sed 's/;.*$//g' | sed 's/[,;\.:]//g' | sed 's/[[:space:]]/_/g') <(cut -f1 -d $'\t' $infile | tail -n +2 | sed "s|^|$dir/|" | sed 's/$/.fastq.gz/') >$outfile
		fi
	else
		if [[ "${#indices[@]}" -gt 1 ]]; then
			filtered=()
			for x in $(seq 0 $((${#indices[@]} - 2))); do
				same=false
				last=false
				for y in $(seq $((x + 1)) $((${#indices[@]} - 1))); do
					differences=$(diff -i -q <(tail -n +2 $infile | cut -f ${indices[x]} -d $'\t' | sed 's/[-_ ][0-9]\+$//g' | sed 's/ *(.\+)//g' | sed 's/;.*$//g') <(tail -n +2 $infile | cut -f ${indices[y]} -d $'\t' | sed 's/[-_ ][0-9]\+$//g' | sed 's/ *(.\+)//g' | sed 's/;.*$//g') || true)
					if [[ -z $differences ]]; then
						if [[ "$y" -eq "$((${#indices[@]} - 1))" ]]; then
							last=true
						else
							last=false
						fi
						same=true
						break
					fi
					if [[ "$y" -eq "$((${#indices[@]} - 1))" ]]; then
						last=true
					else
						last=false
					fi
				done
				if [[ "$same" = false && "$last" = false ]]; then
					# if false, made to end of the loop, store left
					#					echo "Made it through full inner loop. Keeping left."
					filtered+=("${indices[x]}")
				elif [[ "$same" = true && "$last" = true ]]; then
					#					echo "Ran into one identical column. Last iteration of loop, keeping right."
					filtered+=("${indices[y]}")
				elif [[ "$same" = true && "$last" = false ]]; then
					#					echo "Ran into one identical column. Store nothing."
					:
				elif [[ "$same" = false && "$last" = true ]]; then
					#					echo "Made it through full inner loop and is last iteration. Keeping both."
					filtered+=("${indices[x]}" "${indices[y]}")
				fi

			done
			indices=$(echo "${filtered[@]}" | tr ' ' '\n' | sort -nu | tr '\n' ',' | sed 's/,$//')
		else
			indices="${indices[0]}"
		fi
		num_indices=$(echo "$indices" | awk -F "," '{print NF}')
		if [[ "$num_indices" -gt 3 ]]; then
			indices=$(echo "$indices" | awk -F "," 'BEGIN{OFS=","}{print $(NF-2), $(NF-1), $NF}')
		fi
		if [[ "$paired" = true ]]; then
			if [[ "$stranded" = true ]]; then
				paste -d" " <(cut -f${indices} -d$'\t' $infile | tail -n +2 | sed 's/[-_ ][0-9]\+\t/\t/g' | sed 's/[-_ ][0-9]\+$//g' | sed 's/ *(.\+)//g' | sed 's/;.*\t/\t/g' | sed 's/;.*$//g' | sed 's/[,;\.:]//g' | sed 's/[[:space:]]/_/g') <(cut -f1 -d $'\t' $infile | tail -n +2 | sed "s|^|$dir/|" | sed 's/$/_2.fastq.gz/') <(cut -f1 -d $'\t' $infile | tail -n +2 | sed "s|^|$dir/|" | sed 's/$/_1.fastq.gz/') >$outfile
			else
				paste -d" " <(cut -f${indices} -d$'\t' $infile | tail -n +2 | sed 's/[-_ ][0-9]\+\t/\t/g' | sed 's/[-_ ][0-9]\+$//g' | sed 's/ *(.\+)//g' | sed 's/;.*\t/\t/g' | sed 's/;.*$//g' | sed 's/[,;\.:]//g' | sed 's/[[:space:]]/_/g') <(cut -f1 -d $'\t' $infile | tail -n +2 | sed "s|^|$dir/|" | sed 's/$/_1.fastq.gz/') <(cut -f1 -d $'\t' $infile | tail -n +2 | sed "s|^|$dir/|" | sed 's/$/_2.fastq.gz/') >$outfile
			fi
		else
			paste -d" " <(cut -f${indices} -d$'\t' $infile | tail -n +2 | sed 's/[-_ ][0-9]\+\t/\t/g' | sed 's/[-_ ][0-9]\+$//g' | sed 's/ *(.\+)//g' | sed 's/;.*\t/\t/g' | sed 's/;.*$//g' | sed 's/[,;\.:]//g' | sed 's/[[:space:]]/_/g') <(cut -f1 -d $'\t' $infile | tail -n +2 | sed "s|^|$dir/|" | sed 's/$/.fastq.gz/') >$outfile
		fi
	fi
fi

echo -e "END: $(date)\n" 1>&2
#     echo 1>&2
# fi
echo "STATUS: DONE." 1>&2
touch $dir/READSLIST.DONE

if [[ "$email" = true ]]; then
	org=$(echo "$dir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
	echo "$dir" | mail -s "${org^}: STAGE 04: MAKING A READS LIST: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
