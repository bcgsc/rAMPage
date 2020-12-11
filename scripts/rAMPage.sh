#!/usr/bin/env bash

set -euo pipefail
PROGRAM=$(basename $0)

## SCRIPT that wraps around the Makefile
args="$PROGRAM $*"

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
		# DESCRIPTION:
		echo "DESCRIPTION:"
		echo -e "\
		\tRuns the rAMPage pipeline, using the Makefile.\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-s] [-o <output directory>] [-r <reference>] [-c <taxonomic class>] [-n <species name>] <input reads TXT file>\n \
		" | table

		echo "OPTIONS:"
		echo -e "\
		\t-a <address>\temail alert\n \
		\t-c <class>\ttaxonomic class of the dataset\t(default = top-level directory in \$outdir)\n \
		\t-h\tshow help menu\n \
		\t-n <species>\ttaxnomic species or name of the dataset\t(default = second-level directory in \$outdir)\n \
		\t-o <directory>\toutput directory\t(default = directory of input reads TXT file)\n \
		\t-p\trun processes in parallel\n \
		\t-r <FASTA.gz>\treference transcriptome\t(accepted multiple times, *.fna.gz *.fsa_nt.gz)\n \
		\t-s\tstrand-specific library construction\t(default = false)\n \
		\t-t <INT>\tnumber of threads\t(default = 48)\n \
		\t-v\tverbose (uses /usr/bin/time)\n \
		" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -s -o /path/to/output/directory -r /path/to/reference.fna.gz -r /path/to/reference.fsa_nt.gz /path/to/input.txt \n \
		" | table

		echo "INPUT EXAMPLE:"
		echo -e "\
		\ttissue /path/to/readA_1.fastq.gz /path/to/readA_2.fastq.gz\n \
		\ttissue /path/to/readB_1.fastq.gz /path/to/readB_2.fastq.gz\n \
		" | table

		#	echo "Reads must be compressed in .gz format."
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

# 2 - print error function
function print_error() {
	{
		echo -e "CALL: $args (wd: $(pwd))\n"
		message="$1"
		echo "$PROGRAM: ERROR: $message"
		print_line
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
# failed=false
threads=""
parallel=false
email=false
email_opt=""
class=""
species=""
verbose=false
while getopts :ha:c:r:n:o:pst:v opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		email_opt="EMAIL=$address"
		;;
	c)
		# class="${OPTARG,,}"
		class=$(echo "$OPTARG" | sed 's/.\+/\L&/')
		;;
	h) get_help ;;
	n)
		species=$(echo "$OPTARG" | sed 's/.\+/\L&/')
		# species="${OPTARG,,}"
		;;
	o) outdir="$(realpath $OPTARG)" ;;
	p) parallel=true ;;
	r)
		reference+=("$OPTARG")
		ref=true
		;;
	s) stranded=true ;;
	t) threads="THREADS=$OPTARG" ;;
	v) verbose=true ;;
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

if [[ -z $class ]]; then
	# get class from outdir
	class=$(echo "$outdir" | sed "s|$ROOT_DIR||" | awk -F "/" '{print $2}' | sed 's/.\+/\L&/')

fi

if [[ -z $species ]]; then
	species=$(echo "$outdir" | sed "s|$ROOT_DIR||" | awk -F "/" '{print $3}' | sed 's/.\+/\L&/')
fi

export CLASS=$class
# export CLASS=${class,,}
export SPECIES=$species
# export SPECIES=${species,,}

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

# 7 - remove status files
rm -f $outdir/RAMPAGE.DONE

# 8 - print environemnt details
if [[ ! -v ROOT_DIR && ! -f "$ROOT_DIR/CONFIG.DONE" ]]; then
	echo "Environment variables have not been successfuly configured yet." 1>&2
	exit 1
fi

{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo -e "CALL: $args (wd: $(pwd))\n"
} 1>&2

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

	export WORKDIR=$outdir
fi

# check that there are either 2 or 3 columns
num_cols=$(awk '{print NF}' $input | sort -u)
if [[ "$num_cols" -eq 2 ]]; then
	#	touch $outdir/SINGLE.END
	export PAIRED=false
elif [[ "$num_cols" -eq 3 ]]; then
	#	touch $outdir/PAIRED.END
	export PAIRED=true
else
	print_error "There are too many columns in the input TXT file."
fi

if [[ "$stranded" = true ]]; then
	#	touch $outdir/STRANDED.LIB
	export STRANDED=true
else
	#	touch $outdir/NONSTRANDED.LIB
	export STRANDED=false
fi

{
	echo "EXPORTED VARIABLES:"
	print_line
	echo "WORKDIR=$outdir"
	echo "PAIRED=$PAIRED"
	echo "STRANDED=$STRANDED"
	echo "CLASS=$CLASS"
	echo "SPECIES=$SPECIES"
	print_line
	echo
} 1>&2
# class=$(echo "$outdir" | sed "s|$ROOT_DIR/\?||" | awk -F "/" '{print $1}')
# if [[ -n $class ]]; then
# 	touch $outdir/${class^^}.CLASS
# else
# 	print_error "Invalid class taxon in the parent directory name: $(dirname $input | sed "s|$ROOT_DIR/\?||")."
# fi

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
db=$ROOT_DIR/amp_seqs/amps.${CLASS^}.prot.combined.faa
if [[ ! -s $db ]]; then
	print_error "Reference AMP sequences not found in $db."
fi

# RUN THE PIPELINE USING THE MAKE FILE
mkdir -p $outdir/logs
echo "Running rAMPage..." 1>&2
if [[ "$verbose" = true ]]; then
	/usr/bin/time -pv make INPUT=$input $threads PARALLEL=$parallel VERBOSE=$verbose $email_opt -C $outdir -f $ROOT_DIR/scripts/Makefile 2>&1 | tee $outdir/logs/00-rAMPage.log 1>&2
else
	make INPUT=$input $threads PARALLEL=$parallel VERBOSE=$verbose $email_opt -C $outdir -f $ROOT_DIR/scripts/Makefile 2>&1 | tee $outdir/logs/00-rAMPage.log 1>&2
fi

# if [[ "$?" -ne 0 ]]; then
# 	failed=true
# 	file=$(ls -t $outdir/logs/*.log | head -n1)
# 	echo "FAILED! Last logfile: $(realpath $file)" 1>&2
# 	print_line
# 	cat $file 1>&2
# 	print_line
# echo "Cleaning directory $outdir..." 1>&2
# make INPUT=$input -C $outdir -f $ROOT_DIR/scripts/Makefile clean
# fi

echo -e "\nEND: $(date)" 1>&2

# if [[ "$failed" = true ]]; then
# 	echo -e "\nSTATUS: FAILED." 1>&2
# else
# 	echo -e "\nSTATUS: DONE." 1>&2
# fi
echo -e "\nSTATUS: DONE" 1>&2
touch $outdir/RAMPAGE.DONE

if [[ "$email" = true ]]; then
	species=$(echo "$SPECIES" | sed 's/^./\u&. /')
	# echo "$outdir" | mail -s "${species^}: rAMPage: SUCCESS" "$address"
	echo "$outdir" | mail -s "${species}: rAMPage: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
