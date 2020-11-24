#!/usr/bin/env bash

set -euo pipefail
PROGRAM=$(basename $0)

# 1 - get_help function
if column -L <(echo) &>/dev/null; then
	l_opt="-L"
	blank=""
else
	l_opt=""
	blank="echo"
fi

function get_help() {
	{
		# DESCRIPTION
		echo "DESCRIPTION:"
		echo -e "\
		\tUsing cURL, gets draft assemblies given accession numbers.\n \
		" | column -s$'\t' -t $l_opt
		$blank

		# USAGE
		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] -o <output directory> <FTP Genbank path>\n \
		" | column -s$'\t' -t $l_opt
		$blank

		# OPTIONS
		echo "OPTION(S):"
		echo -e "\
		\t-h\tshow this help menu\n \
		\t-o\toutput directory\t(required)\n \
		" | column -s$'\t' -t $l_opt
		$blank
	} 1>&2
	exit 1
}

# 2 - print_error function
function print_error() {
	{
		message="$1"
		echo "ERROR: $message"
		printf '%.0s=' $(seq 1 $(tput cols))
		echo
		get_help
	} 1>&2
}

# 3 - no arguments
if [[ "$#" -eq 0 ]]; then
	get_help
fi
# 4 - get options

while getopts :ho: opt; do
	case $opt in
	h) get_help ;;
	o)
		outdir="$OPTARG"
		mkdir -p $outdir
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
