#!/bin/bash

set -euo pipefail
PROGRAM=$(basename $0)

function get_help() {
	echo "DESCRIPTION:" 1>&2
	echo -e "\
		\tTakes a protein FASTA file as input and predicts a secondary structure and RSA score.\n\
		" | column -s $'\t' -t 1>&2
	echo 1>&2

	echo "USAGE(S):" 1>&2
	echo -e "\
		\t$PROGRAM [OPTIONS] -o <output directory> <protein FASTA file>\n \
		" | column -s $'\t' -t 1>&2
	echo 1>&2

	echo "OPTION(S):" 1>&2
	echo -e "\
		\t-a <address>\temail address for alert\n \
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n\
		\t-t <INT>\tnumber of threads\t(default = 8)\n \
		" | column -s $'\t' -t 1>&2

	exit 1
}


threads=8
email=false
while getopts :a:ho:t: opt
do
	case $opt in
		a) address="$OPTARG"; email=true;;
		h) get_help;;
		o) outdir=$(realpath $OPTARG);mkdir -p $outdir;;
		t) threads=$OPTARG;;
		\?) echo "ERROR: Invalid option: -$OPTARG" 1>&2; printf '%.0s=' $(seq $(tput cols)) 1>&2; echo 1>&2; get_help;;
	esac
done

shift $((OPTIND-1))

if [[ "$#" -eq 0 ]]
then
	get_help
fi

if [[ "$#" -ne 1 ]]
then
	echo "ERROR: Incorrect number of arguments." 1>&2; printf '%.0s=' $(seq $(tput cols)) 1>&2; echo 1>&2; get_help;
fi
echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)" 1>&2
start_sec=$(date '+%s')

echo "PROGRAM: $(command -v $RUN_SABLE)"
echo -e "VERSION: $(grep "SABLE ver" $RUN_SABLE | awk '{print $NF}')\n"

echo "PROGRAM: $(command -v $BLAST_BIN/psiblast)" 1>&2
echo -e "VERSION: $($BLAST_BIN/psiblast -version | tail -n1 | cut -f4- -d' ')\n" 1>&2

fasta=$(realpath $1)
filename=$(basename $fasta ".faa")
# This script differs, as it must be run in the output directory.
(cd $outdir && cp $fasta $outdir/data.seq && $RUN_SABLE $threads)

touch $outdir/SABLE.DONE

if [[ "$email" = true ]]
then
	org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	echo "$outdir" | mail -s "Successful AMPlify run on $org" $address
	echo "Email alert sent to $address." 1>&2
fi

default_name="$(realpath -s $(dirname $outdir)/sable)"
if [[ "$default_name" != "$outdir" ]]
then
	if [[ -d "$default_name" ]]
	then
		count=1
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
		fi
	fi
		echo -e "$outdir softlinked to $default_name\n" 1>&2
		(cd $(dirname $outdir) && ln -fs $(basename $outdir) $(basename $default_name))
fi

echo -e "END: $(date)\n" 1>&2
end_sec=$(date '+%s')

$ROOT_DIR/scripts/get-runtime.sh -T $start_sec $end_sec 1>&2
echo 1>&2
echo "STATUS: complete." 1>&2
