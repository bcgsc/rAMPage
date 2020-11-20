#!/usr/bin/env bash
set -euo pipefail
PROGRAM=$(basename $0)

function get_help() {
	# DESCRIPTION
	echo "DESCRIPTION:" 1>&2
	echo -e "\
		\tCalculates the runtime in 00d 00h 00m 00s format given the start and end seconds.\n\
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	echo "USAGE(S):" 1>&2
	echo -e "\
		\t$PROGRAM [OPTIONS] <START SEC> <END SEC>\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	echo "OPTION(S):" 1>&2
	echo -e "\
		\t-h\tshow this help menu\n \
		\t-T\tprint 'total' runtime\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	echo "EXAMPLE(S):" 1>&2
	echo -e "\
		\$ $PROGRAM -T 100 1005\n \
		Total runtime (seconds): 905\n \
		Total runtime: 00d 00h 15m 05s\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2
	echo -e "\
		\$ $PROGRAM 100 1005\n \
		Time elapsed (seconds): 905\n \
		Time elapsed: 00d 00h 15m 05s\n \
		" | column -s$'\t' -t 1>&2
	exit 1
}
total=false
while getopts :hT opt
do
	case $opt in 
		h) get_help;;
		T) total=true;;
		\?) echo "ERROR: Invalid option: -$OPTARG" 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2; get_help;;
	esac
done

shift $((OPTIND-1))
if [[ "$#" -eq 0 ]]
then
	get_help
fi

if [[ "$#" -ne 2 ]]
then
	echo "ERROR: Incorrect number of arguments." 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2; get_help
fi

start_sec=$1
end_sec=$2

if [[ "$start_sec" -gt "$end_sec" ]]
then
	start_sec=$2
	end_sec=$1
	echo "The start time (seconds) is greater than the end time (seconds). Switching the two..." 1>&2
fi

runtime_total=$(( end_sec - start_sec ))
runtime_min=$(( runtime_total / 60 ))
runtime_sec=$(( runtime_total % 60 ))
runtime_hour=$(( runtime_min / 60 ))
runtime_min=$(( runtime_min % 60 ))
runtime_day=$(( runtime_hour / 24 ))
runtime_hour=$(( runtime_hour % 24 ))
if [[ "$total" = true ]]
then
	printf "Total runtime (seconds): %'d\n" $runtime_total
	printf "Total runtime: %02dd %02dh %02dm %02ds\n" $runtime_day $runtime_hour $runtime_min $runtime_sec
else
	printf "Time elapsed (seconds): %'d\n" $runtime_total
	printf "Time elapsed: %02dd %02dh %02dm %02ds\n" $runtime_day $runtime_hour $runtime_min $runtime_sec
fi


