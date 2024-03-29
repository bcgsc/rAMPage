#!/usr/bin/env bash
set -euo pipefail
FULL_PROGRAM=$0
PROGRAM=$(basename $FULL_PROGRAM)

if [[ "$PROGRAM" == "slurm_script" ]]; then
	FULL_PROGRAM=$(scontrol show job $SLURM_JOBID | awk '/Command=/ {print $1}' | awk -F "=" '{print $2}')
	PROGRAM=$(basename ${FULL_PROGRAM})

fi
args="$FULL_PROGRAM $*"
# input: logfiles
# output: tsv

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
		# DESCRIPTION
		echo "DESCRIPTION:"
		echo -e "\
		\tSummarizes statistics from each step.\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-a <address>] [-h] <logs directory(s)>\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail address for alerts\n \
		\t-h\tshow help menu\n \
		" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com /path/to/logs/dir\n \
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

# 3 - no arguments
if [[ "$#" -eq 0 ]]; then
	get_help
fi

email=false
while getopts :ha: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	h) get_help ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

if [[ "$#" -eq 0 ]]; then
	print_error "Incorrect number of arguments."
fi

if [[ ! -d $(realpath $1) ]]; then

	if [[ ! -e $(realpath $1) ]]; then
		print_error "Input directory $(realpath $1) does not exist."
	else
		print_error "Given input directory is not a directory."
	fi
fi

{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo -e "CALL: $args (wd: $(pwd))\n"
} 1>&2

if [[ ! -v ROOT_DIR ]]; then
	print_error "ROOT_DIR is unbound. Please export ROOT_DIR=/rAMPage/GitHub/directory."
fi

