#!/usr/bin/env bash
PROGRAM=$(basename $0)
set -euo pipefail
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

# 1 - get_help function
function get_help() {
	{
		# DESCRIPTION
		echo "DESCRIPTION:"
		echo -e "\
		\tChecks the input.txt file to make sure the reads are present.\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-a <address>] [-h] [-t <int>] <input reads TXT file>\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail address for alerts\n \
		\t-h\tshow help menu\n \
		\t-t <int>\tnumber of threads (for compression, if needed)\n \
		" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com -t 8 input.txt\n \
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
	print_error "Input file $(realpath $1) is empty."
fi

# 7 remove status files

# 8 - print env
{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo "CALL: $args (wd: $(pwd))"
	if [[ "$custom_threads" = true ]]; then
		echo
		echo -e "THREADS: $threads\n"
	fi
} 1>&2

input=$(realpath $1)
input_processed=${input/.txt/.processed.txt}

# if workdir is unbound then
if [[ ! -v WORKDIR ]]; then
	# get workdir from input
	workdir=$(dirname $input)
else
	workdir=$(realpath $WORKDIR)
fi

if [[ ! -v SPECIES ]]; then
	# get species from workdir
	species=$(echo "$workdir" | awk -F "/" '{print $(NF-1)}')
else
	species=$SPECIES
fi

# remove if already exists
rm -f $input_processed

# check that num columns is consistent
if [[ "$(awk '{print NF}' $input | sort -u | wc -l)" -ne 1 ]]; then
	print_error "Inconsistent number of columns."
fi

# if env variable PAIRED is not set, then use number of columns in input
if [[ ! -v PAIRED ]]; then
	num_cols=$(awk '{print NF}' $input | sort -u)
	if [[ "$num_cols" -eq 2 ]]; then
		paired=false
		#		touch SINGLE.END
	elif [[ "$num_cols" -eq 3 ]]; then
		paired=true
		#		touch PAIRED.END
	else
		print_error "There are too many columns in the input TXT file."
	fi
else
	paired=$PAIRED
fi

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi
# this script is ONLY run as a part of the Makefile, so it will run in the "working directory" CLASS/SPECIES/TISSUE
mkdir -p $workdir/raw_reads

# parse through the input txt and copy reads to the raw_reads dir if they aren't already there
if [[ "$paired" = true ]]; then
	while read pool read1 read2; do
		# check if the reads in the given paths exist
		if [[ -s "$(realpath ${read1} 2>/dev/null)" && -s "$(realpath ${read2} 2>/dev/null)" ]]; then
			newname1=$(realpath raw_reads/$(basename ${read1}))
			if [[ ! -s "raw_reads/$(basename ${read1})" && ! -L "raw_reads/$(basename ${read1})" ]]; then
				echo "Moving $(basename ${read1}) into $(realpath raw_reads)..." 1>&2
				# mv ${read1} ${newname1}
				(cd $workdir/raw_reads && ln -s $(realpath ${read1}))
				# cp ${read1} ${newname1}
			else
				echo "$(basename ${read1}) already in $(realpath raw_reads)..." 1>&2
			fi
			# 			sed "s|${read1}|${newname}|" $input >>$input_processed
			newname2=$(realpath raw_reads/$(basename ${read2}))
			if [[ ! -s "raw_reads/$(basename ${read2})" && ! -L "raw_reads/$(basename ${read2})" ]]; then
				echo "Moving $(basename ${read2}) into $(realpath raw_reads)..." 1>&2
				# mv ${read2} ${newname2}
				# cp ${read2} ${newname2}
				(cd $workdir/raw_reads && ln -s $(realpath ${read2}))
			else
				echo "$(basename ${read2}) already in $(realpath raw_reads)..." 1>&2
			fi
			#			sed "s|${read2}|${newname2}|" $input >>$input_processed
			echo "$pool ${newname1} ${newname2}" >>$input_processed
		else
			print_error "Reads ${read1} and ${read2} in the input file do not exist or are empty."
		fi
	done <$input
else
	while read pool read1; do
		if [[ -s "$(realpath ${read1} 2>/dev/null)" ]]; then
			newname=$(realpath raw_reads/$(basename ${read1}))
			if [[ ! -s "raw_reads/$(basename ${read1})" && ! -L "raw_reads/$(basename ${read1})" ]]; then
				echo "Moving $(basename ${read1}) into $(realpath raw_reads)..." 1>&2a
				# mv ${read1} ${newname}
				# cp ${read1} ${newname}
				(cd $workdir/raw_reads && ln -s $(realpath ${read1}))
			else
				echo "$(basename ${read1}) already in $(realpath raw_reads)..." 1>&2
			fi
			#			sed "s|${read1}|${newname}|" $input >>$input_processed
			echo "$pool ${newname}" >>$input_processed
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

for i in $(realpath $workdir/raw_reads/*.f*q); do
	echo "Compressing $(basename $i)..." 1>&2
	${compress} $i

	# if file is .fq.gz, then change .fq to .fastq.gz
	fq_gz=${i}.gz
	if [[ "${fq_gz}" != "${fq_gz/.fq/.fastq}" ]]; then
		mv ${fq_gz} ${fq_gz/.fq/.fastq}
	fi

	# update input file to reflect .fastq and compression
	sed -i 's/.fastq[:space:]/&.gz/g' $input_processed
done 2>/dev/null || true

touch $workdir/raw_reads/READS.DONE
echo -e "\nSTATUS: DONE.\n" 1>&2

echo "Output: $(realpath raw_reads)" 1>&2

if [[ "$email" = true ]]; then
	species=$(echo "$species" | sed 's/^./\u&. /')
	# echo "$workdir/raw_reads" | mail -s "${species^}: STAGE 02: GETTING READS: SUCCESS" "$address"
	echo "$workdir/raw_reads" | mail -s "${species}: STAGE 02: GETTING READS: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
