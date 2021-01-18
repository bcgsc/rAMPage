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
	{
		echo -e "PROGRAM: $PROGRAM\n"
		echo "DESCRIPTION:"
		echo -e "\
		\tTakes transcripts and translates them into protein sequences.\n \
		\n \
		\tOUTPUT:\n \
		\t-------\n \
		\t  - rnabloom.transcripts.filtered.transdecoder.faa\n \
		\t  - TRANSLATION.DONE or TRANSLATION.FAIL\n \
		\n \
		\tEXIT CODES:\n \
		\t-----------\n \
		\t  - 0: successfully completed\n \
		\t  - 1: general error\n \
		\t  - 2: translation failed\n \
		\n \
		\tFor more information: http://transdecoder.github.io\n \
        " | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-a <address>] [-h] -o <output directory> <input FASTA file>\n \
        " | table

		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail address for alerts\n \
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n \
        " | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com -o /path/to/translation /path/to/filtering/rnabloom.transcripts.filtered.fa\n \
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

# default options
email=false
outdir=""

# 4 - read options
while getopts :a:ho: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	h) get_help ;;
	o)
		outdir=$(realpath $OPTARG)
		;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

# 5 - wrong arguments given
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
rm -f $outdir/TRANSLATION.FAIL
rm -f $outdir/TRANSLATION.DONE

# 8 - print env details
{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo -e "CALL: $args (wd: $(pwd))\n"
} 1>&2

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

input=$(realpath $1)

if [[ ! -v WORKDIR ]]; then
	workdir=$(dirname $outdir)
else
	workdir=$(realpath $WORKDIR)
fi

if [[ ! -v SPECIES ]]; then
	# get species from workdir
	species=$(echo "$workdir" | awk -F "/" '{print $(NF-1)}')
else
	species=$SPECIES
fi

cd $outdir

{
	echo "Extracting the long open reading frames..."
	echo "PROGRAM: $(command -v $TRANSDECODER_LONGORFS)"
	echo "VERSION: $($TRANSDECODER_LONGORFS --version | awk '{print $NF}')"
	echo -e "COMMAND: $TRANSDECODER_LONGORFS -O TransDecoder -m 50 -t $input &> TransDecoder.LongOrfs.log\n"
} 1>&2
$TRANSDECODER_LONGORFS -O TransDecoder -m 50 -t $input &>TransDecoder.LongOrfs.log

{
	echo "Predicting the likely coding regions..."
	echo "PROGRAM: $(command -v $TRANSDECODER_PREDICT)"
	echo "VERSION: $($TRANSDECODER_PREDICT --version | awk '{print $NF}')"
	echo -e "COMMAND: $TRANSDECODER_PREDICT -O TransDecoder -t $input &> TransDecoder.Predict.log\n"
} 1>&2

$TRANSDECODER_PREDICT -O TransDecoder -t $input &>TransDecoder.Predict.log
echo "PROGRAM: $(command -v $RUN_SEQTK)" 1>&2
seqtk_version=$($RUN_SEQTK 2>&1 || true)
echo "VERSION: $(echo "$seqtk_version" | awk '/Version:/ {print $NF}')" 1>&2
$RUN_SEQTK seq rnabloom.transcripts.filtered.fa.transdecoder.pep >rnabloom.transcripts.filtered.transdecoder.faa
sed -i 's/\*\+$//' rnabloom.transcripts.filtered.transdecoder.faa
sed -i 's/X\+$//' rnabloom.transcripts.filtered.transdecoder.faa
if [[ -s "rnabloom.transcripts.filtered.transdecoder.faa" ]]; then
	echo -e "Protein sequences: $outdir/rnabloom.transcripts.filtered.transdecoder.faa\n" 1>&2
	num_transcripts=$(grep -c '^>' $input)
	num_prot=$(grep -c '^>' rnabloom.transcripts.filtered.transdecoder.faa)
	echo "Number of transcripts: $(printf "%'d" $num_transcripts)" 1>&2
	echo -e "Number of valid ORFs: $(printf "%'d" $num_prot)" 1>&2
else
	touch $outdir/TRANSLATION.FAIL
	if [[ "$email" = true ]]; then
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
		echo "$outdir" | mail -s "${species^}: STAGE 07: TRANSLATION: FAILED" $address
		# echo "$outdir" | mail -s "Failed translating transcripts for $org TransDecoder" $address
		echo "Email alert sent to $address." 1>&2
	fi
	echo "ERROR: TransDecoder output file $outdir/rnabloom.transcripts.filtered.transdecoder.faa does not exist or is empty." 1>&2
	exit 2
fi

cd $ROOT_DIR

default_name="$(realpath -s $(dirname $outdir)/translation)"
if [[ "$default_name" != "$outdir" ]]; then
	count=1
	if [[ -d "$default_name" ]]; then
		if [[ ! -L "$default_name" ]]; then
			# if 'default' assembly directory already exists, then rename it.
			# rename it to name +1 so the assembly doesn't overwrite
			temp="${default_name}-${count}"
			while [[ -d "$temp" ]]; do
				count=$((count + 1))
				temp="${default_name}-${count}"
			done
			echo -e "Since $default_name already exists, $default_name is renamed to $temp as to not overwrite old assemblies.\n" 1>&2
			mv $default_name $temp
		else
			unlink $default_name
		fi
	fi
	if [[ "$default_name" != "$outdir" ]]; then
		echo -e "$outdir softlinked to $default_name\n" 1>&2
		(cd $(dirname $outdir) && ln -fs $(basename $outdir) $(basename $default_name))
	fi
fi
echo -e "END: $(date)\n" 1>&2

echo -e "STATUS: DONE.\n" 1>&2
touch $outdir/TRANSLATION.DONE

echo "Output: $outdir/rnabloom.transcripts.filtered.transdecoder.faa" 1>&2

if [[ "$email" = true ]]; then
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	# echo "$outdir" | mail -s "Finished translating transcripts for $org with TransDecoder" $address
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
	species=$(echo "$species" | sed 's/^./\u&. /')
	echo "$outdir" | mail -s "${species}: STAGE 07: TRANSLATION: SUCCESS" $address
	# echo "$outdir" | mail -s "${species^}: STAGE 07: TRANSLATION: SUCCESS" $address
	echo -e "\nEmail alert sent to ${address}." 1>&2
fi
