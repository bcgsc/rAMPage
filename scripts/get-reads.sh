#!/bin/bash
#SBATCH --partition=upgrade
set -euo pipefail
PROGRAM=$(basename $0)
function get_help() {
	echo "DESCRIPTION:" 1>&2
	echo -e "\
		\tGets reads for one single organism, using fasterq-dump.\n \
		\tOUTPUT: *.fastq.gz, RUNS.DONE
		\tFor more information: https://github.com/ncbi/sra-tools/wiki/HowTo:-fasterq-dump\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	# USAGE
	echo "USAGE(S):" 1>&2
	echo -e "\
		\t$PROGRAM [OPTIONS] -o <output directory> <SRA RUN (i.e. SRR) accession list>\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	# OPTIONS
	echo "OPTION(S):" 1>&2 
	echo -e "\
		\t-a <address>\temail alert\n \
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n \
		\t-t <int>\tnumber of threads\t(default = 2)\n \
		" | column -s$'\t' -t 1>&2
	exit 1
}

# defaults
threads=6
email=""
while getopts :a:ho:t: opt
do
	case $opt in 
		a) address="$OPTARG"; email="-a $address" ;;
		h) get_help;;
		o) outdir="$(realpath $OPTARG)";;
		t) threads="$OPTARG";;
		\?) echo "ERROR: Invalid option: -$OPTARG" 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2 ; echo 1>&2; get_help;;
	esac
done

shift $((OPTIND-1))


if [[ "$#" -eq 0 ]]
then
	get_help
fi

if [[ "$#" -ne 1 ]]
then
	echo "ERROR: Incorrect number of arguments."; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2
	get_help
fi

if [[ -f $outdir/READS.DONE ]]
then
	rm $outdir/READS.DONE
elif [[ -f $outdir/READS.FAIL ]]
then
	rm $outdir/READS.FAIL
fi

echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)" 1>&2
start_sec=$(date '+%s')
mkdir -p $outdir
sra=$(realpath $1)

export PATH=$(dirname $(command -v $FASTERQ_DUMP)):$PATH
echo -e "PATH=$PATH\n" 1>&2

echo "PROGRAM: $(command -v $FASTERQ_DUMP)" 1>&2
$FASTERQ_DUMP --version > /dev/null
echo -e "VERSION: $($FASTERQ_DUMP --version | awk '/version/ {print $NF}')\n" 1>&2 
while read accession
do
	# assume that the FASTQs do not exist due to timestamping of the folders
	echo "Initiating download of ${accession}..." 1>&2
	$ROOT_DIR/scripts/get-accession.sh $email -t $threads -o $outdir $accession &
done < $sra

# wait for all child processes to finish
wait

# soft link to 'default name'
default_name="$(realpath -s $(dirname $outdir)/raw_reads)"
if [[ "$outdir" != "$default_name" ]]
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
			echo -e "\nSince $default_name already exists, $default_name is renamed to $temp as to not overwrite old reads.\n" 1>&2
			mv $default_name $temp
		else
			unlink ${default_name}
		fi
	fi
		echo -e "\n$outdir softlinked to $default_name\n" 1>&2
		(cd $(dirname $outdir) && ln -fs $(basename $outdir) $(basename $default_name))
fi
fail=false
failed_accs=()
while read accession
do
	if ls $outdir/${accession}*.fastq.gz 1> /dev/null 2>&1
	then
		:
	else
		fail=true
		failed_accs+=( $accession )
	fi
done < $sra

if [[ "$fail" = true ]]
then
	touch $outdir/READS.FAIL
	if [[ -f "$outdir/READS.DONE" ]]
	then
		rm $outdir/READS.DONE
	fi

	org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	if [[ ! -z $email  ]]
	then
		echo "${outdir}: ${failed_accs[*]}" | mail -s "Failed downloading reads for $org" "$address"
		echo "Email alert sent to $address." 1>&2
	fi

	echo "Failed to download: ${failed_accs[*]}" 1>&2
	echo "STATUS: failed." 1>&2
	exit 2
fi

workdir=$(dirname $outdir)

if ls $outdir/*_?.fastq.gz 1> /dev/null 2>&1
then
	touch $workdir/PAIRED.END
else
	touch $workdir/SINGLE.END
fi

echo -e "\nEND: $(date)\n" 1>&2
end_sec=$(date '+%s')

$ROOT_DIR/scripts/get-runtime.sh -T $start_sec $end_sec 1>&2
echo 1>&2
touch $outdir/READS.DONE

org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
if [[ ! -z $email  ]]
then
	echo "$outdir" | mail -s "Finished downloading reads for $org" "$address"
	echo "Email alert sent to $address." 1>&2
fi
echo "STATUS: complete." 1>&2

# Example
# Subject: Finished downloading reads for SPECIES TISSUE
# Message: $ROOT_DIR/ORDER/SPECIES/TISSUE/raw_reads
