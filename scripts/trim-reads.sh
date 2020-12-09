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
# 1 - get_help function
function get_help() {
	# DESCRIPTION
	{
		echo -e "PROGRAM: $PROGRAM\n"
		echo "DESCRIPTION:"
		echo -e "\
		\tPreprocesses and trims reads with fastp.\n \
		\n \
		\tOUTPUT:\n \
		\t-------\n \
		\t  - *.[paired.]fastq.gz\n \
		\t  - TRIM.DONE\n \
        \n \
		\tEXIT CODES:\n \
		\t-----------\n \
		\t  - 0: successfully completed\n \
		\t  - 1: general error\n \
		\t  - 2: trimming failed\n \
		\t  - 3: core dumped\n \
		\n \
		\tFor more information: https://github.com/OpenGene/fastp\n \
        " | table

		# USAGE
		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] -i <input directory> -o <output directory>\n \
        " | table

		# OPTIONS
		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail alert\n \
		\t-h\tshow this help menu\n \
		\t-i <directory>\tinput directory for raw reads\t(required)\n \
		\t-o <directory>\toutput directory for trimmed reads\t(required)\n \
		\t-p\ttrim each run in parallel\n \
		\t-t <int>\tnumber of threads\t(default = 4)\n \
    	" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -i /path/to/raw_reads -o /path/to/trimmed_reads\n \
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
# this one must be _before_ because none taken after reading options
if [[ "$#" -eq 0 ]]; then
	get_help
fi

# default parameters
threads=4
email=false
parallel=false
outdir=""
indir=""
# 4 - read options
while getopts :a:hi:o:pt: opt; do
	case $opt in
	a)
		email=true
		address="$OPTARG"
		;;
	h) get_help ;;
	i) indir=$(realpath $OPTARG) ;;
	o)
		outdir=$(realpath $OPTARG)
		;;
	p) parallel=true ;;
	t) threads="$OPTARG" ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

