#!/usr/bin/env bash
set -euo pipefail
FULL_PROGRAM=$0
PROGRAM=$(basename $FULL_PROGRAM)
args="$FULL_PROGRAM $*"

# 0 - table function
function table() {
	if column -L <(echo) &>/dev/null; then
		cat | column -s $'\t' -t -L 1>&2
	else
		{
			cat | column -s $'\t' -t
			echo
		} 1>&2
	fi
}
# 1 - get_help function
function get_help() {
	{
		echo -e "PROGRAM: $PROGRAM\n"
		# DESCRIPTION
		echo "DESCRIPTION:"
		echo -e "\
		\tPreprocesses and trims reads using fastp.\n \
		\tFor more information: https://github.com/OpenGene/fastp\n \
		" | table

		# USAGE
		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-h] [-t <int>] -i <input directory> -o <output directory> <accession>\n \
		" | table

		# OPTIONS
		echo "OPTION(S):"
		echo -e "\
		\t-h\tshow help menu\n \
		\t-i <directory>\tinput directory for raw reads\t(required)\n \
		\t-o <directory>\toutput directory for trimmed reads\t(required)\n \
		\t-t <int>\tnumber of threads\t(default = 4)\n \
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

threads=4
indir=""
outdir=""
# 4 - get options
while getopts :hi:o:t: opt; do
	case $opt in
	h) get_help ;;
	i) indir="$(realpath $OPTARG)" ;;
	o) outdir="$(realpath $OPTARG)" ;;
	t) threads="$OPTARG" ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

# 5 - incorrect number of arguments
if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 - check input files - input are not files
if [[ -z $indir ]]; then
	print_error "Required argument -i <input directory> missing."
fi

if [[ -z $outdir ]]; then
	print_error "Required argument -o <output directory> missing."
else
	mkdir -p $outdir
fi

run=$1
logfile=${outdir}/${run}.log
templog=${outdir}/${run}_temp.log
if [[ -e "$logfile" ]]; then
	rm "$logfile"
fi

{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo "CALL: $args (wd: $(pwd))"
	echo -e "THREADS: $threads\n"
} >$logfile

echo "PROGRAM: $(command -v $RUN_FASTP)" >>$logfile
echo -e "VERSION: $($RUN_FASTP --version 2>&1 | awk '{print $NF}')\n" >>$logfile

if [[ ! -v PAIRED ]]; then
	# infer from whether there _1 / _2 or NOT for that accession
	if [[ "$(find $indir -maxdepth 1 -name "*_?.fastq.gz" | wc -l)" -gt 0 ]]; then
		paired=true
	else
		paired=false
	fi
else
	paired=$PAIRED
fi

# workdir=$(dirname $outdir)

# if [[ -f $workdir/PAIRED.END ]]; then
# 	single=false
# elif [[ -f $workdir/SINGLE.END ]]; then
# 	single=true
# else
# 	print_error "*.END file not found."
# fi
mkdir -p $outdir/reports
if [[ "$paired" = true ]]; then
	mkdir -p $outdir/unpaired
	echo -e "COMMAND: $RUN_FASTP --disable_quality_filtering --detect_adapter_for_pe --in1 $indir/${run}_1.fastq.gz --in2 $indir/${run}_2.fastq.gz --out1 $outdir/${run}_1.fastq.gz --out2 $outdir/${run}_2.fastq.gz --unpaired1 $outdir/unpaired/${run}_1.unpaired.fastq.gz --unpaired2 $outdir/unpaired/${run}_2.unpaired.fastq.gz --json $outdir/reports/${run}.report.json --html $outdir/reports/${run}.report.html --thread $threads &>> $templog || true\n" | tee $templog >>$logfile

	$RUN_FASTP --disable_quality_filtering --detect_adapter_for_pe --in1 $indir/${run}_1.fastq.gz --in2 $indir/${run}_2.fastq.gz --out1 $outdir/${run}_1.fastq.gz --out2 $outdir/${run}_2.fastq.gz --unpaired1 $outdir/unpaired/${run}_1.unpaired.fastq.gz --unpaired2 $outdir/unpaired/${run}_2.unpaired.fastq.gz --json $outdir/reports/${run}.report.json --html $outdir/reports/${run}.report.html --thread $threads &>>$templog || true
	#	code=$?
	while [[ "$(grep -c "ERROR" $templog)" -gt 0 ]]; do
		echo -e "Failed to trim ${run}. Trying again...\n" >>$logfile
		echo -e "COMMAND: $RUN_FASTP --disable_quality_filtering --detect_adapter_for_pe --in1 $indir/${run}_1.fastq.gz --in2 $indir/${run}_2.fastq.gz --out1 $outdir/${run}_1.fastq.gz --out2 $outdir/${run}_2.fastq.gz --unpaired1 $outdir/unpaired/${run}_1.unpaired.fastq.gz --unpaired2 $outdir/unpaired/${run}_2.unpaired.fastq.gz --json $outdir/reports/${run}.report.json --html $outdir/reports/${run}.report.html --thread $threads &>> $templog || true\n" >>$templog
		$RUN_FASTP --disable_quality_filtering --detect_adapter_for_pe --in1 $indir/${run}_1.fastq.gz --in2 $indir/${run}_2.fastq.gz --out1 $outdir/${run}_1.fastq.gz --out2 $outdir/${run}_2.fastq.gz --unpaired1 $outdir/unpaired/${run}_1.unpaired.fastq.gz --unpaired2 $outdir/unpaired/${run}_2.unpaired.fastq.gz --json $outdir/reports/${run}.report.json --html $outdir/reports/${run}.report.html --thread $threads &>>$templog || true
		#		code=$?
	done
else
	echo -e "COMMAND: $RUN_FASTP --disable_quality_filtering --in1 $indir/${run}.fastq.gz --out1 $outdir/${run}.fastq.gz --json $outdir/reports/${run}.report.json --html $outdir/reports/${run}.report.html --thread $threads &> $templog || true\n" | tee $templog >>$logfile
	$RUN_FASTP --disable_quality_filtering --in1 $indir/${run}.fastq.gz --out1 $outdir/${run}.fastq.gz --json $outdir/reports/${run}.report.json --html $outdir/reports/${run}.report.html --thread $threads &>>$templog || true
	#	code=$?
	while [[ "$(grep -c "ERROR" $templog)" -gt 0 ]]; do
		echo -e "Failed to trim ${run}. Trying again...\n" >>$logfile
		echo -e "COMMAND: $RUN_FASTP --disable_quality_filtering --in1 $indir/${run}.fastq.gz --out1 $outdir/${run}.fastq.gz --json $outdir/${run}.report.json --html $outdir/${run}.report.html --thread $threads &>> $templog || true\n" >$templog
		$RUN_FASTP --disable_quality_filtering --in1 $indir/${run}.fastq.gz --out1 $outdir/${run}.fastq.gz --json $outdir/reports/${run}.report.json --html $outdir/reports/${run}.report.html --thread $threads &>>$templog || true
		#		code=$?
	done
fi

tail -n +2 $templog >>$logfile
rm $templog
echo >>$logfile
echo "Successfully trimmed ${run}!" >>$logfile
