#!/usr/bin/env bash
set -euo pipefail
FULL_PROGRAM=$0
PROGRAM=$(basename $FULL_PROGRAM)
args="$FULL_PROGRAM $*"

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
		echo "DESCRIPTION:"
		echo -e "\
		\tGets reads for one single organism, using fasterq-dump.\n \
		\n \
		\tOUTPUT:\n \
		\t-------\n \
		\t  - *.fastq.gz\n \
		\t  - RUNS.DONE or RUNS.FAIL\n \
		\n \
		\tEXIT CODES:\n \
		\t-------------\n \
		\t  - 0: successfully completed\n \
		\t  - 1: general error\n \
		\t  - 2: failed to download\n \
		\n \
		\tFor more information: https://github.com/ncbi/sra-tools/wiki/HowTo:-fasterq-dump\n \
        " | table

		# USAGE
		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] -o <output directory> <SRA RUN (i.e. SRR) accession list>\n \
        " | table

		# OPTIONS
		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail alert\n \
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n \
		\t-p\tdownload each run in parallel\n \
		\t-t <int>\tnumber of threads\t(default = 2)\n \
    	" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -o /path/to/raw_reads /path/to/sra/runs.txt\n \
		" | table
	} 1>&2
	exit 1
}

# 1.5 - print_line
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

# default parameters
threads=6
email=false
parallel=false
outdir=""
# 4 - read options
while getopts :a:ho:pt: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	h) get_help ;;
	o)
		outdir="$(realpath $OPTARG)"
		;;
	p) parallel=true ;;
	t) threads="$OPTARG" ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

# 5 - incorrect number arguments given
if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 - check input files
if [[ -z $outdir ]]; then
	print_error "Required argument -o <output directory> missing."
else
	mkdir -p $outdir
fi

if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) is empty."
fi

# 7 - remove status files
rm -f $outdir/READS_DL.DONE
rm -f $outdir/READS_DL.FAIL

# 8 - print environment details
if [[ ! -v FASTERQ_DUMP ]]; then
	if command -v fasterq-dump &>/dev/null; then
		FASTERQ_DUMP=$(command -v fasterq-dump)
	else
		print_error "FASTERQ_DUMP is unbound and no 'fasterq-dump' found in PATH. Please export FASTERQ_DUMP=/path/to/fasterq-dump/executable."
	fi
elif ! command -v $FASTERQ_DUMP &>/dev/null; then
	print_error "Unable to execute $FASTERQ_DUMP."
fi

export PATH=$(dirname $(command -v $FASTERQ_DUMP)):$PATH
{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo "CALL: $args (wd: $(pwd))"
} 1>&2

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

sra=$(realpath $1)

echo "PROGRAM: $(command -v $FASTERQ_DUMP)" 1>&2
$FASTERQ_DUMP --version >/dev/null
echo -e "VERSION: $($FASTERQ_DUMP --version | awk '/version/ {print $NF}')\n" 1>&2

if [[ "$parallel" = true ]]; then
	# get each accession parallelly using the get-accession.sh script
	echo -e "Downloading each accession in parallel...\n" 1>&2
	while read accession; do
		# assume that the FASTQs do not exist due to timestamping of the folders
		echo "Initiating download of ${accession}..." 1>&2
		if [[ "$email" = true ]]; then
			echo "COMMAND: $ROOT_DIR/scripts/helpers/get-accession.sh -a $address -t $threads -o $outdir $accession &" 1>&2
			$ROOT_DIR/scripts/helpers/get-accession.sh -a $address -t $threads -o $outdir $accession &
		else
			echo "COMMAND: $ROOT_DIR/scripts/helpers/get-accession.sh -t $threads -o $outdir $accession &" 1>&2
			$ROOT_DIR/scripts/helpers/get-accession.sh -t $threads -o $outdir $accession &
		fi
	done <$sra

	# wait for all child processes to finish
	wait
else
	while read accession; do
		# assume that the FASTQs do not exist due to timestamping of the folders
		echo "Initiating download of ${accession}..." 1>&2
		if [[ "$email" = true ]]; then
			echo "COMMAND: $ROOT_DIR/scripts/helpers/get-accession.sh -a $address -t $threads -o $outdir $accession" 1>&2
			$ROOT_DIR/scripts/helpers/get-accession.sh -a $address -t $threads -o $outdir $accession
		else
			echo "COMMAND: $ROOT_DIR/scripts/helpers/get-accession.sh -t $threads -o $outdir $accession" 1>&2
			$ROOT_DIR/scripts/helpers/get-accession.sh -t $threads -o $outdir $accession
		fi
	done <$sra
fi

# soft link to 'default name'
default_name="$(realpath -s $(dirname $outdir)/raw_reads)"
if [[ "$outdir" != "$default_name" ]]; then
	count=1
	if [[ -d "$default_name" ]]; then
		if [[ ! -L "$default_name" ]]; then
			temp="${default_name}-${count}"
			while [[ -d "$temp" ]]; do
				count=$((count + 1))
				temp="${default_name}-${count}"
			done
			echo -e "\nSince $default_name already exists, $default_name is renamed to $temp as to not overwrite old reads.\n" 1>&2
			mv $default_name $temp
		else
			unlink ${default_name}
		fi
	fi
	echo -e "\n$outdir softlinked to $default_name\n" 1>&2
	(cd $(dirname $outdir) && ln -fs $(basename $outdir) $(basename $default_name))
fi

fail=false
failed_accs=()

# store an array of all 'failed' accessions
while read accession; do
	if ls $outdir/${accession}*.fastq.gz 1>/dev/null 2>&1; then
		:
	else
		# if there are failed accessions, add to a list and fail = true
		fail=true
		failed_accs+=($accession)
	fi
done <$sra

# if fail = true, then write 'FAIL' file.
if [[ "$fail" = true ]]; then
	touch $outdir/READS_DL.FAIL
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
	if [[ "$email" = true ]]; then
		#		echo "${outdir}: ${failed_accs[*]}" | mail -s "Failed downloading reads for $org" "$address"
		echo "${outdir}: ${failed_accs[*]}" | mail -s "${org^}: STAGE 02: DOWNLOADING READS: FAILED" "$address"
		echo "Email alert sent to $address." 1>&2
	fi

	echo "Failed to download: ${failed_accs[*]}" 1>&2
	echo "STATUS: FAILED." 1>&2
	exit 2
fi

# if [[ ! -v WORKDIR ]]; then
# 	workdir=$(dirname $outdir)
# else
# 	workdir=$WORKDIR
# fi

# write a file to indicate whether reads are SINGLE or PAIRED end
# if ls $outdir/*_?.fastq.gz 1>/dev/null 2>&1; then
# 	touch $workdir/PAIRED.END
# else
# 	touch $workdir/SINGLE.END
# fi

echo -e "END: $(date)\n" 1>&2

# echo 1>&2
touch $outdir/READS_DL.DONE
echo "STATUS: DONE." 1>&2

if [[ "$email" = true ]]; then
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
	#	echo "$outdir" | mail -s "Finished downloading reads for $org" "$address"
	echo "$outdir" | mail -s "${org^}: STAGE 02: DOWNLOADING READS: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
