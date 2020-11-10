#!/bin/bash

set -euo pipefail
PROGRAM=$(basename $0)
function get_help() {
	# DESCRIPTION
	echo "DESCRIPTION:" 1>&2
	echo -e "\
		\tGets the SRA RUN (i.e. SRR) accessions using wget.\n \
		\tOUTPUT: runs.txt, metadata.tsv RUNS.DONE METADATA.DONE\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2
	# USAGE
	echo "USAGE(S):" 1>&2 
	echo -e "\
		\t$PROGRAM -o <output directory> <SRA accessions TXT file>\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	# OPTIONS
	echo "OPTION(S):" 1>&2
	echo -e "\
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n \
		" | column -s$'\t' -t 1>&2
	exit 1
	
}
while getopts :ho: opt
do
	case $opt in 
		h) get_help;;
		o) outdir=$(realpath $OPTARG); mkdir -p $outdir;;
		\?) echo "ERROR: Invalid option: -$OPTARG" 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2; get_help ;;
	esac
done

shift $((OPTIND-1))
if [[ "$#" -eq 0 ]]
then
	get_help
fi
if [[ "$#" -ne 1 ]]
then
	echo "ERROR: Incorrect number of arguments." 1>&2;printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2
	get_help
fi

echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)" 1>&2
start_sec=$(date '+%s')

echo -e "PATH=$PATH\n" 1>&2

if [[ -f $outdir/RUNS.DONE ]]
then
	rm $outdir/RUNS.DONE
fi

accessions=$(cat $1)

echo "Downloading run info..." 1>&2
for i in $accessions
do
	while [[ ! -s $outdir/temp.${i}.csv ]]
	do
		wget --tries=inf -o "$outdir/${i}.wget.log" -O "$outdir/temp.${i}.csv" "http://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?save=efetch&db=sra&rettype=runinfo&term=${i}" || true
	done
done

# wait

cat $outdir/*.wget.log > $outdir/wget.log
# get SRR numbers
cat $outdir/temp*.csv > $outdir/RunInfoTable.csv 

sed -i '/^$/d' $outdir/RunInfoTable.csv

echo "Downloading SRA Run accessions to $outdir/runs.txt..." 1>&2
cat $outdir/RunInfoTable.csv | cut -f1 -d, | sort -u | sed '/^$/d' | grep -v 'Run' > $outdir/runs.txt

rm $outdir/temp*.csv
rm $outdir/*.wget.log

echo "Fetching metadata..." 1>&2
$ROOT_DIR/scripts/get-metadata.sh -o $outdir $accessions
echo -e "END: $(date)\n" 1>&2
end_sec=$(date '+%s')

$ROOT_DIR/scripts/get-runtime.sh -T $start_sec $end_sec 1>&2
echo 1>&2

default_name="$(realpath -s $(dirname $outdir)/sra)"
if [[ "$default_name" != "$outdir" ]]
then
	count=1
	if [[ -d "$default_name" ]]
	then
		if [[ ! -h "$default_name" ]]
		then
			temp="${default_name}-${count}"
			while [[ -d "$temp" ]]
			do
				count=$((count+1))
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
