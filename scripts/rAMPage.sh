#!/usr/bin/env bash

# set -euo pipefail
PROGRAM=$(basename $0)

## SCRIPT that wraps around the Makefile

# 1 - get_help function
function get_help() {
	{
		# DESCRIPTION:
		echo "DESCRIPTION:"
		echo -e "\
		\tRuns the rAMPage pipeline, using the Makefile.\n \
		" | column -s $'\t' -t -L

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-s] [-o <output directory>] [-r <reference>] <input reads TXT file>\n \
		" | column -s $'\t' -t -L

		echo "OPTIONS:"
		echo -e "\
		\t-a <address>\temail alert\n \
		\t-h\tshow help menu\n \
		\t-o <directory>\toutput directory\t(default = directory of input reads TXT file)\n \
		\t-p\trun processes in parallel\n \
		\t-r <FASTA.gz>\treference transcriptome\t(accepted multiple times, *.fna.gz *.fsa_nt.gz)\n \
		\t-s\tstranded library construction\t(default = nonstranded)\n \
		\t-t <INT>\tnumber of threads\t(default = 48)\n \
		" | column -s $'\t' -t -L

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -s -o /path/to/output/directory -r /path/to/reference.fna.gz -r /path/to/reference.fsa_nt.gz /path/to/input.txt \n \
		" | column -s $'\t' -t -L

		echo "INPUT EXAMPLE:"
		echo -e "\
		\ttissue /path/to/readA_1.fastq.gz /path/to/readA_2.fastq.gz\n \
		\ttissue /path/to/readB_1.fastq.gz /path/to/readB_2.fastq.gz\n \
		" | column -s $'\t' -t -L

		#	echo "Reads must be compressed in .gz format."
	} 1>&2

	exit 1
}

# 2 - print error function
function print_error() {
	{
		message="$1"
		echo "ERROR: $message"
		printf '%.0s=' $(seq 1 $(tput cols))
		echo
		get_help
	} 1>&2
}

# 3 - no args given

if [[ "$#" -eq 0 ]]; then
	get_help
fi

# 4 - get options
stranded=false
ref=false
outdir=""
failed=false
threads=""
parallel=false
email=false
email_opt=""
while getopts :ha:r:o:pst: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		email_opt="EMAIL=$address"
		;;
	h) get_help ;;
	o) outdir="$(realpath $OPTARG)" ;;
	p) parallel=true ;;
	r)
		reference+=("$OPTARG")
		ref=true
		;;
	s) stranded=true ;;
	t) threads="THREADS=$OPTARG" ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

# 5 - incorrect number of arguments
if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 - check inputs
if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "input file $(realpath $1) is empty."
fi

# check that input file is somehwere in the repository
if [[ "$(realpath $1)" != */rAMPage* ]]; then
	print_error "Input file $(realpath $1) must be located within the rAMPage directory."
fi

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

# 7 - remove status files

# 8 - print environemnt details
if [[ -z "$ROOT_DIR" || ! -f "$ROOT_DIR/CONFIG.DONE" ]]; then
	print_error "Environment variables have not been successfuly configured yet."
fi

echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)\n" 1>&2

echo -e "PATH=$PATH\n" 1>&2

input=$(realpath $1)

# check that all rows have the same number of columns
if [[ "$(awk '{print NF}' $input | sort -u | wc -l)" -ne 1 ]]; then
	print_error "Inconsistent number of columns."
fi

if [[ -z $outdir ]]; then
	outdir=$(dirname $input)
else
	mkdir -p $outdir
	# if INPUT given ISN'T in the output directory, put it there (it IS supposed to be there)
	if [[ ! -s $outdir/$(basename $input) ]]; then
		mv $input $outdir/$(basename $input)
	fi
	input=$outdir/$(basename $input)
fi

# check that there are either 2 or 3 columns
num_cols=$(awk '{print NF}' $input | sort -u)
if [[ "$num_cols" -eq 2 ]]; then
	touch $outdir/SINGLE.END
elif [[ "$num_cols" -eq 3 ]]; then
	touch $outdir/PAIRED.END
else
	print_error "There are too many columns in the input TXT file."
fi
if [[ "$stranded" = true ]]; then
	touch $outdir/STRANDED.LIB
else
	touch $outdir/NONSTRANDED.LIB
fi

class=$(echo "$outdir" | sed "s|$ROOT_DIR/\?||" | awk -F "/" '{print $1}')
if [[ -n $class ]]; then
	touch $outdir/${class^^}.CLASS
else
	print_error "Invalid class taxon in the parent directory name: $(dirname $input | sed "s|$ROOT_DIR/\?||")."
fi

# MOVE reference to working dir
if [[ $ref = true ]]; then
	for i in "${reference[@]}"; do
		if [[ -s "$i" ]]; then
			if [[ ! -s "$outdir/$(basename $i)" ]]; then
				mv $i $outdir
			fi
		else
			print_error "Reference $(basename $i) does not exist or is empty."
		fi
	done
fi

# RUN THE PIPELINE USING THE MAKE FILE
mkdir -p $outdir/logs
echo "Running rAMPage..." 1>&2
/usr/bin/time -pv make INPUT=$input $threads PARALLEL=$parallel $email_opt -C $outdir -f $ROOT_DIR/scripts/Makefile

if [[ "$?" -ne 0 ]]; then
	failed=true
	echo "FAILED! Last logfile:" 1>&2
	cat $(ls -t $outdir/logs/*.log | head -n1)
	echo "Cleaning directory $outdir..." 1>&2
	make INPUT=$input -C $outdir -f $ROOT_DIR/scripts/Makefile clean
fi

echo -e "\nEND: $(date)" 1>&2

if [[ "$failed" = true ]]; then
	echo -e "\nSTATUS: FAILED." 1>&2
else
	echo -e "\nSTATUS: DONE." 1>&2
fi

if [[ "$email" = true ]]; then
	org=$(echo "$outdir" | awk -F "/" '{print $(NF-1)}' | sed 's/^./&. /')
	echo "$outdir" | mail -s "${org^}: rAMPage: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
