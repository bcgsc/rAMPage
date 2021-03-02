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
		echo -e "\
	\tUses Exonerate to remove known AMP sequences.\n \
	" | table

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

if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) is empty."
fi

if [[ ! -f $(realpath $2) ]]; then
	print_error "Input file $(realpath $2) does not exist."
elif [[ ! -s $(realpath $2) ]]; then
	print_error "Input file $(realpath $2) is empty."
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

# 8 - print env details
{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo -e "CALL: $args (wd: $(pwd))\n"
} 1>&2

query=$(realpath $1)
file=$(realpath $2)
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
echo -e "COMMAND: $RUN_EXONERATE --query $query --target $target1 --querytype protein --targettype protein --ryo \"Summary: %qi %ti %pi\\\n\" --showvulgar false >$outdir/amps.exonerate.out\n" 1>&2
$RUN_EXONERATE --query $query --target $target1 --querytype protein --targettype protein --ryo "Summary: %qi %ti %pi\n" --showvulgar false >$outdir/amps.exonerate.out

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
	echo "query target pid" >$outdir/amps.exonerate.summary.out
	grep '^Summary:' $outdir/amps.exonerate.out | cut -d' ' -f2- | sort -k3,3gr >>$outdir/amps.exonerate.summary.out

	# if [[ "$(wc -l $outdir/amps.exonerate.mature.out | awk '{print $1}')" -gt 3 ]]; then
	# 	echo -e "COMMAND: grep '^Summary:' $outdir/amps.exonerate.mature.out | cut -d' ' -f2- >$outdir/amps.exonerate.summary.mature.out\n" 1>&2
	# 	grep '^Summary:' $outdir/amps.exonerate.mature.out | cut -d' ' -f2- >$outdir/amps.exonerate.summary.mature.out
	# else
	# 	touch $outdir/amps.exonerate.summary.mature.out
	# fi

	# known AMPs will be defined as those that have exonerate pid of 100
	known_amps_list=$outdir/amps.exonerate.known.txt
	awk '{if($3==100) print $1}' $outdir/amps.exonerate.summary.out | sort -u >$known_amps_list

	# novel AMPs will be defined as those that have exonerate pid of <100 or no alignment at all, hence take from $query
	# take known list and do an inverse grep
	novel_amps_list=$outdir/amps.exonerate.novel.txt
	grep -Fvxf $known_amps_list <(awk '/^>/ {print $1}' $query | tr -d '>' | sort -u) >$novel_amps_list

	echo "Filtering for known AMPs..." 1>&2
	echo -e "COMMAND: $RUN_SEQTK subseq $query $known_amps_list >$outdir/known.amps.exonerate.nr.faa\n" 1>&2
	$RUN_SEQTK subseq $query $known_amps_list >$outdir/known.amps.exonerate.nr.faa

	echo "Running Exonerate..." 1>&2
	{
		echo "Query: $outdir/known.amps.exonerate.nr.faa"
		echo "Target: $target2"
		echo
	} 1>&2

	echo -e "COMMAND: $RUN_EXONERATE --query $outdir/known.amps.exonerate.nr.faa --target $target2 --querytype protein --targettype protein --ryo \"Summary: %qi %ti %pi\\\n\" --showvulgar false >$outdir/amps.exonerate.mature.out\n" 1>&2
	$RUN_EXONERATE --query $outdir/known.amps.exonerate.nr.faa --target $target2 --querytype protein --targettype protein --ryo "Summary: %qi %ti %pi\n" --showvulgar false >$outdir/amps.exonerate.mature.out

	exonerate_mature_success=false
	if [[ "$(wc -l $outdir/amps.exonerate.mature.out | awk '{print $1}')" -gt 3 ]]; then
		exonerate_mature_success=true
		echo "Extracting summary..." 1>&2
		echo -e "COMMAND: grep '^Summary:' $outdir/amps.exonerate.mature.out | cut -d' ' -f2- >>$outdir/amps.exonerate.mature.summary.out\n" 1>&2
		echo "query target pid" >$outdir/amps.exonerate.mature.summary.out
		grep '^Summary:' $outdir/amps.exonerate.mature.out | cut -d' ' -f2- | sort -k3,3gr >>$outdir/amps.exonerate.mature.summary.out

		# known mature AMPs will be those with a score of 100 in the mature db too
		# obtain this by using known_amps_list as pattern
		known_amps_mature_list=$outdir/amps.exonerate.known.mature.txt
		awk '{if($3==100) print $1}' $outdir/amps.exonerate.mature.summary.out | sort -u >$known_amps_mature_list

		echo -e "COMMAND: $RUN_SEQTK subseq $query $known_amps_mature_list >$outdir/known.amps.exonerate.mature.nr.faa\n" 1>&2
		$RUN_SEQTK subseq $query $known_amps_mature_list >$outdir/known.amps.exonerate.mature.nr.faa
	else
		touch $outdir/known.amps.exonerate.mature.nr.faa
	fi

	echo -e "Labelling known AMPs...\n" 1>&2
	# echo -e "COMMAND: sed -i '/^>/ s/ length=/_known&/' $outdir/known.amps.exonerate.nr.faa" 1>&2
	while read i; do
		if [[ "$exonerate_mature_success" == true ]]; then
			if grep -F -x -m 1 -q "$i" $known_amps_mature_list; then
				sed -i "s/$i/$i-known_mature/" $outdir/known.amps.exonerate.nr.faa
			else
				sed -i "s/$i/$i-known/" $outdir/known.amps.exonerate.nr.faa
			fi
		else
			sed -i "s/$i/$i-known/" $outdir/known.amps.exonerate.nr.faa
		fi
	done <$known_amps_list

	if [[ "$exonerate_mature_success" == true ]]; then
		sed -i '/^>/ s/ length=/-known_mature&/' $outdir/known.amps.exonerate.mature.nr.faa
	else
		touch $outdir/known.amps.exonerate.mature.nr.faa
	fi

	# label with known AMP accession
	while IFS=' ' read novel known; do
		sed -i "/${novel}-known/ s/$/ exonerate=$known/" $outdir/known.amps.exonerate.nr.faa
	done < <(awk '{if($3==100) print $1, $2}' $outdir/amps.exonerate.summary.out | sort -u)

	# label with known AMP accession

	if [[ "$exonerate_mature_success" == true ]]; then
		while IFS=' ' read novel known; do
			sed -i "/${novel}-known_mature/ s/$/ exonerate=$known/" $outdir/known.amps.exonerate.mature.nr.faa
		done < <(awk '{if($3==100) print $1, $2}' $outdir/amps.exonerate.summary.mature.out | sort -u)
	else
		touch $outdir/known.amps.exonerate.mature.nr.faa
	fi

	echo "Filtering for novel AMPs..." 1>&2
	echo -e "COMMAND: $RUN_SEQTK subseq $query $novel_amps_list >$outdir/novel.amps.exonerate.nr.faa\n" 1>&2
	$RUN_SEQTK subseq $query $novel_amps_list >$outdir/novel.amps.exonerate.nr.faa

	echo "Running Exonerate..." 1>&2
	{
		echo "Query: $outdir/novel.amps.exonerate.nr.faa"
		echo "Target: $target2"
		echo
	} 1>&2

	echo -e "COMMAND: $RUN_EXONERATE --query $outdir/novel.amps.exonerate.nr.faa --target $target2 --querytype protein --targettype protein --ryo \"Summary: %qi %ti %pi\\\n\" --showvulgar false >$outdir/amps.exonerate.mature.out\n" 1>&2
	$RUN_EXONERATE --query $outdir/novel.amps.exonerate.nr.faa --target $target2 --querytype protein --targettype protein --ryo "Summary: %qi %ti %pi\n" --showvulgar false >$outdir/amps.exonerate.novel.mature.out

	exonerate_novel_mature_success=false
	if [[ "$(wc -l $outdir/amps.exonerate.novel.mature.out | awk '{print $1}')" -gt 3 ]]; then
		exonerate_novel_mature_success=true
		echo "Extracting summary..." 1>&2
		echo -e "COMMAND: grep '^Summary:' $outdir/amps.exonerate.novel.mature.out | cut -d' ' -f2- >$outdir/amps.exonerate.novel.mature.summary.out\n" 1>&2
		echo "query target pid" >$outdir/amps.exonerate.novel.mature.summary.out
		grep '^Summary:' $outdir/amps.exonerate.novel.mature.out | cut -d' ' -f2- | sort -k3,3gr >>$outdir/amps.exonerate.novel.mature.summary.out

		novel_amps_mature_list=$outdir/amps.exonerate.novel.mature.txt
		# get unaligned AMPs from this exonerate run
		grep -Fxvf <(awk '{if($3==100) print $1}' $outdir/amps.exonerate.novel.mature.summary.out | sort -u) $novel_amps_list >$novel_amps_mature_list

		echo -e "COMMAND: $RUN_SEQTK subseq $outdir/novel.amps.exonerate.nr.faa $novel_amps_mature_list >$outdir/novel.amps.exonerate.mature.nr.faa\n" 1>&2
		$RUN_SEQTK subseq $query $novel_amps_mature_list >$outdir/novel.amps.exonerate.mature.nr.faa
	else
		touch $outdir/novel.amps.exonerate.mature.nr.faa
	fi

	# echo -e "COMMAND: $RUN_SEQTK subseq $query <(grep -vFf <(awk '{print \$1}' $outdir/amps.exonerate.summary.out | sort -u) <(grep '^>' $query | tr -d '>' | sort -u)) >$outdir/novel.amps.exonerate.nr.faa\n" 1>&2
	# $RUN_SEQTK subseq $query <(grep -vFf <(awk '{print $1}' $outdir/amps.exonerate.summary.out | sort -u) <(grep '^>' $query | tr -d '>')) >$outdir/novel.amps.exonerate.nr.faa

	echo -e "Labelling novel AMPs...\n" 1>&2

	while read i; do
		if [[ "$exonerate_novel_mature_success" == true ]]; then
			if grep -w -m 1 -q "$i" $outdir/novel.amps.exonerate.mature.nr.faa; then
				# 				echo "Mature: $i"
				sed -i "s/$i/$i-novel_mature/" $outdir/novel.amps.exonerate.nr.faa
			else
				#			echo "Precursor: $i"
				sed -i "s/$i/$i-novel/" $outdir/novel.amps.exonerate.nr.faa
			fi
		else
			#		echo "No mature outfile"
			sed -i "s/$i/$i-novel/" $outdir/novel.amps.exonerate.nr.faa
		fi
		# echo -e "COMMAND: sed -i '/^>/ s/ length=/-novel&/' $outdir/novel.amps.exonerate.nr.faa\n" 1>&2
		# sed -i '/^>/ s/ length=/-novel&/' $outdir/novel.amps.exonerate.nr.faa
	done <$novel_amps_list

	if [[ "$exonerate_novel_mature_success" == true ]]; then
		sed -i '/^>/ s/ length=/-novel_mature&/' $outdir/novel.amps.exonerate.mature.nr.faa
	else
		touch $outdir/novel.amps.exonerate.mature.nr.faa
	fi

	echo "Combining the two files..." 1>&2
	echo -e "COMMAND: cat $outdir/known.amps.exonerate.nr.faa $outdir/novel.amps.exonerate.nr.faa >$outdir/labelled.amps.exonerate.nr.faa\n" 1>&2
	cat $outdir/known.amps.exonerate.nr.faa $outdir/novel.amps.exonerate.nr.faa >$outdir/labelled.amps.exonerate.nr.faa

	if [[ "$exonerate_mature_success" == true ]]; then
		echo -e "COMMAND: cat $outdir/known.amps.exonerate.mature.nr.faa $outdir/novel.amps.exonerate.mature.nr.faa >$outdir/labelled.amps.exonerate.mature.nr.faa\n" 1>&2
		cat $outdir/known.amps.exonerate.mature.nr.faa $outdir/novel.amps.exonerate.mature.nr.faa >$outdir/labelled.amps.exonerate.mature.nr.faa
	else
		touch $outdir/labelled.amps.exonerate.mature.nr.faa
	fi

	# add the label to the annotation TSV as well
	for seq in $(awk '/-novel/ {print $1}' $outdir/labelled.amps.exonerate.nr.faa | tr -d '>' | sed 's/-novel_\?[A-z]*//'); do
		sed -i "s/${seq}\t/${seq}-novel\t/" $file
	done

	# 	for seq in $(grep '\-novel_mature' $outdir/labelled.amps.exonerate.mature.nr.faa | tr -d '>' | sed 's/-novel_mature//'); do
	# 		sed -i "s/${seq}\t/${seq}-novel_mature\t/" $file
	# 	done

	for seq in $(awk '/-known/ {print $1}' $outdir/labelled.amps.exonerate.nr.faa | tr -d '>' | sed 's/-known_\?[A-z]*//'); do
		sed -i "s/${seq}\t/${seq}-known\t/" $file
	done

	# for seq in $(grep '\-known_mature' $outdir/labelled.amps.exonerate.mature.nr.faa | tr -d '>' | sed 's/-known_mature//'); do
	# 	sed -i "s/${seq}\t/${seq}-known_mature\t/" $file
	# done
