#!/usr/bin/env bash
set -euo pipefail
PROGRAM=$(basename $0)

# 1 - get_help
function get_help() {
	{
		echo "DESCRIPTION:"
		echo -e "\
		\tTakes the input taxon (e.g. order), and finds the rank 'class' in the full lineage using the E-utilities.\n \
		" | column -s$'\t' -t -L

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] <taxon>\n \
		" | column -s$'\t' -t -L

		echo "OPTION(S):"
		echo -e "\
		\t-h\tshow this help menu\n \
		" | column -s$'\t' -t -L
	} 1>&2
	exit 1
}

# 2 - print_error
function print_error() {
	{
		message="$1"
		echo "ERROR: $message"
		printf '%.0s=' $(seq 1 $(tput cols))
		echo
		get_help
	} 1>&2
}

# 3 - no arguments given
if [[ "$#" -eq 0 ]]; then
	get_help
fi

# 4 - get options
while getopts :h opt; do
	case $opt in
	h) get_help ;;
	\?)
		echo "ERROR: Invalid option: -$OPTARG" 1>&2
		printf '%.0s=' $(seq 1 $(tput cols)) 1>&2
		echo 1>&2
		get_help
		;;
	esac
done

shift $((OPTIND - 1))

# 5 - incorrect number of arguments
if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 - no input check

# 7 - no status files

# 8 - no env print
taxon=$1
echo "Searching for the 'class' rank  with the given taxon..." 1>&2
echo -e "COMMAND: $RUN_ESEARCH -db taxonomy -query $taxon < /dev/null | $RUN_EFETCH -format native -mode xml | grep -w -B1 class | head -n1 | awk -v FS='>|<' '{print \$3}'" 1>&2
class=$($RUN_ESEARCH -db taxonomy -query $taxon < /dev/null | $RUN_EFETCH -format native -mode xml | grep -w -B1 class | head -n1 | awk -v FS=">|<" '{print $3}')
echo "${class,,}"