# 5 - incorrect number of arguments given
if [[ "$#" -ne 0 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 - check input files
if [[ -z $outdir ]]; then
	print_error "Required argument -o <output directory> missing."
else
	mkdir -p $outdir
fi

if [[ -z $indir ]]; then
	print_error "Required argument -i <input directory> missing."
fi

if [[ ! -d $indir ]]; then
	print_error "Input directory $indir does not exist."
fi

if ! ls $indir/*.fastq.gz &>/dev/null; then
	print_error "Input raw reads not found in $indir."
fi

# 7 - remove status files
rm -f $outdir/TRIM.DONE
rm -f $outdir/TRIM.FAIL

# 8 - print env details
{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo -e "CALL: $args (wd: $(pwd))\n"
} 1>&2

# if workdir not set, infer from indir
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
# if [[ ! -v PAIRED ]]; then
# 	# infer from indir
# 	if [[ "$(find $indir -maxdepth 1 -name "*_?.fastq.gz" | wc -l)" -gt 0 ]]; then
# 		paired=true
# 	else
# 		paired=false
# 	fi
# else
# 	paired=$PAIRED
# fi
# if [[ -f $workdir/PAIRED.END ]]; then
# 	paired=true
# elif [[ -f $workdir/SINGLE.END ]]; then
# 	paired=false
# else
# 	print_error "*.END file not found. Please check that the reads have been downloaded properly."
# fi

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

echo "PROGRAM: $(command -v $RUN_FASTP)" 1>&2
echo -e "VERSION: $($RUN_FASTP --version 2>&1 | awk '{print $NF}')\n" 1>&2
if [[ "$parallel" = true ]]; then
	echo -e "Trimming each accession in parallel...\n" 1>&2
	for i in $(find $indir -maxdepth 1 -name "*.fastq.gz" | sed 's/_\?[1-2]\?\.fastq\.gz//' | sort -u); do
		if [[ -n $i ]]; then
			run=$(basename $i)
			echo "Trimming ${run}..." 1>&2
			echo -e "COMMAND: $ROOT_DIR/scripts/run-fastp.sh -t $threads -i $indir -o $outdir $run &\n" 1>&2
			$ROOT_DIR/scripts/run-fastp.sh -t $threads -i $indir -o $outdir $run &
		fi
	done
	wait
else
	for i in $(find $indir -maxdepth 1 -name "*.fastq.gz" | sed 's/_\?[1-2]\?\.fastq\.gz//' | sort -u); do
		if [[ -n $i ]]; then
			run=$(basename $i)
			echo "Trimming ${run}..." 1>&2
			echo -e "COMAMND: $ROOT_DIR/scripts/run-fastp.sh -t $threads -i $indir -o $outdir $run\n" 1>&2
			$ROOT_DIR/scripts/run-fastp.sh -t $threads -i $indir -o $outdir $run
		fi
	done
fi

fail=false
failed_accs=()

# for each accession in indir, check if an outdir equivalent exists
for i in $(find $indir -maxdepth 1 -name "*.fastq.gz"); do
	run=$(basename $i)
	if [[ ! -s $outdir/${run} ]]; then
		fail=true
		failed_accs+=(${run})
	fi
done

if [[ "$fail" = true ]]; then
	touch $outdir/TRIM.FAIL

	if [[ -f "$outdir/TRIM.DONE" ]]; then
		rm $outdir/TRIM.DONE
	fi

	if [[ "$email" = true ]]; then
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		# echo "${outdir}: ${failed_accs[*]}" | mail -s "Failed trimming reads for $org" "$address"
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
		echo "${outdir}: ${failed_accs[*]}" | mail -s "${species^}: STAGE 03: TRIMMING READS: FAILED" "$address"
		echo "Email alert sent to $address." 1>&2
	fi
	echo "Failed to trim: ${failed_accs[*]}" 1>&2
	echo "STATUS: FAILED." 1>&2
	exit 2
fi

if ls $workdir/core.* &>/dev/null; then
	echo "ERROR: Core dumped." 1>&2
	rm $workdir/core.*
	if [[ "$email" = true ]]; then
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		# echo "${outdir}: ${failed_accs[*]}" | mail -s "Failed trimming reads for $org" "$address"
		echo "${outdir}: ${failed_accs[*]}" | mail -s "${species^}: STAGE 03: TRIMMING READS: FAILED" "$address"
		echo "Email alert sent to $address." 1>&2
	fi
	echo "Failed to trim: ${failed_accs[*]}" 1>&2
	echo "STATUS: FAILED." 1>&2
	exit 3
fi

# tally up the number of reads before and after trimming by parsing all the logs
total=$(awk '/reads passed filter:/ {print $NF}' $outdir/*.log | paste -s -d+ | bc)
low_qual=$(awk '/reads failed due to low quality:/ {print $NF}' $outdir/*.log | paste -s -d+ | bc)
many_Ns=$(awk '/reads failed due to too many N:/ {print $NF}' $outdir/*.log | paste -s -d+ | bc)
too_short=$(awk '/reads failed due to too short:/ {print $NF}' $outdir/*.log | paste -s -d+ | bc)
adapter_trimmed=$(awk '/reads with adapter trimmed:/ {print $NF}' $outdir/*.log | paste -s -d+ | bc)

echo "Reads passed filter: $(printf "%'d" $total)" 1>&2
echo "Reads failed due to low quality: $(printf "%'d" $low_qual)" 1>&2
echo "Reads failed due to too many Ns: $(printf "%'d" $many_Ns)" 1>&2
echo "Reads failed due to short length: $(printf "%'d" $too_short)" 1>&2
echo "Reads with adapter trimmed: $(printf "%'d" $adapter_trimmed)" 1>&2

default_name="$(realpath -s $(dirname $outdir)/trimmed_reads)"
if [[ "$default_name" != "$outdir" ]]; then
	if [[ -d "$default_name" ]]; then
		count=1
		if [[ ! -L "$default_name" ]]; then
			temp="${default_name}-${count}"
			while [[ -d "$temp" ]]; do
				count=$((count + 1))
				temp="${default_name}-${count}"
			done
			echo -e "Since $default_name already exists, $default_name is renamed to $temp as to not overwrite old trimmed reads.\n" 1>&2
			mv $default_name $temp
		else
			unlink $default_name
		fi
	fi
	if [[ "$default_name" != "$outdir" ]]; then
		echo -e "\n$outdir softlinked to $default_name\n" 1>&2
		(cd $(dirname $outdir) && ln -fs $(basename $outdir) $(basename $default_name))
	fi
fi
echo -e "\nEND: $(date)\n" 1>&2
# echo 1>&2

echo -e "STATUS: DONE.\n" 1>&2
touch $outdir/TRIM.DONE

echo "Output: $outdir)" 1>&2

if [[ "$email" = true ]]; then
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	# echo "$outdir" | mail -s "Finished trimming reads for $org" "$address"
	species=$(echo "$species" | sed 's/^./\u&. /')
	# echo "$outdir" | mail -s "${species^}: STAGE 03: TRIMMING READS: SUCCESS" "$address"
	echo "$outdir" | mail -s "${species}: STAGE 03: TRIMMING READS: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
