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

# 1 - get_help
function get_help() {
	{
		echo -e "PROGRAM: $PROGRAM\n"
		echo "DESCRIPTION:"
		if [[ ! -v CLASS ]]; then
			echo -e "\
		\tUses Exonerate to remove known AMP sequences. Known AMP sequences are:\n \
		\t- amp_seqs/amps.\$CLASS.prot.precursor.faa\n \
		\t- amp_seqs/amps.\$CLASS.prot.mature.faa\n \
		" | table
		else
			echo -e "\
			\tUses Exonerate to remove known AMP sequences. Known AMP sequences are:\n \
			\t- amp_seqs/amps.$CLASS.prot.precursor.faa\n \
			\t- amp_seqs/amps.$CLASS.prot.mature.faa\n \
		" | table
		fi
		echo "USAGE(S):"
		echo -e "\
	\t$PROGRAM [-a <address>] [-h] -o <output directory> <query FASTA file> <annotation TSV file>\n \
	" | table

		echo "OPTION(S):"
		echo -e "\
	\t-a <address>\temail address for alerts\n \
	\t-h\tshow this help menu\n \
	\t-o <directory>\toutput directory\t(required)\n \
	" | table

		echo "EXAMPLE(S):"
		echo -e "\
	\t$PROGRAM -a user@example.com -o /path/to/exonerate/outdir /path/to/annotation/amps.final.annotated.faa /path/to/annotation/final_annotations.final.tsv\n \
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
outdir=""
email=false
# 4 - getopts
while getopts :a:ho: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	h) get_help ;;
	o) outdir=$(realpath $OPTARG) ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

