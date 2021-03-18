#!/usr/bin/env bash
set -euo pipefail
FULL_PROGRAM=$0
PROGRAM=$(basename $FULL_PROGRAM)
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
		\t$PROGRAM [-d] [-h] [-o <output FASTA file>] [-s <0 to 1>] [-t <int>] [-v] <input protein FASTA file>\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-d\tremove absolute duplicates (same length, 100% sequence similarity; overrides -s)\n \
		\t-h\tshow help menu\n \
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
# 4 - getopts
while getopts :dho:s:t:v opt; do
	case $opt in
	d) remove_duplicates=true ;;
	h) get_help ;;
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

if [[ -z "$output" ]]; then
	output=${input/.faa/.nr.faa}
fi
outdir=$(dirname $output)

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
	length_cutoffs=""
fi

if (($(echo "$similarity < 0" | bc -l) || $(echo "$similarity > 1" | bc -l))); then
	print_error "Sequence similarity cut-off must be between 0 and 1."
fi

if [[ "$similarity" == "1.0" || "$similarity" -eq 1 ]]; then
	remove_duplicates=true
	length_cutoffs="-S 0 -s 1"
fi

echo "PROGRAM: $(command -v $RUN_CDHIT)" 1>&2
cdhit_version=$({ $RUN_CDHIT -h 2>&1 | head -n1 | awk -F "version " '{print $2}' | tr -d '='; } || true)
echo -e "VERSION: $cdhit_version\n" 1>&2

log=$outdir/cdhit.log

if [[ $(echo "$similarity >= 0.7" | bc -l) && $(echo "$similarity <= 1.0" | bc -l) ]]; then
	wordsize=5
elif [[ $(echo "$similarity >= 0.6" | bc -l) ]]; then
	wordsize=4
elif [[ $(echo "$similarity >= 0.5" | bc -l) ]]; then
	wordsize=3
else
	wordsize=2
fi

echo "Conducting redundancy removal at $(echo "$similarity * 100" | bc)% global sequence similarity..." 1>&2
echo -e "COMMAND: $RUN_CDHIT -d 0 -l 4 -i $input -o $output -c $similarity -n $wordsize -T $threads -M 0 $length_cutoffs &>> $log\n" 1>&2
$RUN_CDHIT -d 0 -l 4 -i $input -o $output -c $similarity -n $wordsize -T $threads -M 0 $length_cutoffs &>>$log

num_seqs=$(grep -c '^>' $input || true)
num_seqs_nr=$(grep -c '^>' $output || true)

echo "# sequences: $(printf "%'d" $num_seqs)" 1>&2
echo "# nr sequences: $(printf "%'d" $num_seqs_nr)" 1>&2

if [[ "$verbose" = true ]]; then
	echo -e "\nEND: $(date)\n" 1>&2
	echo -e "STATUS: DONE." 1>&2
fi
