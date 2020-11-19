#!/bin/bash
set -euo pipefail
PROGRAM=$(basename $0)

# 1 - get_help function
function get_help() {
	{
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
        " | column -s $'\t' -t -L

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] -o <output directory> <input FASTA file>\n \
        " | column -s $'\t' -t -L

		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail alert\n \
		\t-h\tshow this help menu\n \
		\t-o <DIRECTORY>\toutput directory\t(required)\n \
        " | column -s $'\t' -t -L
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

# default options
email=false

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
		mkdir -p $outdir
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
if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "input file $(realpath $1) is empty."
fi

# 7 - remove status files
rm -f $outdir/TRANSLATION.FAIL
rm -f $outdir/TRANSLATION.DONE

# 8 - print env details
echo -e "PATH=$PATH\n" 1>&2
echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)\n" 1>&2
# start_sec=$(date '+%s')

input=$(realpath $1)

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
	touch $outdir/TRANSLATION.DONE
	if [[ "$email" = true ]]; then
		org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		echo "$outdir" | mail -s "Finished translating transcripts for $org with TransDecoder" $address
	fi
else
	touch $outdir/TRANSLATION.FAIL
	if [[ "$email" = true ]]; then
		org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		echo "$outdir" | mail -s "Failed translating transcripts for $org TransDecoder" $address
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
# end_sec=$(date '+%s')
# $ROOT_DIR/scripts/get-runtime.sh -T $start_sec $end_sec 1>&2
# echo 1>&2
echo "STATUS: complete." 1>&2
