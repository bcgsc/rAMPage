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

# {
# 	echo "Query: $query"
# 	echo "Target: $target2"
# 	echo
# } 1>&2
#
# echo -e "COMMAND: $RUN_EXONERATE --query $query --target $target2 --querytype protein --targettype protein --ryo \"Summary: %qi %ti %pi\\\n\" --showvulgar false >$outdir/amps.exonerate.mature.out\n" 1>&2
# $RUN_EXONERATE --query $query --target $target2 --querytype protein --targettype protein --ryo "Summary: %qi %ti %pi\n" --showvulgar false >$outdir/amps.exonerate.mature.out
#
exonerate_success=false
if [[ "$(wc -l $outdir/amps.exonerate.out | awk '{print $1}')" -gt 3 ]]; then
	# there are known AMPs!
	exonerate_success=true
	echo "Extracting summary..." 1>&2
	echo -e "COMMAND: grep '^Summary:' $outdir/amps.exonerate.out | cut -d' ' -f2- >>$outdir/amps.exonerate.summary.out\n" 1>&2
	echo -e "Query\tTarget\tDescription\tPercent Identity" >$outdir/amps.exonerate.summary.out
	grep '^Summary:' $outdir/amps.exonerate.out | cut -d' ' -f2- | sort -k4,4gr -t $'\t' >>$outdir/amps.exonerate.summary.out

	# if [[ "$(wc -l $outdir/amps.exonerate.mature.out | awk '{print $1}')" -gt 3 ]]; then
	# 	echo -e "COMMAND: grep '^Summary:' $outdir/amps.exonerate.mature.out | cut -d' ' -f2- >$outdir/amps.exonerate.summary.mature.out\n" 1>&2
	# 	grep '^Summary:' $outdir/amps.exonerate.mature.out | cut -d' ' -f2- >$outdir/amps.exonerate.summary.mature.out
	# else
	# 	touch $outdir/amps.exonerate.summary.mature.out
	# fi

	# novel AMPs will be defined as those that have exonerate pid of <100 or no alignment at all, hence take from $query

	# take known list and do an inverse grep

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
	# echo "COMMAND: awk -F \"\t\" '{if(\$4!=100) print \$1}' $outdir/amps.exonerate.summary.out | sort -u >$amps_some_list" 1>&2
	# awk -F "\t" '{if($4!=100) print $1}' $outdir/amps.exonerate.summary.out | sort -u >$amps_some_list
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
	# 	echo "COMMAND: grep -Fxf <(cat $amps_some_list $amps_none_list | sort -u) <(awk '/^>/ {print $1}' $query | tr -d '>' | sort -u) > $amps_some_none_list || true" 1>&2
	# 	grep -Fxf <(cat $amps_some_list $amps_none_list | sort -u) <(awk '/^>/ {print $1}' $query | tr -d '>' | sort -u) >$amps_some_none_list || true
	# echo "COMMAND: grep -Fvxf $amps_100_list <(awk '/^>/ {print \$1}' $query | tr -d '>' | sort -u) >$amps_some_none_list || true" 1>&2
	# grep -Fvxf $amps_100_list <(awk '/^>/ {print $1}' $query | tr -d '>' | sort -u) >$amps_some_none_list || true
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
		# echo "COMMAND: awk -F \"\t\" '{if(\$4!=100) print \$1}' <(tail -n +2 $outdir/amps.exonerate.mature.summary.out) | sort -u >$amps_mature_some_list" 1>&2
		# awk -F "\t" '{if($4!=100) print $1}' <(tail -n +2 $outdir/amps.exonerate.mature.summary.out) | sort -u >$amps_mature_some_list
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
		# echo "COMMAND: grep -Fvxf $amps_mature_100_list <(awk '/^>/ {print \$1}' $query | tr -d '>' | sort -u) >$amps_mature_some_none_list || true" 1>&2
		# grep -Fvxf $amps_mature_100_list <(awk '/^>/ {print $1}' $query | tr -d '>' | sort -u) >$amps_mature_some_none_list || true
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

	# 	echo -e "Labelling known AMPs...\n" 1>&2
	# 	# echo -e "COMMAND: sed -i '/^>/ s/ length=/_known&/' $outdir/known.amps.exonerate.nr.faa" 1>&2
	# 	while read i; do
	# 		if [[ "$exonerate_mature_success" == true ]]; then
	# 			if grep -F -x -m 1 -q "$i" $known_amps_mature_list; then
	# 				sed -i "s/$i/$i-known_mature/" $outdir/known.amps.exonerate.nr.faa
	# 			else
	# 				sed -i "s/$i/$i-known/" $outdir/known.amps.exonerate.nr.faa
	# 			fi
	# 		else
	# 			sed -i "s/$i/$i-known/" $outdir/known.amps.exonerate.nr.faa
	# 		fi
	# 	done <$known_amps_list
	#
	# 	if [[ "$exonerate_mature_success" == true ]]; then
	# 		sed -i '/^>/ s/ length=/-known_mature&/' $outdir/known.amps.exonerate.mature.nr.faa
	# 	else
	# 		touch $outdir/known.amps.exonerate.mature.nr.faa
	# 	fi

	# label with known AMP accession
	# 	while IFS=' ' read novel known; do
	# 		sed -i "/${novel}/ s/$/ exonerate=$known/" $outdir/known.amps.exonerate.nr.faa
	# 	done < <(awk -F "\t" '{if($3==100) print $1, $2}' $outdir/amps.exonerate.summary.out | sort -u)

	# while IFS=' ' read novel known; do
	# 	sed -i "/${novel}-known/ s/$/ exonerate=$known/" $outdir/known.amps.exonerate.nr.faa
	# done < <(awk -F "\t" '{if($3==100) print $1, $2}' $outdir/amps.exonerate.summary.out | sort -u)

	# label with known AMP accession

	# 	if [[ "$exonerate_mature_success" == true ]]; then
	# 		while IFS=' ' read novel known; do
	# 			sed -i "/${novel}-known_mature/ s/$/ exonerate=$known/" $outdir/known.amps.exonerate.mature.nr.faa
	# 		done < <(awk -F "\t" '{if($4==100) print $1, $2}' $outdir/amps.exonerate.mature.summary.out | sort -u)
	# 	else
	# 		touch $outdir/known.amps.exonerate.mature.nr.faa
	# 	fi
	#
	# 	echo "Filtering for novel AMPs..." 1>&2
	# 	echo -e "COMMAND: $RUN_SEQTK subseq $query $novel_amps_list >$outdir/novel.amps.exonerate.nr.faa\n" 1>&2
	# 	$RUN_SEQTK subseq $query $novel_amps_list >$outdir/novel.amps.exonerate.nr.faa
	#
	# 	echo "Running Exonerate..." 1>&2
	# 	{
	# 		echo "Query: $outdir/novel.amps.exonerate.nr.faa"
	# 		echo "Target: $target2"
	# 		echo
	# 	} 1>&2
	#
	# 	echo -e "COMMAND: $RUN_EXONERATE --query $outdir/novel.amps.exonerate.nr.faa --target $target2 --querytype protein --targettype protein --ryo \"Summary: %qi\\\t%ti\\\t%td\\\t%pi\\\n\" --showvulgar false >$outdir/amps.exonerate.mature.out\n" 1>&2
	# 	$RUN_EXONERATE --query $outdir/novel.amps.exonerate.nr.faa --target $target2 --querytype protein --targettype protein --ryo "Summary: %qi\t%ti\t%td\t%pi\n" --showvulgar false >$outdir/amps.exonerate.novel.mature.out
	#
	# 	exonerate_novel_mature_success=false
	# 	if [[ "$(wc -l $outdir/amps.exonerate.novel.mature.out | awk '{print $1}')" -gt 3 ]]; then
	# 		exonerate_novel_mature_success=true
	# 		echo "Extracting summary..." 1>&2
	# 		echo -e "COMMAND: grep '^Summary:' $outdir/amps.exonerate.novel.mature.out | cut -d' ' -f2- >$outdir/amps.exonerate.novel.mature.summary.out\n" 1>&2
	# 		echo -e "Query\tTarget\tDescription\tPercent Identity" >$outdir/amps.exonerate.novel.mature.summary.out
	# 		grep '^Summary:' $outdir/amps.exonerate.novel.mature.out | cut -d' ' -f2- | sort -k4,4gr >>$outdir/amps.exonerate.novel.mature.summary.out
	#
	# 		novel_amps_mature_list=$outdir/amps.exonerate.novel.mature.txt
	# 		# get unaligned AMPs from this exonerate run
	# 		awk -F "\t" '{if($4==100) print $1}' $outdir/amps.exonerate.novel.mature.summary.out | sort -u >$novel_amps_mature_list
	#
	# 		echo -e "COMMAND: $RUN_SEQTK subseq $query $novel_amps_mature_list >$outdir/novel.amps.exonerate.mature.nr.faa\n" 1>&2
	# 		$RUN_SEQTK subseq $query $novel_amps_mature_list >$outdir/novel.amps.exonerate.mature.nr.faa
	#
	# 		awk -F "\t" '{print $1}' $outdir/amps.exonerate.novel.mature.summary.out | sort -u >$outdir/amps.exonerate.novel.mature.aligned.txt
	#
	# 		$RUN_SEQTK subseq $query $outdir/amps.exonerate.novel.mature.aligned.txt >$outdir/novel.amps.exonerate.mature.aligned.nr.faa
	# 	else
	# 		touch $outdir/novel.amps.exonerate.mature.nr.faa
	# 	fi

	# echo -e "COMMAND: $RUN_SEQTK subseq $query <(grep -vFf <(awk '{print \$1}' $outdir/amps.exonerate.summary.out | sort -u) <(grep '^>' $query | tr -d '>' | sort -u)) >$outdir/novel.amps.exonerate.nr.faa\n" 1>&2
	# $RUN_SEQTK subseq $query <(grep -vFf <(awk '{print $1}' $outdir/amps.exonerate.summary.out | sort -u) <(grep '^>' $query | tr -d '>')) >$outdir/novel.amps.exonerate.nr.faa

	# echo -e "Labelling novel AMPs...\n" 1>&2

	# while read i; do
	# 	if [[ "$exonerate_novel_mature_success" == true ]]; then
	# 		if grep -w -m 1 -q "$i" $outdir/novel.amps.exonerate.mature.nr.faa; then
	# 			# 				echo "Mature: $i"
	# 			sed -i "s/$i/$i-novel_mature/" $outdir/novel.amps.exonerate.nr.faa
	# 		else
	# 			#			echo "Precursor: $i"
	# 			sed -i "s/$i/$i-novel/" $outdir/novel.amps.exonerate.nr.faa
	# 		fi
	# 	else
	# 		#		echo "No mature outfile"
	# 		sed -i "s/$i/$i-novel/" $outdir/novel.amps.exonerate.nr.faa
	# 	fi
	# 	# echo -e "COMMAND: sed -i '/^>/ s/ length=/-novel&/' $outdir/novel.amps.exonerate.nr.faa\n" 1>&2
	# 	# sed -i '/^>/ s/ length=/-novel&/' $outdir/novel.amps.exonerate.nr.faa
	# done <$novel_amps_list

	# if [[ "$exonerate_novel_mature_success" == true ]]; then
	# 	sed -i '/^>/ s/ length=/-novel_mature&/' $outdir/novel.amps.exonerate.mature.nr.faa
	# else
	# 	touch $outdir/novel.amps.exonerate.mature.nr.faa
	# fi

	# echo "Combining the two files..." 1>&2
	# echo -e "COMMAND: cat $outdir/known.amps.exonerate.nr.faa $outdir/novel.amps.exonerate.nr.faa >$outdir/labelled.amps.exonerate.nr.faa\n" 1>&2
	# cat $outdir/known.amps.exonerate.nr.faa $outdir/novel.amps.exonerate.nr.faa >$outdir/labelled.amps.exonerate.nr.faa

	# #	if [[ "$exonerate_mature_success" == true ]]; then
	# echo -e "COMMAND: cat $outdir/known.amps.exonerate.mature.nr.faa $outdir/novel.amps.exonerate.mature.nr.faa >$outdir/labelled.amps.exonerate.mature.nr.faa\n" 1>&2
	# cat $outdir/known.amps.exonerate.mature.nr.faa $outdir/novel.amps.exonerate.mature.nr.faa >$outdir/labelled.amps.exonerate.mature.nr.faa
	# #	else
