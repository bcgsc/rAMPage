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

function get_help() {
	{
		echo -e "PROGRAM: $PROGRAM\n"
		echo "DESCRIPTION:"
		echo -e "\
		\tTakes a protein FASTA file as input and predicts a secondary structure and RSA score.\n\
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-a <address>] [-h] [-t <int>] -o <output directory> <protein FASTA file> <protein TSV file>\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail address for alert\n \
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n\
		\t-t <INT>\tnumber of threads\t(default = 8)\n \
		" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -o /path/to/sable/outdir /path/to/exonerate/amps.exonerate.some_none.nr.faa  /path/to/exonerate/final_annotation.tsv\n \
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

if [[ "$#" -ne 2 ]]; then
	print_error "Incorrect number of arguments."
fi

if [[ -z $outdir ]]; then
	print_error "Required argument -o <output directory> missing."
else
	mkdir -p $outdir
fi

rm -f $outdir/SABLE.FAIL

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

if command -v mlr &>/dev/null; then
	mlr_join=true
else
	mlr_join=false
fi

tsv_file=$(realpath -s $2)
if [[ ! -s $tsv_file ]]; then
	if [[ ! -f $tsv_file ]]; then
		print_error "Input file $tsv_file does not exist."
	else
		print_error "Input file $tsv_file is empty!"
	fi
elif [[ "$tsv_file" != *.tsv ]]; then
	print_error "Input file $tsv_file is not a TSV file."
fi

fasta=$(realpath $1)
if [[ ! -f $fasta ]]; then
	print_error "Input file $fasta does not exist."
elif [[ ! -s $fasta ]]; then
	# print_error "Input file $fasta is empty!"
	echo "Input file $fasta is empty. There are no sequences to characterize." 1>&2
	echo -e "Sequence_ID\tSequence\tStructure\tStructure Confidence\tRSA\tRSA Confidence" >$outdir/SABLE_results.tsv
	# just do regular join and reorder tsv
	join --header -t$'\t' $tsv_file <(cut -d $'\t' -f 1,3- $outdir/SABLE_results.tsv) >$outdir/final_annotation.tsv
	rm -f $outdir/SABLE.FAIL
	touch $outdir/SABLE.DONE
	exit 0
elif [[ "$fasta" != *.fa* ]]; then
	print_error "Input file $fasta is not a FASTA file."
fi

{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo "CALL: $args (wd: $(pwd))"
	if [[ -L $tsv_file ]]; then
		echo -e "TSV: $(ls -l $tsv_file | awk '{print $(NF-2), $(NF-1), $NF}')\n"
	fi
	echo -e "THREADS: $threads\n"
} 1>&2

if [[ ! -v ROOT_DIR ]]; then
	print_error "ROOT_DIR is unbound. Please export ROOT_DIR=/path/to/rAMPage/GitHub/directory."
fi

if [[ ! -v RUN_SABLE ]]; then
	if command -v run.sable &>/dev/null; then
		RUN_SABLE=$(command -v run.sable)
	else
		print_error "RUN_SABLE is unbound and no 'run.sable' found in PATH. Please export RUN_SABLE=/path/to/run.sable."
	fi
elif ! command -v $RUN_SABLE &>/dev/null; then
	print_error "Unable to execute $RUN_SABLE."
fi

echo "PROGRAM: $(command -v $RUN_SABLE)"
echo -e "VERSION: $(grep "SABLE ver" $RUN_SABLE | awk '{print $NF}')\n"

if [[ ! -v BLAST_DIR ]]; then
	if command -v psiblast &>/dev/null; then
		BLAST_DIR=$(dirname $(realpath $(command -v psiblast)))
	else
		print_error "BLAST_DIR is unbound. Please export BLAST_DIR=/path/to/blast/bin."
	fi
elif ! command -v $BLAST_DIR/psiblast &>/dev/null; then
	print_error "Unable to execute $BLAST_DIR/psiblast."
fi

echo "PROGRAM: $(command -v $BLAST_DIR/psiblast)" 1>&2
echo -e "VERSION: $($BLAST_DIR/psiblast -version | tail -n1 | cut -f4- -d' ')\n" 1>&2

# This script differs, as it must be run in the output directory.
echo "Predicting secondary structures using SABLE..." 1>&2
# echo -e "COMMAND: (cd $outdir && cp $fasta $outdir/data.seq && $RUN_SABLE $threads &>$outdir/sable.log)\n" 1>&2
# (cd $outdir && cp $fasta $outdir/data.seq && $RUN_SABLE $threads &>$outdir/sable.log)
echo -e "COMMAND: (cd $outdir && ln -fs $fasta $outdir/data.seq && $RUN_SABLE $threads &>$outdir/sable.log)\n" 1>&2
(cd $outdir && ln -fs $fasta $outdir/data.seq && $RUN_SABLE $threads &>$outdir/sable.log)

if [[ "$(wc -l $outdir/OUT_SABLE_graph | awk '{print $1}')" -gt 2 ]]; then
	echo "Parsing SABLE TXT output into a TSV format..." 1>&2
	echo -e "COMMAND: $ROOT_DIR/scripts/process-sable.sh $fasta $outdir/OUT_SABLE_graph $tsv_file &>>$outdir/sable.log\n" 1>&2
	$ROOT_DIR/scripts/process-sable.sh $fasta $outdir/OUT_SABLE_graph &>>$outdir/sable.log

	if [[ "$mlr_join" = true ]]; then
		mlr --tsv join -f $tsv_file -j "Sequence_ID,Sequence" $outdir/SABLE_results.tsv >$outdir/final_annotation.tsv
	else
		join -t$'\t' --header $tsv_file <(cut -f1,3- -d$'\t' $outdir/SABLE_results.tsv) >$outdir/final_annotation.tsv
	fi

else

	echo -e "Sequence_ID\tSequence\tStructure\tStructure Confidence\tRSA\tRSA Confidence" >$outdir/SABLE_results.tsv
	echo -e " \t \t \t \t \t " >>$outdir/SABLE_results.tsv

	join -t$'\t' --header $tsv_file <(cut -f1,3- -d$'\t' $outdir/SABLE_results.tsv) >$outdir/final_annotation.tsv

	echo -e "STATUS: FAILED.\n" 1>&2
	touch $outdir/SABLE.FAIL

	if [[ "$email" = true ]]; then
		#		org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		#		echo "$outdir" | mail -s "Failed SABLE run on $org" $address
		echo "$outdir" | mail -s "${species^}: STAGE 13: SABLE: FAILED" $address
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
