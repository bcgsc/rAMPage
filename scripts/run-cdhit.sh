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

# 1 - get_help function
function get_help() {
	{
		echo "DESCRIPTION:"
		echo -e "\
		\tRuns CD-HIT to reduce redundancy between protein sequences.\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-d] [-h] [-l] [-o <output FASTA file>] [-s <0 to 1>] [-t <int>] [-v] <input protein FASTA file>\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-d\tremove exact duplicates (same as -s 1.0 -l; overrides -s)\n \
		\t-f\tformat clusters as a TSV file\n \
		\t-h\tshow help menu\n \
		\t-l\tcluster sequences only of the same length\n \
		\t-o <FILE>\toutput FASTA file\t(default = *.nr.faa)\n \
		\t-s <0 to 1>\tCD-HIT global sequence similarity cut-off\t(default = 0.90)\n\
		\t-t <INT>\tnumber of threads\t(default = 2)\n\
		\t-v\tverbose logging\t(i.e. print PATH, HOSTNAME, etc.)\n \
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

# 3 - no args given
if [[ "$#" -eq 0 ]]; then
	get_help
fi

# default options
threads=2
similarity=0.90
output=""
verbose=false
remove_duplicates=false
format=false
length=false
# 4 - getopts
while getopts :dfhlo:s:t:v opt; do
	case $opt in
	d) remove_duplicates=true ;;
	f) format=true ;;
	h) get_help ;;
	l) length=true ;;
	o) output="$(realpath $OPTARG)" ;;
	s) similarity="$OPTARG" ;;
	t) threads="$OPTARG" ;;
	v) verbose=true ;;
	\?)
		print_error "Invalid option: -$OPTARG"
		;;
	esac
done

shift $((OPTIND - 1))

if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

input=$(realpath $1)

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

# if [[ ! -v WORKDIR ]]; then
# 	workdir=$(dirname $outdir)
# else
# 	workdir=$(realpath $WORKDIR)
# fi

# if [[ ! -v SPECIES ]]; then
# 	# get species from workdir
# 	species=$(echo "$workdir" | awk -F "/" '{print $(NF-1)}' | sed 's/^./&./')
# else
# 	species=$SPECIES
# fi

if [[ "$verbose" = true ]]; then
	{
		echo "HOSTNAME: $(hostname)"
		echo -e "START: $(date)\n"

		echo -e "PATH=$PATH\n"

		echo "CALL: $args (wd: $(pwd))"
		echo -e "THREADS: $threads\n"
	} 1>&2
fi

if [[ "$remove_duplicates" == true ]]; then
	similarity=1.0
	length_cutoffs="-S 0 -s 1"
else
	if [[ "$length" = true ]]; then
		length_cutoffs="-S 0 -s 1"
	else
		length_cutoffs=""
	fi
fi

if (($(echo "$similarity < 0" | bc -l) || $(echo "$similarity > 1" | bc -l))); then
	print_error "Sequence similarity cut-off must be between 0 and 1."
fi

# not always want the same length for 100% similarity
# if (($(echo "$similarity == 1" | bc -l))); then
# if [[ "$similarity" == "1.0" || "$similarity" == "1" ]]; then
# 	remove_duplicates=true
# 	length_cutoffs="-S 0 -s 1"
# fi

if [[ ! -v RUN_CDHIT ]]; then
	if command -v cd-hit &>/dev/null; then
		RUN_CDHIT=$(command -v cd-hit)
	else
		print_error "RUN_CDHIT is unbound and no 'cd-hit' found in PATH. Please export RUN_CDHIT=/path/to/cd-hit/executable."
	fi
elif ! command -v $RUN_CDHIT &>/dev/null; then
	print_error "Unable to execute $RUN_CDHIT."
fi

echo "PROGRAM: $(command -v $RUN_CDHIT)" 1>&2
cdhit_version=$({ $RUN_CDHIT -h 2>&1 | head -n1 | awk -F "version " '{print $2}' | tr -d '='; } || true)
echo -e "VERSION: $cdhit_version\n" 1>&2

if (($(echo "$similarity >= 0.7" | bc -l) && $(echo "$similarity <= 1.0" | bc -l))); then
	wordsize=5
elif (($(echo "$similarity >= 0.6" | bc -l))); then
	wordsize=4
elif (($(echo "$similarity >= 0.5" | bc -l))); then
	wordsize=3
else
	wordsize=2
fi

if [[ -z "$output" ]]; then
	if [[ "$remove_duplicates" = true ]]; then
		# output=${input/.faa/.rmdup.nr.faa}
		# output=${input/.faa/.nr.faa}
		output=$(echo "$input" | sed 's/\.faa\?/.nr&/' | sed 's/\(\.nr\)\+\(\.faa\?\)/.rmdup.nr\2/')
	else
		percent=$(echo "$similarity * 100" | bc | sed 's/\.00//')
		# output=${input/.faa/.nr.faa}
		output=$(echo "$input" | sed 's/\.faa\?/.nr&/' | sed "s/\(\.nr\)\+\(\.faa\?\)/.${percent}.nr\2/")
	fi
fi

if [[ "$input" == "$output" ]]; then
	echo "BUG: Input filename is the same as output filename."
	exit 1