#	touch $outdir/labelled.amps.exonerate.mature.nr.faa
#	fi

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

	# echo "Labelling novel AMPs..." 1>&2
	# sed -i '/^>/ s/ length=/-novel&/' $outdir/novel.amps.exonerate.nr.faa
	# cat $outdir/known.amps.exonerate.nr.faa $outdir/novel.amps.exonerate.nr.faa >$outdir/labelled.amps.exonerate.nr.faa

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
		# sed -i "/$query-/ s/$/ precursor_hits=$exonerate_results/" $outdir/labelled.amps.exonerate.nr.faa
		# sed -i "/$query-/ s/$/ precursor_hits=$exonerate_results/" $outdir/known.amps.exonerate.nr.faa
		# sed -i "/$query-/ s/$/ precursor_hits=$exonerate_results/" $outdir/novel.amps.exonerate.nr.faa

		# sed -i "/$query-/ s/$/ top_precursor=$exonerate_precursor_top/" $outdir/labelled.amps.exonerate.nr.faa
		# sed -i "/$query-/ s/$/ top_precursor=$exonerate_precursor_top/" $outdir/known.amps.exonerate.nr.faa
		# sed -i "/$query-/ s/$/ precursor_hits=$exonerate_results/" $outdir/novel.amps.exonerate.nr.faa
		# sed -i "/$query-/ s@\$@ top_precursor=$exonerate_precursor_top@" $outdir/labelled.amps.exonerate.nr.faa
		# sed -i "/$query-/ s@\$@ top_precursor=$exonerate_precursor_top@" $outdir/known.amps.exonerate.nr.faa
		# sed -i "/$query-/ s@\$@ top_precursor=$exonerate_precursor_top@" $outdir/novel.amps.exonerate.nr.faa
		if [[ -z "$exonerate_precursor_top" ]]; then
			exonerate_precursor_top=" "
		fi
		# parse through the annotation file and add the tsv file
		echo -e "$seq\t$exonerate_precursor_top\t$exonerate_results" >>$outdir/annotation.precursor.tsv
		if [[ "$exonerate_mature_success" == true ]]; then
			# sed -i "/$query-/ s/$/ mature_hits=$exonerate_results/" $outdir/labelled.amps.exonerate.mature.nr.faa
			# sed -i "/$query-/ s/$/ mature_hits=$exonerate_results/" $outdir/known.amps.exonerate.mature.nr.faa
			# sed -i "/$query-/ s/$/ mature_hits=$exonerate_results/" $outdir/novel.amps.exonerate.mature.nr.faa
			exonerate_mature_top=$(sort -k4,4gr -t $'\t' $outdir/amps.exonerate.mature.summary.out | grep -w "$seq" | head -n1 | awk -F "\t" '{print $2 ": " $3}' || true)
			if [[ -n "$exonerate_mature_top" ]]; then
				sed -i "/$seq / s@\$@ top_mature=$exonerate_mature_top@" $amps_mature_100_fasta $amps_mature_some_fasta $amps_mature_some_none_fasta $amps_mature_none_fasta
				# sed -i "/$query-/ s/$/ top_mature=$exonerate_mature_top/" $outdir/labelled.amps.exonerate.mature.nr.faa
				# sed -i "/$query-/ s/$/ top_mature=$exonerate_mature_top/" $outdir/known.amps.exonerate.mature.nr.faa
				# sed -i "/$query-/ s/$/ top_mature=$exonerate_mature_top/" $outdir/novel.amps.exonerate.mature.nr.faa
				# sed -i "/$query-/ s@\$@ top_mature=$exonerate_mature_top@" $outdir/labelled.amps.exonerate.mature.nr.faa
				# sed -i "/$query-/ s@\$@ top_mature=$exonerate_mature_top@" $outdir/known.amps.exonerate.mature.nr.faa
				# sed -i "/$query-/ s@\$@ top_mature=$exonerate_mature_top@" $outdir/novel.amps.exonerate.mature.nr.faa
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
	done < <(cat $amps_100_list $amps_some_list | sort -u) # <(tail -n +2 $outdir/amps.exonerate.summary.out | awk '{print $1}' | sort -u)

	while read seq; do
		echo -e "$seq\t \t " >>$outdir/annotation.precursor.tsv
		echo -e "$seq\t \t " >>$outdir/annotation.mature.tsv
	done <$amps_none_list
	# add the label to the annotation TSV as well
	# 	for seq in $(awk '/-novel / {print $1}' $outdir/labelled.amps.exonerate.nr.faa | tr -d '>' | sed 's/-novel//'); do
	# 		sed -i "s/${seq}\t/${seq}-novel\t/" $file
	# 		sed -i "s/${seq}\t/${seq}-novel\t/" $outdir/annotation.mature.tsv
	# 		sed -i "s/${seq}\t/${seq}-novel\t/" $outdir/annotation.precursor.tsv
	# 	done

	# for seq in $(awk '/-known / {print $1}' $outdir/labelled.amps.exonerate.nr.faa | tr -d '>' | sed 's/-known//'); do
	# 	sed -i "s/${seq}\t/${seq}-known\t/" $file
	# 	sed -i "s/${seq}\t/${seq}-known\t/" $outdir/annotation.mature.tsv
	# 	sed -i "s/${seq}\t/${seq}-known\t/" $outdir/annotation.precursor.tsv
	# done

	# 	for seq in $(grep '\-novel_mature' $outdir/labelled.amps.exonerate.mature.nr.faa | tr -d '>' | sed 's/-novel_mature//'); do
	# 		sed -i "s/${seq}\t/${seq}-novel_mature\t/" $file
	# 		sed -i "s/${seq}\t/${seq}-novel_mature\t/" $outdir/annotation.mature.tsv
	# 		sed -i "s/${seq}\t/${seq}-novel_mature\t/" $outdir/annotation.precursor.tsv
	# 	done
	#
	# 	for seq in $(grep '\-known_mature' $outdir/labelled.amps.exonerate.mature.nr.faa | tr -d '>' | sed 's/-known_mature//'); do
	# 		sed -i "s/${seq}\t/${seq}-known_mature\t/" $file
	# 		sed -i "s/${seq}\t/${seq}-known_mature\t/" $outdir/annotation.mature.tsv
	# 		sed -i "s/${seq}\t/${seq}-known_mature\t/" $outdir/annotation.precursor.tsv
	# 	done
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
# num_novel=$(grep -c '\-novel' $outdir/labelled.amps.exonerate.nr.faa || true)
# num_novel_precursor=$(grep -c '\-novel ' $outdir/labelled.amps.exonerate.nr.faa || true)
# num_novel_mature=$(grep -c '\-novel_mature' $outdir/labelled.amps.exonerate.nr.faa || true)