for logdir in "$@"; do
	indir=$(realpath $logdir)
	if [[ ! -d $indir ]]; then
		continue
	fi
	outfile_long=$indir/00-stats.long.tsv
	outfile_wide=$indir/00-stats.wide.tsv
	# if workdir is unbound then
	if [[ ! -v WORKDIR ]]; then
		# get workdir from input
		workdir=$(dirname $indir)
	else
		workdir=$(realpath $WORKDIR)
	fi

	if [[ ! -v SPECIES ]]; then
		# get species from workdir
		species=$(echo "$workdir" | awk -F "/" '{print $(NF-1)}')
	else
		species=$SPECIES
	fi
	declare -A values
	# 	header=()
	#	values=()
	for i in $(printf '%02d\n' $(seq 1 $(ls $indir | tail -n1 | cut -f1 -d-))); do
		if [[ "$i" != "04" ]]; then
			file=$(find $indir -maxdepth 1 -name "$i-*" | head -n1)
			step=$(basename "$file" ".log" | cut -f2 -d-)
			# echo $file
			case $step in
			trimmed_reads)
				num=$(awk '/Reads passed filter:/ {print $NF}' $file)
				values["Number of Trimmed Reads"]=$num
				# header+=("Number of Trimmed Reads")
				# values+=($num)
				# echo "Trimmed Reads: $num"
				;;
			assembly)
				# header+=("Number of Assembled Transcripts")
				num=$(awk '/Total number of assembled non-redundant transcripts:/ {print $NF}' $file)
				values["Number of Assembled Transcripts"]=$num
				# echo "Assembly: $num"
				;;
			filtering)
				# header+=("Number of Filtered Transcripts")
				num=$(awk '/After   filtering:/ {print $NF}' $file)
				values["Number of Filtered Transcripts"]=$num
				# echo "Filtering: $num"
				;;
			translation)
				# header+=("Number of Filtered Transcripts with Valid ORFs")
				# num=$(awk '/Number of valid ORFs:/ {print $NF}' $file)
				num=$(awk '/Number of transcripts with valid ORFs:/ {print $NF}' $file)
				values["Number of Filtered Transcripts with Valid ORFs"]=$num
				# echo "Translation: $num"
				;;
			homology)
				# header+=("Number of Non-redundant AMP Precursors (HMMs)")
				num=$(awk '/Number of AMPs found \(non-redundant\):/ {print $NF}' $file)
				values["Number of Non-redundant AMP Precursors (HMMs)"]=$num
				# echo "Homology: $num"
				;;
			cleavage)
				# header+=("Number of Cleaved Precursors")
				num=$(awk '/Number of sequences remaining:/ {print $NF}' $file)
				values["Number of Cleaved Precursors"]=$num
				# echo "Cleavage: $num"
				;;
			amplify)
				# header+=("Number of Non-redundant AMPs (HMMs then AMPlify)")
				num=$(awk '/Number of Final AMPs:/ {print $NF}' $file)
				values["Number of Non-redundant AMPs (HMMs then AMPlify)"]=$num
				# echo "AMPlify: $num"
				;;
			annotation)
				# header+=("Number of Annotated AMPs")
				num=$(awk '/Number of annotated AMPs:/ {print $NF}' $file)
				# if [[ -z "$num" ]]; then
				# 	num="0"
				# fi
				values["Number of Annotated AMPs"]=$num
				# echo "Annotation: $num"
				;;
			exonerate)
				# header+=("Number of Novel AMPs")
				num=$(awk '/Number of Novel AMPs:/ {print $NF}' $file)
				# num=$(awk '/Number of high-confidence \(score >= [0-9]\.?[0-9]*\), short \(length <= [0-9]+\), and positive \(charge >= -?[0-9]+\) unique AMPs:/ {print $NF}' $file)
				# if [[ -z "$num" ]]; then
				# 	num="0/0"
				# fi
				values["Number of Novel AMPs"]=$num
				# echo "Novel: $num"
				;;
			sable) ;;
			esac
		fi
	done

	path=$(echo "$workdir" | sed "s|$ROOT_DIR/||")

	headers=("Number of Trimmed Reads" "Number of Assembled Transcripts" "Number of Filtered Transcripts" "Number of Filtered Transcripts with Valid ORFs" "Number of Non-redundant AMP Precursors (HMMs)" "Number of Cleaved Precursors" "Number of Non-redundant AMPs (HMMs then AMPlify)" "Number of Annotated AMPs" "Number of Novel AMPs")

	# echo "${headers[*]}"

	echo -ne "Path\t" >$outfile_wide

	for i in "${headers[@]}"; do
		echo -ne "$i\t" >>$outfile_wide
	done
	sed -i 's/\t$//' $outfile_wide
	echo -ne "\n$path\t" >>$outfile_wide

	for i in "${headers[@]}"; do
		echo -ne "${values[$i]}\t" >>$outfile_wide
	done
	sed -i 's/\t$//' $outfile_wide
	echo >>$outfile_wide
	# echo "Path ${!values[*]}" | sed 's/ //g' | tr ' ' '\t' | tr '_' ' ' >$outfile_wide
	# echo "$path ${values[*]}" | tr ' ' '\t' >>$outfile_wide

	headers=("Number of Trimmed Reads" "Number of Assembled Transcripts" "Number of Filtered Transcripts" "Number of Filtered Transcripts with Valid ORFs" "Number of Non-redundant AMP Precursors (HMMs)" "Number of Cleaved Precursors" "Number of Non-redundant AMPs (HMMs then AMPlify)" "Number of Annotated AMPs" "Number of Novel AMPs")

	echo -e "Path\t$path" >$outfile_long
	for i in "${headers[@]}"; do
		echo -e "${i}\t${values[$i]}" >>$outfile_long
	done

	if [[ "$#" -eq 1 ]]; then
		column -s $'\t' -t $outfile_long 1>&2
		echo 1>&2
	fi
	echo -e "Output:\t$outfile_long\n \t$outfile_wide\n" | column -s $'\t' -t 1>&2

	if [[ -s $indir/10-amplify.log ]]; then
		echo 1>&2
		amp_outfile_long=$indir/00-amps.long.tsv
		amp_outfile_wide=$indir/00-amps.wide.tsv
		amp_outfile_wide_ordered=$indir/00-amps.wide.ordered.tsv

		echo -e "Path\t$path" >$amp_outfile_long
		awk 'BEGIN{OFS="\t"} /\samps.*\.nr\.faa\s+[0-9]+/ {print $1, $2}' $indir/10-amplify.log >>$amp_outfile_long
		#		grep '\samps\..\+\.nr\.faa\s\+[0-9]\+' $indir/10-amplify.log | awk 'BEGIN{OFS="\t"}{print $1, $2}' >>$amp_outfile_long
		echo -e "Path\t$(grep '\samps.*\.nr\.faa\s\+[0-9]\+' $indir/10-amplify.log | awk 'BEGIN{OFS="\t"}{print $1}' | tr '\n' '\t' | sed 's/\t$//')" >$amp_outfile_wide
		echo -e "$path\t$(grep '\samps.*\.nr\.faa\s\+[0-9]\+' $indir/10-amplify.log | awk 'BEGIN{OFS="\t"}{print $2}' | tr '\n' '\t' | sed 's/\t$//')" >>$amp_outfile_wide

		# key_order=("amps.nr.faa" "amps.conf.nr.faa" "amps.charge.nr.faa" "amps.short.nr.faa" "amps.conf.charge.nr.faa" "amps.conf.short.nr.faa" "amps.short.charge.nr.faa" "amps.conf.short.charge.nr.faa")

		declare -A dict
		while read file num; do
			dict[$file]=$num
		done < <(grep '\samps.*\.nr\.faa\s\+[0-9]\+' $indir/10-amplify.log)

		echo -ne "Path\t" >$amp_outfile_wide_ordered
		#		for i in "${key_order[@]}"; do
		for i in "${!dict[@]}"; do
			echo -ne "$i\t" >>$amp_outfile_wide_ordered
		done
		sed -i 's/\t$/\n/' $amp_outfile_wide_ordered
		echo -ne "$path\t" >>$amp_outfile_wide_ordered
		#		for i in "${key_order[@]}"; do
		for i in "${!dict[@]}"; do
			if [[ -e $(dirname $indir)/amplify/$i ]]; then
				echo -ne "${dict[$i]}\t" >>$amp_outfile_wide_ordered
			else
				echo -ne"NA\t" >>$amp_outfile_wide_ordered
			fi
		done
		sed -i 's/\t$/\n/' $amp_outfile_wide_ordered

		if [[ "$#" -eq 1 ]]; then
			column -s $'\t' -t $amp_outfile_long 1>&2
			echo 1>&2
		fi
		echo -e "Output:\t$amp_outfile_long\n \t$amp_outfile_wide\n \t$amp_outfile_wide_ordered" | column -s $'\t' -t 1>&2
		echo 1>&2
	fi
done

echo -e "\nEND: $(date)" 1>&2
echo -e "\nSTATUS: DONE.\n" 1>&2

if [[ "$email" = true ]]; then
	species=$(echo "$species" | sed 's/^./\u&. /')
	echo "$indir" | mail -s "${species}: SUMMARY" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
