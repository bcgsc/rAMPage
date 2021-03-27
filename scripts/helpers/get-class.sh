#!/usr/bin/env bash
set -euo pipefail
PROGRAM=$(basename $0)

function table() {
	if column -L <(echo) &>/dev/null; then
		cat | column -s $'\t' -t -L
	else
		cat | column -s $'\t' -t
		echo
	fi
}
# 1 - get_help
function get_help() {
	{
		echo "DESCRIPTION:"
		echo -e "\
		\tTakes the input taxon (e.g. order), and finds the rank 'class' in the full lineage using the E-utilities.\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] <taxon>\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-h\tshow this help menu\n \
		" | table
	} 1>&2
	exit 1
}

# 2 - print_error
function print_error() {
	{
		message="$1"
		echo "ERROR: $message"
		print_line
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
		print_line
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

if [[ ! -v RUN_ESEARCH ]]; then
	if command -v esearch &>/dev/null; then
		RUN_ESEARCH=$(command -v esearch)
	else
		print_error "RUN_ESEARCH is unbound and no 'esearch' found in PATH. Please export RUN_ESEARCH=/path/to/esearch/executable."
	fi
elif ! command -v $RUN_ESEARCH &>/dev/null; then
	print_error "Unable to execute $RUN_ESEARCH."
fi

if [[ ! -v RUN_EFETCH ]]; then
	if command -v efetch &>/dev/null; then
		RUN_EFETCH=$(command -v efetch)
	else
		print_error "RUN_EFETCH is unbound and no 'efetch' found in PATH. Please export RUN_ESEARCH=/path/to/efetch/executable."
	fi
elif ! command -v $RUN_EFETCH &>/dev/null; then
	print_error "Unable to execute $RUN_EFETCH."
fi
# 8 - no env print
taxon=$1
{
	echo "PROGRAM: $(command -v $RUN_ESEARCH)"
	echo -e "VERSION: $($RUN_ESEARCH --help | awk 'NR==1 {print $NF}')\n"

	echo "PROGRAM: $(command -v $RUN_EFETCH)"
	echo -e "VERSION: $($RUN_EFETCH --help | awk 'NR==1 {print $NF}')\n"
} 1>&2

echo "Searching for the 'class' rank  with the given taxon..." 1>&2
echo -e "COMMAND: $RUN_ESEARCH -db taxonomy -query $taxon < /dev/null | $RUN_EFETCH -format native -mode xml | grep -w -B1 class | head -n1 | awk -v FS='>|<' '{print \$3}'" 1>&2
class=$($RUN_ESEARCH -db taxonomy -query $taxon </dev/null | $RUN_EFETCH -format native -mode xml | grep -w -B1 class | head -n1 | awk -v FS=">|<" '{print $3}')
# echo "${class,,}"
echo "${class}" | sed 's/.\+/\L&/'
