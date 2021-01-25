#!/usr/bin/env bash
set -euo pipefail
FULL_PROGRAM=$0
PROGRAM=$(basename $FULL_PROGRAM)
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
		\tSummarizes wall clock time, CPU, and memory from /usr/bin/time -pv.\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-a <address>] [-h] <logs directory>\n \
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

if [[ "$#" -ne 1 ]]; then
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
# first line - Step, Time, CPU, Memory
# first column - step names

indir=$(realpath $1)
outfile=$indir/00-summary.tsv

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

echo -e "Step\tPercent of CPU this job got\tElapsed (wall clock) time (h:mm:ss or m:ss)\tMaximum resident set size (kbytes)" >$outfile

for logfile in $indir/*.log; do
	if [[ "$logfile" == $indir/00-summary.log || "$logfile" == $indir/00-stats.log ]]; then
		continue
	fi
	line=$(grep -Ff <(echo -e "Elapsed (wall clock) time (h:mm:ss or m:ss)\nPercent of CPU this job got:\nMaximum resident set size (kbytes):") $logfile | awk '{print $NF}' | tr '\n' '\t' | sed 's/\t$//')
	if [[ -z "$line" ]]; then
		# line="0\t0\t0"
		line="NA\tNA\tNA"
	fi
	step=$(basename $logfile ".log" | cut -f2 -d-)
	echo -e "$step\t$line" >>$outfile
done

column -s $'\t' -t $outfile
echo -e "\nEND: $(date)" 1>&2
echo -e "\nSTATUS: DONE.\n" 1>&2

echo "Output: $outfile" 1>&2
if [[ "$email" = true ]]; then
	species=$(echo "$species" | sed 's/^./\u&. /')
	echo "$indir" | mail -s "${species}: SUMMARY" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
