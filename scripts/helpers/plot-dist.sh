#!/usr/bin/env bash

set -euo pipefail
FULL_PROGRAM=$0
PROGRAM=$(basename $FULL_PROGRAM)

if [[ "$PROGRAM" == "slurm_script" ]]; then
	FULL_PROGRAM=$(scontrol show job $SLURM_JOBID | awk '/Command=/ {print $1}' | awk -F "=" '{print $2}')
	PROGRAM=$(basename ${FULL_PROGRAM})

fi
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
		echo "DESCRIPTION:"
		echo -e "\
		\tTakes AMPlify results and plots a distribution histogram.\n \
		\n \
		\tOUTPUT:\n \
		\t-------\n \
		\t  - AMPlify_results.nr.tsv\n \
		\t  - [Reference]AMPDistribution.png\n \
		\n \
		\tEXIT CODES:\n \
		\t-----------\n \
		\t  - 0: successfully completed\n \
		\t  - 1: general errors\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-h] [-t <int>] -a <Amphibian FASTA> -i <Insect FASTA> [-r] [-s <0 to 1>] [-S <0 to 1>] [-L <int> [-C <int>]\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-a <FASTA>\tAmphibian FASTA file (*.faa)\n \
		\t-h\tshow this help menu\n \
		\t-i <FASTA>\tInsect FASTA file (*.faa)\n \
		\t-o <PATH>\t Output directory\t(default: parent directory of FASTAs)\n \
		\t-r\tAMPs given are reference AMPs\n \
		\t-t <int>\tnumber of threads\t(default = all)\n \
		\t-s <0 to 1>\tAMPlify score threshold for amphibians\t(default = 0.90)\n \
		\t-S <0 to 1>\tAMPlify score threshold for insects\t(default = 0.80)\n \
		\t-L <int>\tLength threshold\t(default = 30)\n \
		\t-C <int>\tCharge threshold\t(default = 2)\n \
		" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a amphibianAMPs.faa -i insectAMPs.faa -t 8 -o /path/to/output/dir\n \
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

# default parameters
custom_threads=false
outdir=""
amphibian_fasta=""
insect_fasta=""
reference_opt=""
amphibian_score="--amphibian_score=0.90"
insect_score="--insect_score=0.80"
length="--length=30"
charge="--charge=2"

# 4 - read options
while getopts :a:i:ht:o:rs:S:L:C: opt; do
	case $opt in
	a)
		amphibian_fasta=$(realpath $OPTARG)
		;;
	h) get_help ;;
	i) insect_fasta=$(realpath $OPTARG) ;;
	o)
		outdir=$(realpath $OPTARG)
		;;
	r) reference_opt="--reference" ;;
	t)
		threads="$OPTARG"
		custom_threads=true
		;;
	s) amphibian_score="--amphibian_score=$OPTARG" ;;
	S) insect_score="--insect_score=$OPTARG" ;;
	L) length="--length=$OPTARG" ;;
	C) charge="--charge=$OPTARG" ;;
	\?)
		print_error "Invalid option: -$OPTARG"
		;;
	esac
done

shift $((OPTIND - 1))

# 5 - wrong arguments given
if [[ "$#" -ne 0 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 - check input files
if [[ -z $amphibian_fasta && -z $insect_fasta ]]; then
	print_error "At least one of required -a <FASTA> or -i <FASTA> not given."
fi

if [[ -z $outdir ]]; then
	if [[ -n $amphibian_fasta ]]; then
		outdir=$(dirname $amphibian_fasta)
	elif [[ -n $insect_fasta ]]; then
		outdir=$(dirname $insect_fasta)
	fi
else
	mkdir -p $outdir
fi

# RUNS AMPLIFY and gets the TSV
if [[ "$custom_threads" = true ]]; then
	if [[ -n $amphibian_fasta ]]; then
		export CLASS=Amphibia && mkdir -p $outdir/amphibia && $ROOT_DIR/scripts/run-amplify.sh -o $outdir/amphibia -T -t $threads $amphibian_fasta &>$outdir/amphibia/amplify.log
	fi
	if [[ -n $insect_fasta ]]; then
		export CLASS=Insecta && mkdir -p $outdir/insecta && $ROOT_DIR/scripts/run-amplify.sh -o $outdir/insecta -T -t $threads $insect_fasta &>$outdir/insecta/amplify.log
	fi
else
	if [[ -n $amphibian_fasta ]]; then
		export CLASS=Amphibia && mkdir -p $outdir/amphibia && $ROOT_DIR/scripts/run-amplify.sh -o $outdir/amphibia -T $amphibian_fasta &>$outdir/amphibia/amplify.log
	fi
	if [[ -n $insect_fasta ]]; then
		export CLASS=Insecta && mkdir -p $outdir/insecta && $ROOT_DIR/scripts/run-amplify.sh -o $outdir/insecta -T $insect_fasta &>$outdir/insecta/amplify.log
	fi
fi

cat $outdir/amphibia/AMPlify_results.nr.tsv <(tail -n +2 $outdir/insecta/AMPlify_results.nr.tsv) >$outdir/AMPlify_results.nr.tsv

# PLOT IT
echo "PROGRAM: $(command -v $RSCRIPT)" 1>&2
R_version=$($RSCRIPT --version 2>&1 | awk '{print $(NF-1), $NF}')
echo -e "VERSION: $R_version\n" 1>&2

echo "COMMAND: Rscript $ROOT_DIR/scripts/helpers/RefAMPDist.R $reference_opt --input_tsv=$outdir/AMPlify_results.nr.tsv --output_dir=$outdir $amphibian_score $insect_score $length $charge" 1>&2

Rscript $ROOT_DIR/scripts/helpers/RefAMPDist.R $reference_opt --input_tsv=$outdir/AMPlify_results.nr.tsv --output_dir=$outdir $amphibian_score $insect_score $length $charge
