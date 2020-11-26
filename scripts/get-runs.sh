#!/usr/bin/env bash
set -euo pipefail
PROGRAM=$(basename $0)

# 1 - get_help function
function get_help() {
	# DESCRIPTION
	{
		echo -e "PROGRAM: $PROGRAM\n"
		echo "DESCRIPTION:"
		echo -e "\
		\tGets the SRA RUN (i.e. SRR) accessions using wget.\n \
		\n \
		\tOUTPUT:\n \
		\t-------\n \
		\t  - runs.txt\n \
		\t  - metadata.tsv\n \
		\t  - RUNS.DONE\n \
		\t  - METADATA.DONE\n \
		\n
		\tEXIT CODES:\n \
		\t-------------\n \
		\t  - 0: successfully completed\n \
		\t  - 1: general error\n \
        " | column -s$'\t' -t -L

		# USAGE
		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] -o <output directory> <SRA accessions TXT file>\n \
        " | column -s$'\t' -t -L

		# OPTIONS
		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail alert\n \
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n \
		" | column -s$'\t' -t -L

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -o /path/to/sra /path/to/accessions.txt\n \
		" | column -s $'\t' -t -L
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

# 3 - no arguments given
if [[ "$#" -eq 0 ]]; then
	get_help
fi

email=false
outdir=""
# 4 - read options
while getopts :a:ho: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	h) get_help ;;
	o)
		outdir=$(realpath $OPTARG)
		;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

# 5 - incorrect number of arguments given
if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number or arguments."
fi

# 6 - check input files
if [[ -z $outdir ]]; then
	print_error "Required argument -o <output directory> missing."
else
	mkdir -p $outdir
fi

if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) is empty."
fi

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

# 7 - remove status files
rm -f $outdir/RUNS.DONE

# 8 - print environment details
echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)" 1>&2
# start_sec=$(date '+%s')

echo -e "PATH=$PATH\n" 1>&2

accessions=$(cat $1)

echo "Downloading run info..." 1>&2
echo "PROGRAM: $(command -v curl)" 1>&2
echo -e "VERSION: $(curl -V | head -n1 | awk '{print $2}')\n" 1>&2

for i in $accessions; do
	# while [[ ! -s $outdir/temp.${i}.csv ]]; do
	# 	wget --tries=inf -o "$outdir/${i}.wget.log" -O "$outdir/temp.${i}.csv" "http://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?save=efetch&db=sra&rettype=runinfo&term=${i}" || true
	# done

	(cd $outdir && curl -L -o temp.${i}.csv "http://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?save=efetch&db=sra&rettype=runinfo&term=${i}" &>${i}.curl.log)
done

# cat $outdir/*.wget.log >$outdir/wget.log
cat $outdir/*.curl.log >$outdir/curl.log

# get SRR numbers
cat $outdir/temp*.csv >$outdir/RunInfoTable.csv

# delete empty lines in RunInfoTable.csv
sed -i '/^$/d' $outdir/RunInfoTable.csv

echo "Downloading SRA Run accessions to $outdir/runs.txt..." 1>&2
cut -f1 -d, $outdir/RunInfoTable.csv | sort -u | sed '/^$/d' | grep -v 'Run' >$outdir/runs.txt

rm $outdir/temp*.csv
# rm $outdir/*.wget.log
rm $outdir/*.curl.log

echo "Fetching metadata..." 1>&2

echo -e "COMMAND: $ROOT_DIR/scripts/get-metadata.sh -o $outdir $accessions\n" 1>&2
$ROOT_DIR/scripts/get-metadata.sh -o $outdir $accessions

echo -e "END: $(date)\n" 1>&2
# end_sec=$(date '+%s')

# $ROOT_DIR/scripts/get-runtime.sh -T $start_sec $end_sec 1>&2
# echo 1>&2

# soft link to a generic name
default_name="$(realpath -s $(dirname $outdir)/sra)"
if [[ "$default_name" != "$outdir" ]]; then
	count=1
	if [[ -d "$default_name" ]]; then
		if [[ ! -L "$default_name" ]]; then
			temp="${default_name}-${count}"
			while [[ -d "$temp" ]]; do
				count=$((count + 1))
				temp="${default_name}-${count}"
			done
			echo -e "Since $default_name already exists, $default_name is renamed to $temp as to not overwrite old files.\n" 1>&2
			mv $default_name $temp
		else
			unlink $default_name
			echo "Unlinking the old soft link..." 1>&2
		fi
	fi
	echo -e "$outdir softlinked to $default_name\n" 1>&2
	(cd $(dirname $outdir) && ln -fs $(basename $outdir) $(basename $default_name))
fi

touch $outdir/RUNS.DONE
echo "STATUS: DONE." 1>&2

if [[ "$email" = true ]]; then
	org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
	echo "$outdir" | mail -s "${org^}: STAGE 01: DOWNLOADING METADATA: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
