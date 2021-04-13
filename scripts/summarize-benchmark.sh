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

if [[ "$#" -lt 1 ]]; then
	print_error "Incorrect number of arguments."
fi

# if [[ ! -d $(realpath $1) ]]; then
#
# 	if [[ ! -e $(realpath $1) ]]; then
# 		print_error "Input directory $(realpath $1) does not exist."
# 	else
# 		print_error "Given input directory is not a directory."
# 	fi
# fi
{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo -e "CALL: $args (wd: $(pwd))\n"
} 1>&2
# first line - Step, Time, CPU, Memory
# first column - step names

if [[ ! -v ROOT_DIR ]]; then
	print_error "ROOT_DIR is unbound. Please export ROOT_DIR=/rAMPage/GitHub/directory."
fi

for i in "$@"; do
	indir=$(realpath $i)

	if [[ ! -d $indir ]]; then
		continue
	fi
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

	echo -e "Path\tStep\tPercent of CPU this job got\tElapsed (wall clock) time (h:mm:ss or m:ss)\tElapsed (wall clock) time (seconds)\tMaximum resident set size (kbytes)" >$outfile

	for logfile in $indir/*.log; do
		if [[ "$logfile" == $indir/00-summary.log || "$logfile" == $indir/00-stats.log ]]; then
			continue
		fi
		path=${workdir/$ROOT_DIR\//}
		cpu=$(awk -F ": " '/Percent of CPU this job got:/ {print $2}' $logfile | sed 's/%$//')
		raw_time=$(awk -F ": " '/Elapsed \(wall clock\) time \(h:mm:ss or m:ss\):/ {print $2}' $logfile)
		time=$($ROOT_DIR/scripts/convert-time.sh -s -u ${raw_time})
		memory=$(awk -F ": " '/Maximum resident set size \(kbytes\):/ {print $2}' $logfile)
		#	line=$(grep -Ff <(echo -e "Elapsed (wall clock) time (h:mm:ss or m:ss)\nPercent of CPU this job got:\nMaximum resident set size (kbytes):") $logfile | awk '{print $NF}' | tr '\n' '\t' | sed 's/\t$//')
		line="$(printf "%'d" $cpu)\t${raw_time}\t${time}\t$(printf "%'d" $memory)"
		if [[ -z "$line" ]]; then
			# line="0\t0\t0"
			line="NA\tNA\tNA\tNA"
		fi
		step=$(basename $logfile ".log" | cut -f2 -d-)
		echo -e "$path\t$step\t$line" >>$outfile
	done
	if [[ "$#" -eq 1 ]]; then
		column -s $'\t' -t $outfile 1>&2
		echo 1>&2
	fi
	echo "Output: $outfile" 1>&2
	echo 1>&2
done

echo -e "END: $(date)" 1>&2
echo -e "\nSTATUS: DONE.\n" 1>&2

if [[ "$email" = true ]]; then
	species=$(echo "$species" | sed 's/^./\u&. /')
	echo "$indir" | mail -s "${species}: SUMMARY" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