if [[ "$#" -ne 2 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 - check input files
if [[ -z $outdir ]]; then
	print_error "Required argument -o <output directory> missing."
else
	mkdir -p $outdir
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
if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	#	print_error "Input file $(realpath $1) is empty."
	# elif [[ $(wc -l $(realpath $1) | awk '{print $1}') -eq 1 ]]; then
	echo "Input file $(realpath $1) is empty. There are no sequences to align."
	rm -f $outdir/EXONERATE.FAIL
	touch $outdir/EXONERATE.DONE
	echo -e "Query Sequence\tTop Precursor\tPrecursor Hits" >$outdir/annotation.precursor.tsv
	echo -e "Query Sequence\tTop Mature\tMature Hits" >$outdir/annotation.mature.tsv
	touch $outdir/amps.exonerate.some_none.nr.faa
	join -t$'\t' $outdir/annotation.precursor.tsv $outdir/annotation.mature.tsv >$outdir/annotation.tsv
	if [[ -s $(realpath $2) && $(wc -l $(realpath $1) | awk '{print $1}') -eq 1 ]]; then
		cp $(realpath $2) $outdir
		join -t $'\t' $outdir/annotation.tsv $(realpath $2) >$outdir/final_annotation.tsv
	else
		(cd $outdir && ln -fs annotation.tsv final_annotation.tsv)
	fi
	exit 0
	# print_error "Input file $(realpath $1) is empty."
fi

if [[ ! -f $(realpath $2) ]]; then
	print_error "Input file $(realpath $2) does not exist."
elif [[ ! -s $(realpath $2) ]]; then
	print_error "Input file $(realpath $2) is empty."
fi

# 8 - print env details
{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo -e "CALL: $args (wd: $(pwd))\n"
} 1>&2

query=$(realpath $1)
file=$(realpath $2)
cp $file $outdir/EnTAP_annotation.tsv
file=$outdir/EnTAP_annotation.tsv

echo "PROGRAM: $(command -v $RUN_EXONERATE)" 1>&2
echo -e "VERSION: $($RUN_EXONERATE --version 2>&1 | head -n1 | awk '{print $NF}')\n" 1>&2

# target1=$ROOT_DIR/amp_seqs/amps.${class^}.prot.combined.faa
target1=$ROOT_DIR/amp_seqs/amps.${class^}.prot.precursor.faa
target2=$ROOT_DIR/amp_seqs/amps.${class^}.prot.mature.faa

echo "Running Exonerate..." 1>&2

{
	echo "Query: $query"
	echo "Target: $target1"
	echo
} 1>&2
echo -e "COMMAND: $RUN_EXONERATE --query $query --target $target1 --querytype protein --targettype protein --ryo \"Summary: %qi\\\t%ti\\\t%td\\\t%pi\\\n\" --showvulgar false >$outdir/amps.exonerate.out\n" 1>&2
$RUN_EXONERATE --query $query --target $target1 --querytype protein --targettype protein --ryo "Summary: %qi\t%ti\t%td\t%pi\n" --showvulgar false >$outdir/amps.exonerate.out

exonerate_success=false
if [[ "$(wc -l $outdir/amps.exonerate.out | awk '{print $1}')" -gt 3 ]]; then
	# there are known AMPs!
	exonerate_success=true
	echo "Extracting summary..." 1>&2
	echo -e "COMMAND: grep '^Summary:' $outdir/amps.exonerate.out | cut -d' ' -f2- >>$outdir/amps.exonerate.summary.out\n" 1>&2
	echo -e "Query\tTarget\tDescription\tPercent Identity" >$outdir/amps.exonerate.summary.out
	grep '^Summary:' $outdir/amps.exonerate.out | cut -d' ' -f2- | sort -k4,4gr -t $'\t' >>$outdir/amps.exonerate.summary.out

	echo "Filtering for AMPs with 100% alignment..." 1>&2
	amps_100_list=$outdir/amps.exonerate.100.txt
	amps_100_fasta=$outdir/amps.exonerate.100.nr.faa
	echo "COMMAND: awk -F \"\t\" '{if(\$4==100) print \$1}' $outdir/amps.exonerate.summary.out | sort -u >$amps_100_list"
	awk -F "\t" '{if($4==100) print $1}' $outdir/amps.exonerate.summary.out | sort -u >$amps_100_list
	echo -e "COMMAND: $RUN_SEQTK subseq $query $amps_100_list >$amps_100_fasta\n" 1>&2
	$RUN_SEQTK subseq $query $amps_100_list >$amps_100_fasta

	echo "Filtering for AMPs with some alignment..." 1>&2
	amps_some_list=$outdir/amps.exonerate.some.txt
	amps_some_fasta=$outdir/amps.exonerate.some.nr.faa
	echo "COMMAND: grep -Fxvf $amps_100_list <(awk -F \"\t\" '{print \$1}' <(tail -n +2 $outdir/amps.exonerate.summary.out) | sort -u) > $amps_some_list || true" 1>&2
	grep -Fxvf $amps_100_list <(awk -F "\t" '{print $1}' <(tail -n +2 $outdir/amps.exonerate.summary.out) | sort -u) >$amps_some_list || true
	echo -e "COMMAND: $RUN_SEQTK subseq $query $amps_some_list >$amps_some_fasta\n" 1>&2
	$RUN_SEQTK subseq $query $amps_some_list >$amps_some_fasta

	echo "Filtering for AMPs with no alignment..." 1>&2
	amps_none_list=$outdir/amps.exonerate.none.txt
	amps_none_fasta=$outdir/amps.exonerate.none.nr.faa
	echo "COMMAND: grep -Fvxf <(cat $amps_100_list $amps_some_list) <(awk '/^>/ {print \$1}' $query | tr -d '>' | sort -u) > $amps_none_list || true" 1>&2
	grep -Fvxf <(cat $amps_100_list $amps_some_list) <(awk '/^>/ {print $1}' $query | tr -d '>' | sort -u) >$amps_none_list || true
	echo -e "COMMAND: $RUN_SEQTK subseq $query $amps_none_list > $amps_none_fasta\n" 1>&2
	$RUN_SEQTK subseq $query $amps_none_list >$amps_none_fasta

	echo "Filtering for AMPs with some or no alignment..." 1>&2
	amps_some_none_list=$outdir/amps.exonerate.some_none.txt
	amps_some_none_fasta=$outdir/amps.exonerate.some_none.nr.faa
	echo "COMMAND: cat $amps_some_list $amps_none_list | sort -u >$amps_some_none_list" 1>&2
	cat $amps_some_list $amps_none_list | sort -u >$amps_some_none_list
	echo -e "COMMAND: $RUN_SEQTK subseq $query $amps_some_none_list > $amps_some_none_fasta\n" 1>&2
	$RUN_SEQTK subseq $query $amps_some_none_list >$amps_some_none_fasta

	echo "Running Exonerate..." 1>&2
	{
		echo "Query: $query"
		echo "Target: $target2"
		echo
	} 1>&2

	echo -e "COMMAND: $RUN_EXONERATE --query $query --target $target2 --querytype protein --targettype protein --ryo \"Summary: %qi\\\t%ti\\\t%td\\\t%pi\\\n\" --showvulgar false >$outdir/amps.exonerate.mature.out\n" 1>&2
	$RUN_EXONERATE --query $query --target $target2 --querytype protein --targettype protein --ryo "Summary: %qi\t%ti\t%td\t%pi\n" --showvulgar false >$outdir/amps.exonerate.mature.out

	exonerate_mature_success=false
	if [[ "$(wc -l $outdir/amps.exonerate.mature.out | awk '{print $1}')" -gt 3 ]]; then
		exonerate_mature_success=true
		echo "Extracting summary..." 1>&2
		echo -e "COMMAND: grep '^Summary:' $outdir/amps.exonerate.mature.out | cut -d' ' -f2- >>$outdir/amps.exonerate.mature.summary.out\n" 1>&2
		echo -e "Query\tTarget\tDescription\tPercent Identity" >$outdir/amps.exonerate.mature.summary.out
		grep '^Summary:' $outdir/amps.exonerate.mature.out | cut -d' ' -f2- | sort -k4,4gr -t $'\t' >>$outdir/amps.exonerate.mature.summary.out

		echo "Filtering for AMPs with 100% alignment..." 1>&2
		amps_mature_100_list=$outdir/amps.exonerate.mature.100.txt
		amps_mature_100_fasta=$outdir/amps.exonerate.mature.100.nr.faa
		echo "COMMAND: awk -F \"\t\" '{if(\$4==100) print \$1}' $outdir/amps.exonerate.mature.summary.out | sort -u >$amps_mature_100_list"
		awk -F "\t" '{if($4==100) print $1}' $outdir/amps.exonerate.mature.summary.out | sort -u >$amps_mature_100_list
		echo -e "COMMAND: $RUN_SEQTK subseq $query $amps_mature_100_list >$amps_mature_100_fasta\n" 1>&2
		$RUN_SEQTK subseq $query $amps_mature_100_list >$amps_mature_100_fasta

		echo "Filtering for AMPs with some alignment..." 1>&2
		amps_mature_some_list=$outdir/amps.exonerate.mature.some.txt
		amps_mature_some_fasta=$outdir/amps.exonerate.mature.some.nr.faa
		echo "COMMAND: grep -Fxvf $amps_mature_100_list <(awk -F \"\t\" '{print \$1}' <(tail -n +2 $outdir/amps.exonerate.summary.out) | sort -u) > $amps_mature_some_list || true" 1>&2
		grep -Fxvf $amps_mature_100_list <(awk -F "\t" '{print $1}' <(tail -n +2 $outdir/amps.exonerate.summary.out) | sort -u) >$amps_mature_some_list || true
		echo -e "COMMAND: $RUN_SEQTK subseq $query $amps_mature_some_list >$amps_mature_some_fasta\n" 1>&2
		$RUN_SEQTK subseq $query $amps_mature_some_list >$amps_mature_some_fasta

		echo "Filtering for AMPs with no alignment..." 1>&2
		amps_mature_none_list=$outdir/amps.exonerate.mature.none.txt
		amps_mature_none_fasta=$outdir/amps.exonerate.mature.none.nr.faa
		echo "COMMAND: grep -Fvxf <(cat $amps_mature_100_list $amps_mature_some_list) <(awk '/^>/ {print \$1}' $query | tr -d '>' | sort -u) > $amps_mature_none_list || true" 1>&2
		grep -Fvxf <(cat $amps_mature_100_list $amps_mature_some_list) <(awk '/^>/ {print $1}' $query | tr -d '>' | sort -u) >$amps_mature_none_list || true
		echo -e "COMMAND: $RUN_SEQTK subseq $query $amps_mature_none_list > $amps_mature_none_fasta\n" 1>&2
		$RUN_SEQTK subseq $query $amps_mature_none_list >$amps_mature_none_fasta

		echo "Filtering for AMPs with some or no alignment..." 1>&2
		amps_mature_some_none_list=$outdir/amps.exonerate.mature.some_none.txt
		amps_mature_some_none_fasta=$outdir/amps.exonerate.mature.some_none.nr.faa
		echo "COMMAND: cat $amps_mature_some_list $amps_mature_none_list > $amps_mature_some_none_list" 1>&2
		cat $amps_mature_some_list $amps_mature_none_list >$amps_mature_some_none_list
		echo -e "COMMAND: $RUN_SEQTK subseq $query $amps_mature_some_none_list > $amps_mature_some_none_fasta\n" 1>&2
		$RUN_SEQTK subseq $query $amps_mature_some_none_list >$amps_mature_some_none_fasta

	else
		amps_mature_100_list=$outdir/amps.exonerate.mature.100.txt
		amps_mature_100_fasta=$outdir/amps.exonerate.mature.100.nr.faa
		touch $amps_mature_100_list
		touch $amps_mature_100_fasta

		amps_mature_some_list=$outdir/amps.exonerate.mature.some.txt
		amps_mature_some_fasta=$outdir/amps.exonerate.mature.some.nr.faa
		touch $amps_mature_some_list
		touch $amps_mature_some_fasta

		amps_mature_none_list=$outdir/amps.exonerate.mature.none.txt
		amps_mature_none_fasta=$outdir/amps.exonerate.mature.none.nr.faa
		(cd $outdir && ln -fs $query $(basename $amps_mature_none_fasta))
		awk '{print $1}' $amps_mature_none_fasta | tr -d '>' >$amps_mature_none_list

		amps_mature_some_none_list=$outdir/amps.exonerate.mature.some_none.txt
		amps_mature_some_none_fasta=$outdir/amps.exonerate.mature.some_none.nr.faa
		(cd $outdir && ln -fs $(basename $amps_mature_none_list) $(basename $amps_mature_some_none_list) && ln -fs $(basename $amps_mature_none_fasta) $(basename $amps_mature_some_none_fasta))
	fi

else

	# no known AMPs
	exonerate_mature_success=false
	amps_none_list=$outdir/amps.exonerate.none.txt
	amps_none_fasta=$outdir/amps.exonerate.none.nr.faa
	awk '/^>/ {print $1}' $query | tr -d '>' | sort -u >$amps_none_list
	(cd $outdir && ln -fs $query $(basename $amps_none_fasta))

	amps_100_list=$outdir/amps.exonerate.100.txt
	amps_100_fasta=$outdir/amps.exonerate.100.nr.faa
	touch $amps_100_list
	touch $amps_100_fasta

	amps_some_list=$outdir/amps.exonerate.some.txt
	amps_some_fasta=$outdir/amps.exonerate.some.nr.faa
	touch $amps_some_list
	touch $amps_some_fasta

	amps_some_none_list=$outdir/amps.exonerate.some_none.txt
	amps_some_none_fasta=$outdir/amps.exonerate.some_none.nr.faa
	(cd $outdir && ln -fs $(basename $amps_none_list) $(basename $amps_some_none_list) && ln -fs $(basename $amps_none_fasta) $(basename $amps_some_none_fasta))

fi

# should still add these to the annotation tSV
echo -e "Annotating...\n" 1>&2
if [[ "$exonerate_success" == true ]]; then
	echo -e "Query Sequence\tTop Precursor\tPrecursor Hits" >$outdir/annotation.precursor.tsv
	echo -e "Query Sequence\tTop Mature\tMature Hits" >$outdir/annotation.mature.tsv
	while read seq; do
		exonerate_precursor_top=$(sort -k4,4gr -t $'\t' $outdir/amps.exonerate.summary.out | grep -w "$seq" -m1 | awk -F "\t" '{print $2 ": " $3}' || true)

		sed -i "/$seq / s@\$@ top_precursor=$exonerate_precursor_top@" $amps_100_fasta $amps_some_fasta $amps_some_none_fasta $amps_none_fasta
		exonerate_results=$(awk -F "\t" -v var="$seq" 'BEGIN{ORS=";"}{if($1==var) print $2 "(" $4 "%)"}' <(sort -k4,4gr -t $'\t' $outdir/amps.exonerate.summary.out) | sed 's/;$/\n/')
		sed -i "/$seq / s/$/ precursor_hits=$exonerate_results/" $amps_none_fasta $amps_100_fasta $amps_some_fasta $amps_some_none_fasta
		if [[ -z "$exonerate_precursor_top" ]]; then
			exonerate_precursor_top=" "
		fi
		# parse through the annotation file and add the tsv file
		echo -e "$seq\t$exonerate_precursor_top\t$exonerate_results" >>$outdir/annotation.precursor.tsv
		if [[ "$exonerate_mature_success" == true ]]; then
			exonerate_mature_top=$(sort -k4,4gr -t $'\t' $outdir/amps.exonerate.mature.summary.out | grep -w "$seq" | head -n1 | awk -F "\t" '{print $2 ": " $3}' || true)
			if [[ -n "$exonerate_mature_top" ]]; then
				sed -i "/$seq / s@\$@ top_mature=$exonerate_mature_top@" $amps_mature_100_fasta $amps_mature_some_fasta $amps_mature_some_none_fasta $amps_mature_none_fasta
			else
				exonerate_mature_top=" "
			fi
			exonerate_results=$(awk -F "\t" -v var="$seq" 'BEGIN{ORS=";"}{if($1==var) print $2 "(" $4 "%)"}' <(sort -k4,4gr -t $'\t' $outdir/amps.exonerate.mature.summary.out) | sed 's/;$/\n/')
			sed -i "/$seq / s/$/ mature_hits=$exonerate_results/" $amps_mature_100_fasta $amps_mature_some_fasta $amps_mature_some_none_fasta $amps_mature_none_fasta
			# parse through the annotation file and add the tsv file
			echo -e "$seq\t$exonerate_mature_top\t$exonerate_results" >>$outdir/annotation.mature.tsv
		else
			echo -e "$seq\t \t " >>$outdir/annotation.mature.tsv
		fi
	done < <(cat $amps_100_list $amps_some_list | sort -u)

	while read seq; do
		echo -e "$seq\t \t " >>$outdir/annotation.precursor.tsv
		echo -e "$seq\t \t " >>$outdir/annotation.mature.tsv
	done <$amps_none_list
	join --header -t $'\t' <(LC_COLLATE=C sort -k1,1 $outdir/annotation.precursor.tsv) <(LC_COLLATE=C sort -k1,1 $outdir/annotation.mature.tsv) >$outdir/annotation.tsv
	join --header -t $'\t' <(LC_COLLATE=C sort -k1,1 $outdir/annotation.tsv) <(LC_COLLATE=C sort -k1,1 $outdir/EnTAP_annotation.tsv) >$outdir/final_annotation.tsv
else
	echo -e "Query Sequence\tTop Precursor\tPrecursor Hits" >$outdir/annotation.precursor.tsv
	echo -e "Query Sequence\tTop Mature\tMature Hits" >$outdir/annotation.mature.tsv
	while read seq; do
		echo -e "$seq\t \t " >>$outdir/annotation.precursor.tsv
		echo -e "$seq\t \t " >>$outdir/annotation.mature.tsv
	done < <(cat $amps_100_list $amps_some_list $amps_none_list | sort -u)

	join --header -t $'\t' <(LC_COLLATE=C sort -k1,1 $outdir/annotation.precursor.tsv) <(LC_COLLATE=C sort -k1,1 $outdir/annotation.mature.tsv) >$outdir/annotation.tsv
	join --header -t $'\t' <(LC_COLLATE=C sort -k1,1 $outdir/annotation.tsv) <(LC_COLLATE=C sort -k1,1 $outdir/EnTAP_annotation.tsv) >$outdir/final_annotation.tsv
fi

echo -e "RESULTS\n$(printf '%.0s-' $(seq 1 63))\n" 1>&2

num_total=$(grep -c '^>' $query || true)
if [[ "$exonerate_success" = true ]]; then
	# pid = 100%
	num_100=$(wc -l $amps_100_list | awk '{print $1}')
	num_some=$(wc -l $amps_some_list | awk '{print $1}')
	num_some_none=$(wc -l $amps_some_none_list | awk '{print $1}')
	num_none=$(wc -l $amps_none_list | awk '{print $1}')
	num_mature_100=$(wc -l $amps_mature_100_list | awk '{print $1}')
	num_mature_some=$(wc -l $amps_mature_some_list | awk '{print $1}')
	num_mature_some_none=$(wc -l $amps_mature_some_none_list | awk '{print $1}')
	num_mature_none=$(wc -l $amps_mature_none_list | awk '{print $1}')
	{
		echo -e "Number of AMPs (100% alignment to precursor AMPs):\t$(printf "%'d" $num_100)/$(printf "%'d" $num_total)"

		# present in exonerate results
		echo -e "Number of AMPs (some alignment to precursor AMPs):\t$(printf "%'d" $num_some)/$(printf "%'d" $num_total)"

		# pid < 100% or not present in exonerate results
		echo -e "Number of AMPs (some or no alignment to precursor AMPs):\t$(printf "%'d" $num_some_none)/$(printf "%'d" $num_total)"

		# not present in exonerate results
		echo -e "Number of AMPs (no alignment to precursor AMPs):\t$(printf "%'d" $num_none)/$(printf "%'d" $num_total)\n"

		echo -e "Number of AMPs (100% alignment to mature AMPs):\t$(printf "%'d" $num_mature_100)/$(printf "%'d" $num_total)"

		echo -e "Number of AMPs (some alignment to mature AMPs):\t$(printf "%'d" $num_mature_some)/$(printf "%'d" $num_total)"

		echo -e "Number of AMPs (some or no alignment to mature AMPs):\t$(printf "%'d" $num_mature_some_none)/$(printf "%'d" $num_total)"

		echo -e "Number of AMPs (no alignment to mature AMPs):\t$(printf "%'d" $num_mature_none)/$(printf "%'d" $num_total)\n"
	} | table 1>&2
	echo "Novelty defined as < 100% alignment..." 1>&2
	echo -e "Number of Novel AMPs: $(printf "%'d" $num_none)/$(printf "%'d" $num_total)\n" 1>&2
else
	echo "No alignments detected-- there are no alignments to known AMPs. All AMPs are novel!" 1>&2
	# echo "Novelty defined as < 100% alignment..." 1>&2
	num_total=$(grep -c '^>' $query || true)
	echo -e "Number of Novel AMPs: $(printf "%'d" $num_total)/$(printf "%'d" $num_total)\n" 1>&2
fi

if [[ -n $file ]]; then
	if [[ "$exonerate_mature_success" == true ]]; then
		echo -e "Output(s): $outdir/final_annotation.tsv\n $amps_some_none_fasta\n $amps_mature_some_none_fasta\n \
		" | column -s ' ' -t 1>&2
	else
		echo -e "Output(s): $outdir/final_annotation.tsv\n $amps_some_none_fasta\n \
		" | column -s ' ' -t 1>&2
	fi
else
	echo -e "Output: $amps_some_none_fasta\n" 1>&2
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
echo -e "\nEND: $(date)\n" 1>&2

echo -e "STATUS: DONE.\n" 1>&2
touch $outdir/EXONERATE.DONE

if [[ "$email" = true ]]; then
	species=$(echo "$species" | sed 's/^./\u&. /')
	echo "$outdir" | mail -s "${species}: STAGE 12: EXONERATE: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
