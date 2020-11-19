#!/bin/bash
set -uo pipefail
PROGRAM=$(basename $0)

# 1 - get_help function
function get_help() {
	{
		# DESCRIPTION
		echo "DESCRIPTION:" 1>&2
		echo -e "\
		\tPreprocesses and trims reads using fastp.\n \
		\tFor more information: https://github.com/OpenGene/fastp\n \
		" | column -s$'\t' -t -L

		# USAGE
		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] -i <input directory> -o <output directory> <accession>\n \
		" | column -s$'\t' -t -L

		# OPTIONS
		echo "OPTION(S):"
		echo -e "\
		\t-h\tshow help menu\n \
		\t-i <directory>\tinput directory for raw reads\t(required)\n \
		\t-o <directory>\toutput directory for trimmed reads\t(required)\n \
		\t-t <int>\tnumber of threads\t(default = 4)\n \
		" | column -s$'\t' -t -L
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

threads=4

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

run=$1
logfile=${outdir}/${run}.log
templog=${outdir}/${run}_temp.log
if [[ -e "$logfile" ]]; then
	rm "$logfile"
fi

{
	echo "HOSTNAME: $(hostname)"
	echo -e "PATH=$PATH\n"
} >$logfile

echo "PROGRAM: $(command -v $RUN_FASTP)" >>$logfile
echo -e "VERSION: $($RUN_FASTP --version 2>&1 | awk '{print $NF}')\n" >>$logfile

workdir=$(dirname $outdir)

if [[ -f $workdir/PAIRED.END ]]; then
	single=false
elif [[ -f $workdir/SINGLE.END ]]; then
	single=true
else
	echo "ERROR: *.END file not found." 1>&2
	printf '%.0s=' $(seq 1 $(tput cols)) 1>&2
	echo 1>&2
	get_help
fi

if [[ "$single" = false ]]; then
	echo -e "COMMAND: $RUN_FASTP --disable_quality_filtering --detect_adapter_for_pe --in1 $indir/${run}_1.fastq.gz --in2 $indir/${run}_2.fastq.gz --out1 $outdir/${run}_1.paired.fastq.gz --out2 $outdir/${run}_2.paired.fastq.gz --unpaired1 $outdir/${run}_1.unpaired.fastq.gz --unpaired2 $outdir/${run}_2.unpaired.fastq.gz --json $outdir/${run}.report.json --html $outdir/${run}.report.html --thread $threads &>> $templog\n" | tee $templog >>$logfile

	$RUN_FASTP --disable_quality_filtering --detect_adapter_for_pe --in1 $indir/${run}_1.fastq.gz --in2 $indir/${run}_2.fastq.gz --out1 $outdir/${run}_1.paired.fastq.gz --out2 $outdir/${run}_2.paired.fastq.gz --unpaired1 $outdir/${run}_1.unpaired.fastq.gz --unpaired2 $outdir/${run}_2.unpaired.fastq.gz --json $outdir/${run}.report.json --html $outdir/${run}.report.html --thread $threads &>>$templog
	code=$?
	while [[ "$code" -ne 0 || "$(grep -c "ERROR" $templog)" -gt 0 ]]; do
		echo -e "Failed to trim ${run}. Trying again...\n" >>$logfile
		echo -e "COMMAND: $RUN_FASTP --disable_quality_filtering --detect_adapter_for_pe --in1 $indir/${run}_1.fastq.gz --in2 $indir/${run}_2.fastq.gz --out1 $outdir/${run}_1.paired.fastq.gz --out2 $outdir/${run}_2.paired.fastq.gz --unpaired1 $outdir/${run}_1.unpaired.fastq.gz --unpaired2 $outdir/${run}_2.unpaired.fastq.gz --json $outdir/${run}.report.json --html $outdir/${run}.report.html --thread $threads &>> $templog\n" >>$templog
		$RUN_FASTP --disable_quality_filtering --detect_adapter_for_pe --in1 $indir/${run}_1.fastq.gz --in2 $indir/${run}_2.fastq.gz --out1 $outdir/${run}_1.paired.fastq.gz --out2 $outdir/${run}_2.paired.fastq.gz --unpaired1 $outdir/${run}_1.unpaired.fastq.gz --unpaired2 $outdir/${run}_2.unpaired.fastq.gz --json $outdir/${run}.report.json --html $outdir/${run}.report.html --thread $threads &>>$templog
		code=$?
	done
else
	echo -e "COMMAND: $RUN_FASTP --disable_quality_filtering --in1 $indir/${run}.fastq.gz --out1 $outdir/${run}.fastq.gz --json $outdir/${run}.report.json --html $outdir/${run}.report.html --thread $threads &> $templog\n" | tee $templog >>$logfile
	$RUN_FASTP --disable_quality_filtering --in1 $indir/${run}.fastq.gz --out1 $outdir/${run}.fastq.gz --json $outdir/${run}.report.json --html $outdir/${run}.report.html --thread $threads &>>$templog
	code=$?
	while [[ "$code" -ne 0 || "$(grep -c "ERROR" $templog)" -gt 0 ]]; do
		echo -e "Failed to trim ${run}. Trying again...\n" >>$logfile
		echo -e "COMMAND: $RUN_FASTP --disable_quality_filtering --in1 $indir/${run}.fastq.gz --out1 $outdir/${run}.fastq.gz --json $outdir/${run}.report.json --html $outdir/${run}.report.html --thread $threads &>> $templog\n" >$templog
		$RUN_FASTP --disable_quality_filtering --in1 $indir/${run}.fastq.gz --out1 $outdir/${run}.fastq.gz --json $outdir/${run}.report.json --html $outdir/${run}.report.html --thread $threads &>>$templog
		code=$?
	done
fi

tail -n +2 $templog >>$logfile
rm $templog
echo >>$logfile
echo "Successfully trimmed ${run}!" >>$logfile