else
	# no known AMPs
	echo -e "No alignments detected-- there are no known AMPs. All AMPs are novel!\n" 1>&2

	cp $query $outdir/novel.amps.exonerate.nr.faa
	touch $outdir/known.amps.exonerate.nr.faa

	echo "Labelling novel AMPs..." 1>&2
	sed -i '/^>/ s/ length=/-novel&/' $outdir/novel.amps.exonerate.nr.faa
	cat $outdir/known.amps.exonerate.nr.faa $outdir/novel.amps.exonerate.nr.faa >$outdir/labelled.amps.exonerate.nr.faa
fi

# num_novel=$(grep -c '\-novel' $outdir/labelled.amps.exonerate.nr.faa || true)
# num_novel_precursor=$(grep -c '\-novel ' $outdir/labelled.amps.exonerate.nr.faa || true)
# num_novel_mature=$(grep -c '\-novel_mature' $outdir/labelled.amps.exonerate.nr.faa || true)
num_total=$(grep -c '^>' $outdir/labelled.amps.exonerate.nr.faa || true)
if [[ "$exonerate_success" = true ]]; then
	num_novel=$(wc -l $novel_amps_list | awk '{print $1}')
	if [[ "$exonerate_mature_success" = true ]]; then
		num_novel_mature=$(wc -l $novel_amps_mature_list | awk '{print $1}')
		num_novel_all=$(cat $novel_amps_list $novel_amps_mature_list | sort -u | wc -l)
	else
		num_novel_mature=0
		num_novel_all=$num_novel
	fi
	echo "Number of Novel Precursor AMPs: $(printf "%'d" $num_novel)/$(printf "%'d" $num_total)" 1>&2
	echo "Number of Novel Mature AMPs: $(printf "%'d" $num_novel_mature)/$(printf "%'d" $num_total)" 1>&2
	echo -e "Number of Novel AMPs: $(printf "%'d" $num_novel_all)/$(printf "%'d" $num_total)\n" 1>&2
else
	num_novel=$(grep -c '^>' $query || true)
	echo "Number of Novel AMPs: $(printf "%'d" $num_novel)/$(printf "%'d" $num_total)" 1>&2
fi

if [[ -n $file ]]; then
	echo -e "Output(s): $outdir/labelled.amps.exonerate.nr.faa\n $file\n \
	" | column -s ' ' -t 1>&2
else
	echo -e "Output: $outdir/novel.amps.exonerate.nr.faa\n" 1>&2
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