fi

if [[ ! -s "$input" ]]; then
	print_error "Input file $input is empty!"
fi

outdir=$(dirname $output)
log=$outdir/cdhit.log
if [[ "$remove_duplicates" = true ]]; then
	echo "Conducting exact duplicate removal..." 1>&2
elif [[ "$length" = true ]]; then
	echo "Conducting redundancy removal of same length sequences at $(echo "$similarity * 100" | bc)% global sequence similarity with word size $wordsize..." 1>&2
else
	echo "Conducting redundancy removal at $(echo "$similarity * 100" | bc)% global sequence similarity with word size $wordsize..." 1>&2
fi

echo -e "COMMAND: $RUN_CDHIT -d 0 -l 4 -i $input -o $output -c $similarity -n $wordsize -T $threads -M 0 $length_cutoffs &>> $log\n" 1>&2
$RUN_CDHIT -d 0 -l 4 -i $input -o $output -c $similarity -n $wordsize -T $threads -M 0 $length_cutoffs &>>$log

unique_ids=$(grep '^>' $input | sort -u | wc -l || true)
total_ids=$(grep -c '^>' $input || true)

not_unique=false
if [[ "$unique_ids" -lt "$total_ids" ]]; then
	not_unique=true
	{
		echo "NOTE: There are duplicate sequence IDs in your input file."
		echo "Number of unique sequence IDs: $(printf "%'d" $unique_ids)/$(printf "%'d" $total_ids)"
		dup_seq_ids=$(grep '^>' $input | tr -d '>' | sort | uniq -c | awk '{if($1>1) print}' | sort -k1,1gr || true)
		num_dup_seq_ids=$(echo "$dup_seq_ids" | wc -l)
		echo -e "\nDuplicate sequence IDs:\n$dup_seq_ids\n" 1>&2
	} 1>&2
fi
rm -f ${output}.processed.clstr
if [[ "$format" = true ]]; then
	echo -e "Converting cluster file to TSV format...\n" 1>&2
	echo -e "Cluster\tLength\tSequence Similarity\tSequence ID" >${output}.clstr.tsv
	if [[ "$not_unique" = true ]]; then
		echo -e "Cluster\tLength\tSequence Similarity\tSequence ID" >${output}.processed.clstr.tsv
	fi
	while read line; do
		if [[ "$line" =~ ^\> ]]; then
			if [[ "$not_unique" = true ]]; then
				echo "$line" >>${output}.processed.clstr
			fi
			cluster=$(echo "$line" | sed 's/>Cluster //')
		elif [[ "$line" =~ ^[0-9] ]]; then
			seq_id=$(echo "$line" | awk '{print $3}' | sed 's/\.\.\.//' | tr -d '>')
			len=$(echo "$line" | awk '{print $2}' | sed 's/aa,//')
			sim=$(echo "$line" | awk '{print $5}' | sed 's/%//')
			if [[ -z "$sim" ]]; then
				sim="rep"
			fi
			if [[ "$not_unique" = true ]]; then
				if ! grep -wm1 -q "$seq_id" ${output}.clstr.tsv &>/dev/null; then
					echo "$line" >>${output}.processed.clstr
					echo -e "$cluster\t$len\t$sim\t$seq_id" >>${output}.processed.clstr.tsv
				fi
			fi
			echo -e "$cluster\t$len\t$sim\t$seq_id" >>${output}.clstr.tsv
		fi
	done <${output}.clstr
else
	if [[ "$not_unique" = true ]]; then
		while read line; do
			if [[ "$line" =~ ^\> ]]; then
				echo "$line" >>${output}.processed.clstr
				cluster=$(echo "$line" | sed 's/>Cluster //')
			elif [[ "$line" =~ ^[0-9] ]]; then
				if ! grep -wm1 -q "$seq_id" ${output}.clstr.tsv &>/dev/null; then
					echo "$line" >>${output}.processed.clstr
				fi
			fi
		done <${output}.clstr
	fi
fi

num_seqs=$(grep -c '^>' $input || true)
num_seqs_nr=$(grep -c '^>' $output || true)

if [[ "$not_unique" = true ]]; then
	echo "# sequences: $(printf "%'d" $num_seqs) ($(printf "%'d" $num_dup_seq_ids) duplicate sequence IDs)" 1>&2
else
	echo "# sequences: $(printf "%'d" $num_seqs)" 1>&2
fi
echo -e "# nr sequences: $(printf "%'d" $num_seqs_nr)\n" 1>&2

{
	echo "Output(s):"
	echo "----------"

	echo " - ${output}"
	echo " - ${output}.clstr"
	if [[ "$not_unique" = true ]]; then
		echo " - ${output}.processed.clstr (duplicate sequence IDs removed)"
	fi
	if [[ "$format" = true ]]; then
		echo " - ${output}.clstr.tsv"
		if [[ "$not_unique" = true ]]; then
			echo " - ${output}.processed.clstr.tsv (duplicate sequence IDs removed)"
		fi
	fi
} 1>&2

if [[ "$verbose" = true ]]; then
	echo -e "\nEND: $(date)\n" 1>&2
	echo -e "STATUS: DONE." 1>&2
fi
