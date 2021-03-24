#!/usr/bin/env bash
set -euo pipefail
FULL_PROGRAM=$0
PROGRAM=$(basename $FULL_PROGRAM)
if [[ "$PROGRAM" == "slurm_script" ]]; then
	FULL_PROGRAM=$(scontrol show job $SLURM_JOBID | awk '/Command=/ {print $1}' | awk -F "=" '{print $2}')
	PROGRAM=$(basename ${FULL_PROGRAM})

fi
args="$FULL_PROGRAM $*"
function table() {
	if column -L <(echo) &>/dev/null; then
		cat | column -s $'\t' -t -L
	else
		cat | column -s $'\t' -t
		echo
	fi
}

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

function print_error() {
	{
		echo -e "CALL: $args (wd: $(pwd))\n"
		message="$1"
		echo "ERROR: $message"
		print_line
		get_help
	} 1>&2
}

function get_help() {
	{
		echo "DESCRIPTION:"
		echo -e "\
	\tConverts hh:mm:ss time-format (or only seconds) to human readable time.\n \
	" | table

		echo "USAGE(S):"
		echo -e "\
	\t$PROGRAM <hh:mm:ss>\n \
	" | table

		echo "OPTION(S):"
		echo -e "\
	\t-h\tshow this help menu\n \
	\t-m\tkeep milliseconds\t(only when time is < 1 hour)\n \
	\t-s\tconvert time to seconds\n \
	\t-u\thide units\t(only applies with -s)\n \
	" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM 11:22:33\n \
		\t$PROGRAM -s 11:22:33\n \
		\t$PROGRAM 112233\n \
		" | table
	}
}

if [[ "$#" -eq 0 ]]; then
	get_help
fi
units=true
in_seconds=false
ms=false
while getopts :hsum opt; do
	case $opt in
	h) get_help ;;
	m) ms=true ;;
	s) in_seconds=true ;;
	u) units=false ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

time=$1

num_fields=$(echo "$time" | awk -F ":" '{print NF}')
if [[ "$num_fields" -eq 3 ]]; then
	# means there is an hour
	hours=$(echo "$time" | awk -F: '{print $1}' | sed 's/^0//')
	minutes=$(echo "$time" | awk -F: '{print $2}' | sed 's/^0//')
	seconds=$(echo "$time" | awk -F: '{print $3}' | sed 's/^0//')

	hours_in_seconds=$(echo "${hours}*60*60" | bc)
	minutes_in_seconds=$(echo "${minutes}*60" | bc)

	hours_in_days=$(echo "${hours}/24" | bc)
	hours_in_hours=$(echo "${hours}%24" | bc)
	total_seconds=$(echo "${hours_in_seconds}+${minutes_in_seconds}+${seconds}" | bc)

	if [[ "${in_seconds}" == true ]]; then
		if [[ "$units" = true ]]; then
			string=$(printf "%'ds" ${total_seconds})
		else
			string=$(printf "%'d" ${total_seconds})
		fi
	else
		string=$(printf "%'dd %2dh %2dm %2ds" ${hours_in_days} ${hours_in_hours} ${minutes} ${seconds})
	fi
elif [[ "$num_fields" -eq 2 ]]; then
	# means there is NO hour, and there are milliseconds
	minutes=$(echo "$time" | awk -F "[:.]" '{print $1}' | sed 's/^0//')
	if [[ -z "$minutes" ]]; then
		minutes=0
	fi
	if [[ "$ms" = true ]]; then
		seconds=$(echo "$time" | awk -F "[:]" '{print $2}' | sed 's/^0//')
	else
		seconds=$(echo "$time" | awk -F "[:.]" '{print $2}' | sed 's/^0//')
	fi
	minutes_in_seconds=$(echo "${minutes}*60" | bc)

	total_seconds=$(echo "${minutes_in_seconds}+${seconds}" | bc)
	if [[ "${in_seconds}" = true ]]; then
		if [[ "$units" = true ]]; then
			if [[ "$ms" = true ]]; then
				string=$(printf "%'fs" ${total_seconds})
			else
				string=$(printf "%'ds" ${total_seconds})
			fi
		else
			if [[ "$ms" = true ]]; then
				string=$(printf "%'f" ${total_seconds})
			else
				string=$(printf "%'d" ${total_seconds})
			fi
		fi
	else
		if [[ "$ms" = true ]]; then
			string=$(printf "%'dd %2dh %2dm %2fs" 0 0 ${minutes} ${seconds})
		else
			string=$(printf "%'dd %2dh %2dm %2ds" 0 0 ${minutes} ${seconds})
		fi
	fi
else
	# assume that the time is already in total_seconds
	mseconds=$(echo "${time}" | awk -F "." '{print $2}')
	time=$(echo "${time}" | awk -F "." '{print $1}')
	min=$(echo "${time}/60" | bc)
	sec=$(echo "${time}%60" | bc)
	hour=$(echo "${min}/60" | bc)
	min=$(echo "${min}%60" | bc)
	day=$(echo "${hour}/24" | bc)
	hour=$(echo "${hour}%24" | bc)

	if [[ "${in_seconds}" = true ]]; then
		string=$(printf "%'d" $time)
	else
		string=$(printf "%'dd %2dh %2dm %2ds" $day $hour $min $sec)
	fi
fi

echo "$string"
