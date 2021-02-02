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
# 1 - get_help function
function get_help() {
	{
		# DESCRIPTION
		echo "DESCRIPTION:"
		echo -e "\
		\tUsing cURL, gets draft assemblies given accession numbers.\n \
		" | table

		# USAGE
		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] -o <output directory> <FTP Genbank path>\n \
		" | table

		# OPTIONS
		echo "OPTION(S):"
		echo -e "\
		\t-h\tshow this help menu\n \
		\t-o\toutput directory\t(required)\n \
		" | table
	} 1>&2
	exit 1
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

# 2 - print_error function
function print_error() {
	{
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

outdir=""
# 4 - get options
while getopts :ho: opt; do
	case $opt in
	h) get_help ;;
	o)
		outdir="$(realpath $OPTARG)"
		;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

# 5 - wrong arguments given
if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 - no input files to check, check if URL works
if [[ -z $outdir ]]; then
	print_error "Required argument -o <output directory> missing."
else
	mkdir -p $outdir
fi

if [[ "$1" =~ ^/ ]]; then
	path=$1
else
	path=/$1
fi

base_url="ftp://ftp.ncbi.nlm.nih.gov"
url="${base_url}${path}"
filename=$(echo "$path" | awk -F "/" '{print $NF}')

echo "Checking URL..." 1>&2
# if wget -q --method=HEAD $url; then
if curl --head --silent --fail $url &>/dev/null; then
	echo -e "\t\t...exists!\n" 1>&2
else
	print_error "The URL $url does not exist."
fi

# 7 - no status files
# 8 - print env details

{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"
	echo -e "PATH: $PATH\n"
	echo "PROGRAM: $(command -v curl)"
	# echo "PROGRAM: $(command -v wget)"
	# echo -e "VERSION: $(wget -V | head -n1 | awk '{print $3}')\n"
	echo -e "VERSION: $(curl -V | head -n1 | awk '{print $2}')\n"
} 1>&2

echo "Downloading the reference transcriptome..." 1>&2
echo -e "COMMAND: (cd $outdir && curl -O $url &> $outdir/logs/00-reference.log)\n" 1>&2
(cd $outdir && curl -O $url &>>$outdir/logs/00-reference.log)

# echo -e "COMMAND: wget --tries=inf -P $outdir $url\n" 1>&2
# wget --tries=inf -P $outdir $url

if [[ -s $outdir/$filename ]]; then
	echo -e "\nSTATUS: DONE." 1>&2
else
	echo -e "\nSTATUS: FAILED." 1>&2
fi
