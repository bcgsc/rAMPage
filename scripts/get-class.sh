#!/bin/bash
set -euo pipefail
PROGRAM=$(basename $0)
function get_help() {
	echo "DESCRIPTION:" 1>&2
	echo -e "\
		\tTakes the input taxon (e.g. order), and finds the rank 'class' in the full lineage using the E-utilities.\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	echo "USAGE(S):" 1>&2
	echo -e "\
		\t$PROGRAM [OPTIONS] <taxon>\n \ " | column -s$'\t' -t echo 1>&2

	echo "OPTION(S):" 1>&2
	echo -e "\
		\t-h\tshow this help menu\n \
		" | column -s$'\t' -t
	exit 1
}

while getopts :h opt
do
	case $opt in
		h) get_help;;
		\?) echo "ERROR: Invalid option: -$OPTARG" 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2; get_help;;
	esac
done

shift $((OPTIND-1))

if [[ "$#" -eq 0 ]]
then
	get_help
fi

if [[ "$#" -ne 1 ]]
then
	echo "ERROR: Incorrect number of arguments." 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2; get_help;
fi

taxon=$1
echo "Searching for the 'class' rank  with the given taxon..." 1>&2
echo -e "COMMAND: $RUN_ESEARCH -db taxonomy -query $taxon | $RUN_EFETCH -format native -mode xml | grep -w -B1 class | head -n1 | awk -v FS='>|<' '{print \$3}'" 1>&2
class=$($RUN_ESEARCH -db taxonomy -query $taxon | $RUN_EFETCH -format native -mode xml | grep -w -B1 class | head -n1 | awk -v FS=">|<" '{print $3}')
echo "${class,,}"