# FIX THIS PART-- no 'labelled amp file anymore'

echo -e "RESULTS\n$(printf '%.0s-' $(seq 1 63))\n" 1>&2

num_total=$(grep -c '^>' $query || true)
if [[ "$exonerate_success" = true ]]; then
	# num_novel=$(wc -l $novel_amps_list | awk '{print $1}')
	# if [[ "$exonerate_novel_mature_success" = true ]]; then
	# 		num_novel_mature=$(wc -l $novel_amps_mature_list | awk '{print $1}')
	# 		num_novel_all=$(cat $novel_amps_list $novel_amps_mature_list | sort -u | wc -l)

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
	# 	echo "Number of novel AMPs (<100% alignment to precursor AMPs): $(printf "%'d" $num_novel)/$(printf "%'d" $num_total)" 1>&2
	# 	echo "Number of novel mature AMPs (<100% alignment to mature AMPs): $(printf "%'d" $num_novel_mature)/$(printf "%'d" $num_novel)" 1>&2
	# 	echo -e "Number of Novel AMPs: $(printf "%'d" $num_novel_all)/$(printf "%'d" $num_total)\n" 1>&2
	# else
	# 	# num_novel_mature=$(wc -l $novel_amps_mature_list | awk '{print $1}')
	# 	num_novel_all=$num_novel
	# 	echo "Number of novel AMPs (<100% alignment to precursor AMPs): $(printf "%'d" $num_novel)/$(printf "%'d" $num_total)" 1>&2
	# 	echo -e "Number of Novel AMPs: $(printf "%'d" $num_novel_all)/$(printf "%'d" $num_total)\n" 1>&2
	# fi
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

