#!/usr/bin/env bash

set -euo pipefail
PROGRAM=$(basename $0)
args="$PROGRAM $*"
function get_help() {
	echo "DESCRIPTION:" 1>&2
	echo -e "\
		\tTakes a protein FASTA file as input and predicts a secondary structure and RSA score.\n\
		" | column -s $'\t' -t 1>&2
	echo 1>&2

	echo "USAGE(S):" 1>&2
	echo -e "\
		\t$PROGRAM [OPTIONS] -o <output directory> <protein FASTA file>\n \
		" | column -s $'\t' -t 1>&2
	echo 1>&2

	echo "OPTION(S):" 1>&2
	echo -e "\
		\t-a <address>\temail address for alert\n \
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n\
		\t-t <INT>\tnumber of threads\t(default = 8)\n \
		" | column -s $'\t' -t 1>&2

	exit 1
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
threads=8
email=false
outdir=""
while getopts :a:ho:t: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	h) get_help ;;
	o)
		outdir=$(realpath $OPTARG)
		;;
	t) threads=$OPTARG ;;
	\?)
		echo "ERROR: Invalid option: -$OPTARG" 1>&2
		printf '%.0s=' $(seq $(tput cols)) 1>&2
		echo 1>&2
		get_help
		;;
	esac
done

shift $((OPTIND - 1))

if [[ "$#" -eq 0 ]]; then
	get_help
fi

if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

if [[ -z $outdir ]]; then
	print_error "Required argument -o <output directory> missing."
else
	mkdir -p $outdir
fi

{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo "CALL: $args (wd: $(pwd))"
	echo -e "THREADS: $threads\n"
} 1>&2

echo "PROGRAM: $(command -v $RUN_SABLE)"
echo -e "VERSION: $(grep "SABLE ver" $RUN_SABLE | awk '{print $NF}')\n"

echo "PROGRAM: $(command -v $BLAST_DIR/psiblast)" 1>&2
echo -e "VERSION: $($BLAST_DIR/psiblast -version | tail -n1 | cut -f4- -d' ')\n" 1>&2

# if workdir is unbound then
if [[ ! -v WORKDIR ]]; then
	# get workdir from input
	workdir=$(dirname $outdir)
else
	workdir=$(realpath $WORKDIR)
fi

if [[ ! -v SPECIES ]]; then
	# get species from workdir
	species=$(echo "$workdir" | awk -F "/" '{print $(NF-1)}' | sed 's/^./&./')
else
	species=$SPECIES
fi
fasta=$(realpath $1)

if [[ ! -s $fasta ]]; then
	if [[ ! -f $fasta ]]; then
		print_error "Input file does not exist."
	else
		print_error "Input file is empty!"
	fi
fi

# This script differs, as it must be run in the output directory.
echo "Predicting secondary structures using SABLE..." 1>&2
# echo -e "COMMAND: (cd $outdir && cp $fasta $outdir/data.seq && $RUN_SABLE $threads &>$outdir/sable.log)\n" 1>&2
# (cd $outdir && cp $fasta $outdir/data.seq && $RUN_SABLE $threads &>$outdir/sable.log)
echo -e "COMMAND: (cd $outdir && ln -fs $fasta $outdir/data.seq && $RUN_SABLE $threads &>$outdir/sable.log)\n" 1>&2
(cd $outdir && ln -fs $fasta $outdir/data.seq && $RUN_SABLE $threads &>$outdir/sable.log)

if [[ -s $outdir/OUT_SABLE_graph ]]; then
	echo "Parsing SABLE TXT output into a TSV format..." 1>&2
	echo -e "COMMAND: $ROOT_DIR/scripts/process-sable.sh $outdir/OUT_SABLE_graph &>>$outdir/sable.log\n" 1>&2
	$ROOT_DIR/scripts/process-sable.sh $outdir/OUT_SABLE_graph &>>$outdir/sable.log

	# combine AMPlify score with this file
else
	touch $outdir/SABLE.FAIL

	if [[ "$email" = true ]]; then
		#		org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		#		echo "$outdir" | mail -s "Failed SABLE run on $org" $address
		echo "$outdir" | mail -s "${species^}: STAGE XX: SABLE: FAILED" $address
		echo "Email alert sent to $address." 1>&2
	fi

	exit 2
fi

default_name="$(realpath -s $(dirname $outdir)/sable)"
if [[ "$default_name" != "$outdir" ]]; then
	if [[ -d "$default_name" ]]; then
		count=1
		if [[ ! -L "$default_name" ]]; then
			temp="${default_name}-${count}"
			while [[ -d "$temp" ]]; do
				count=$((count + 1))
				temp="${default_name}-${count}"
			done
			echo -e "Since $default_name already exists, $default_name is renamed to $temp as to not overwrite old files.\n" 1>&2
			mv $default_name $temp
		else
			unlink $default_name
		fi
	fi
	echo -e "$outdir softlinked to $default_name\n" 1>&2
	(cd $(dirname $outdir) && ln -fs $(basename $outdir) $(basename $default_name))
fi

echo -e "END: $(date)\n" 1>&2
echo -e "STATUS: DONE.\n" 1>&2
echo "Output: $outdir/SABLE_results.tsv" 1>&2
touch $outdir/SABLE.DONE

if [[ "$email" = true ]]; then
	#	echo "$outdir" | mail -s "Finished running SABLE" $address
	species=$(echo "$species" | sed 's/^./\u&. /')
	echo "$outdir" | mail -s "${species}: STAGE 13: SABLE: SUCCESS" "$address"
	# echo "$outdir" | mail -s "${species^}: STAGE 12: SABLE: SUCCESS"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
