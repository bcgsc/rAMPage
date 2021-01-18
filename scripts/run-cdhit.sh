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

# 1 - get_help function
function get_help() {
	{
		echo "DESCRIPTION:"
		echo -e "\
		\tRuns CD-HIT to reduce redundancy between protein sequences.\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-h] [-o <output FASTA file>] [-s <0 to 1>] [-t <int>] [-v] <input protein FASTA file>\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
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

# 4 - getopts
while getopts :ho:s:t:v opt; do
	case $opt in
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

echo "PROGRAM: $(command -v $RUN_CDHIT)" 1>&2
cdhit_version=$({ $RUN_CDHIT -h 2>&1 | head -n1 | awk -F "version " '{print $2}' | tr -d '='; } || true)
echo -e "VERSION: $cdhit_version\n" 1>&2

log=$outdir/cdhit.log

echo "Conducting redundancy removal at $(echo "$similarity * 100" | bc)% global sequence similarity..." 1>&2
echo -e "COMMAND: $RUN_CDHIT -i $input -o $output -c $similarity -T $threads &>> $log\n" 1>&2
$RUN_CDHIT -i $input -o $output -c $similarity -T $threads &>>$log

if [[ "$verbose" = true ]]; then
	echo -e "END: $(date)\n" 1>&2
	echo -e "STATUS: DONE." 1>&2
fi