# default_name="$(realpath -s $(dirname $outdir)/exonerate)"
# if [[ "$default_name" != "$outdir" ]]; then
# 	if [[ -d "$default_name" ]]; then
# 		count=1
# 		if [[ ! -L "$default_name" ]]; then
# 			temp="${default_name}-${count}"
# 			while [[ -d "$temp" ]]; do
# 				count=$((count + 1))
# 				temp="${default_name}-${count}"
# 			done
# 			echo -e "Since $default_name already exists, $default_name is renamed to $temp as to not overwrite old trimmed reads.\n" 1>&2
# 			mv $default_name $temp
# 		else
# 			unlink $default_name
# 		fi
# 	fi
# 	if [[ "$default_name" != "$outdir" ]]; then
# 		echo -e "\n$outdir softlinked to $default_name\n" 1>&2
# 		(cd $(dirname $outdir) && ln -fs $(basename $outdir) $(basename $default_name))
# 	fi
# fi
echo -e "\nEND: $(date)\n" 1>&2
# echo 1>&2

echo -e "STATUS: DONE.\n" 1>&2
touch $outdir/EXONERATE.DONE

if [[ "$email" = true ]]; then
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	species=$(echo "$species" | sed 's/^./\u&. /')
	echo "$outdir" | mail -s "${species}: STAGE 12: EXONERATE: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
