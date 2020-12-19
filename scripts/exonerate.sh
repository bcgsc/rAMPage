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

# 1 - get_help
function get_help() {
	{
		echo -e "PROGRAM: $PROGRAM\n"
		echo "DESCRIPTION:"
		echo -e "\
	\tUses Exonerate to remove known AMP sequences.\n \
	" | table

		echo "USAGE(S):"
		echo -e "\
	\t$PROGRAM [-a <address>] [-f <TSV file>] [-t <target FASTA file>] -o <output directory> <query FASTA file>\n \
	" | table

		echo "OPTION(S):"
		echo -e "\
	\t-a <address>\temail address for alerts\n \
	\t-f <TSV>\tannotation TSV file\n \
	\t-h\tshow this help menu\n \
	\t-o <directory>\toutput directory\t(required)\n \
	\t-t <FASTA>\ttarget FASTA file\t(default = \$ROOT_DIR/amp_seqs/amps.\$CLASS.prot.combined.faa)\n \
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
target=""
outdir=""
email=false
file=""
# 4 - getopts
while getopts :a:f:ho:t: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	f) file="$(realpath $OPTARG)" ;;
	h) get_help ;;
	o) outdir=$(realpath $OPTARG) ;;
	t) target=$(realpath $OPTARG) ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

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

if [[ -n $file ]]; then
	if [[ ! -f $file ]]; then
		print_error "TSV file $file does not exist."
	elif [[ ! -s $file ]]; then
		print_error "TSV file $file is empty."
	fi
fi

# if workdir not set, infer from indir
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

if [[ ! -v CLASS ]]; then
	class=$(echo "$workdir" | awk -F "/" '{print $(NF-2)}')
else
	class=$CLASS
fi

if [[ -z "$target" ]]; then
	target=$ROOT_DIR/amp_seqs/amps.${class^}.prot.combined.faa
fi
# 8 - print env details
{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo -e "CALL: $args (wd: $(pwd))\n"
} 1>&2

query=$(realpath $1)

echo "PROGRAM: $(command -v $RUN_EXONERATE)" 1>&2
echo -e "VERSION: $($RUN_EXONERATE --version 2>&1 | head -n1 | awk '{print $NF}')\n" 1>&2

echo "Running Exonerate..." 1>&2
echo -e "COMMAND: $RUN_EXONERATE --query $query --target $target --querytype protein --targettype protein --ryo "Summary: %qi %ti %pi\n" --showvulgar false >$outdir/amps.exonerate.out\n" 1>&2
$RUN_EXONERATE --query $query --target $target --querytype protein --targettype protein --ryo "Summary: %qi %ti %pi\n" --showvulgar false >$outdir/amps.exonerate.out

echo "Extracting summary..." 1>&2
echo -e "COMMAND: grep '^Summary:' $outdir/amps.exonerate.out | cut -d' ' -f2- $outdir/amps.exonerate.summary.out\n" 1>&2
grep '^Summary:' $outdir/amps.exonerate.out | cut -d' ' -f2- >$outdir/amps.exonerate.summary.out

echo "Filtering for known AMPs..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq $query <(awk '{print \$1}' $outdir/amps.exonerate.summary.out | sort -u) >$outdir/known.amps.exonerate.nr.faa\n" 1>&2
$RUN_SEQTK subseq $query <(awk '{print $1}' $outdir/amps.exonerate.summary.out | sort -u) >$outdir/known.amps.exonerate.nr.faa

echo "Labelling known AMPs..." 1>&2
echo -e "COMMAND: sed -i '/^>/ s/ length=/_known&/' $outdir/known.amps.exonerate.nr.faa" 1>&2
sed -i '/^>/ s/ length=/_known&/' $outdir/known.amps.exonerate.nr.faa

echo "Filtering for novel AMPs..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq $query <(grep -vFf <(awk '{print \$1}' $outdir/amps.exonerate.summary.out | sort -u) <(grep '^>' $query | tr -d '>' | sort -u)) >$outdir/novel.amps.exonerate.nr.faa\n" 1>&2
$RUN_SEQTK subseq $query <(grep -vFf <(awk '{print $1}' $outdir/amps.exonerate.summary.out | sort -u) <(grep '^>' $query | tr -d '>')) >$outdir/novel.amps.exonerate.nr.faa

echo "Labelling novel AMPs..." 1>&2
echo -e "COMMAND: sed -i '/^>/ s/ length=/_novel&/' $outdir/novel.amps.exonerate.nr.faa\n" 1>&2
sed -i '/^>/ s/ length=/_novel&/' $outdir/novel.amps.exonerate.nr.faa

echo "Combining the two files..." 1>&2
echo -e "COMMAND: cat $outdir/known.amps.exonerate.nr.faa $outdir/novel.amps.exonerate.nr.faa >$outdir/labelled.amps.exonerate.nr.faa\n" 1>&2
cat $outdir/known.amps.exonerate.nr.faa $outdir/novel.amps.exonerate.nr.faa >$outdir/labelled.amps.exonerate.nr.faa

if [[ -n $file ]]; then
	echo "Filtering annotations for novel AMPs..." 1>&2
	head -n1 $file >$outdir/annotated.novel.amps.tsv
	echo -e "COMMAND: grep -Ff <(awk '{print $1}' $outdir/amps.exonerate.summary.out) $file >>$outdir/annotated.novel.amps.tsv" 1>&2
	grep -Ff <(awk '{print $1}' $outdir/amps.exonerate.summary.out) $file >>$outdir/annotated.novel.amps.tsv
fi

default_name="$(realpath -s $(dirname $outdir)/exonerate)"
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
echo -e "END: $(date)\n" 1>&2
# echo 1>&2

echo -e "STATUS: DONE.\n" 1>&2
touch $outdir/EXONERATE.DONE

if [[ -n $file ]]; then
	echo -e "Output(s): $outdir/novel.amps.exonerate.nr.faa\n $outdir/annotated.novel.amps.tsv\
	" | column -s ' ' -t 1>&2
else
	echo "Output: $outdir/novel.amps.exonerate.nr.faa" 1>&2
fi

if [[ "$email" = true ]]; then
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	species=$(echo "$species" | sed 's/^./\u&. /')
	echo "$outdir" | mail -s "${species}: STAGE 12: EXONERATE: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
