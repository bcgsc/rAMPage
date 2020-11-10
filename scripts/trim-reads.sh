#!/bin/bash
#SBATCH --partition=upgrade
#SBATCH --exclusive
set -euo pipefail

PROGRAM=$(basename $0)
function get_help() {
	# DESCRIPTION
	echo "DESCRIPTION:" 1>&2
	echo -e "\
		\tPreprocesses and trims reads with fastp.\n \
		\tOUTPUT: *.fastq.gz, TRIM.DONE\n \
		\tFor more information: https://github.com/OpenGene/fastp\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	# USAGE
	echo "USAGE(S):" 1>&2
	echo -e "\
		\t$PROGRAM [OPTIONS] -i <input directory> -o <output directory>\n \
		" | column -t -s$'\t' 1>&2
	echo 1>&2

	# OPTIONS
	echo "OPTION(S):" 1>&2
	echo -e "\
		\t-a <address>\temail alert\n \
		\t-h\tshow this help menu\n \
		\t-i <directory>\tinput directory for raw reads\t(required)\n \
		\t-o <directory>\toutput directory for trimmed reads\t(required)\n \
		\t-t <int>\tnumber of threads\t(default = 4)\n \
		" | column -t -s$'\t' 1>&2
	exit 1
}

if [[ "$#" -eq 0 ]]
then
	get_help
fi
threads=4
email=false
while getopts :a:hi:o:t: opt
do
	case $opt in 
		a) email=true; address="$OPTARG";;
		h) get_help;;
		i) indir=$(realpath $OPTARG);;
		o) outdir=$(realpath $OPTARG); mkdir -p $outdir;;
		t) threads="$OPTARG";;
		\?) echo "ERROR: Invalid option: -$OPTARG" 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2; get_help ;;
	esac
done

shift $((OPTIND-1))

if [[ "$#" -ne 0 ]]
then
	echo "ERROR: Incorrect number of arguments." 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2
	get_help
fi

if [[ -f $outdir/TRIM.DONE ]]
then
	rm $outdir/TRIM.DONE
elif [[ -f $outdir/TRIM.FAIL ]]
then
	rm $outdir/TRIM.FAIL
fi

echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)\n" 1>&2
start_sec=$(date '+%s') 

mkdir -p $outdir
workdir=$(dirname $indir)
if [[ -f $workdir/PAIRED.END ]]
then
	single=false
elif [[ -f $workdir/SINGLE.END ]]
then
	single=true
else
	echo "ERROR: *.END file not found. Please check that the reads have been downloaded properly." 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2; get_help;
fi

echo -e "PATH=$PATH\n" 1>&2
echo "PROGRAM: $(command -v $RUN_FASTP)" 1>&2
echo -e "VERSION: $($RUN_FASTP --version 2>&1 | awk '{print $NF}')\n" 1>&2

while read run
do
	if [[ "$single" = false ]]
	then
		if [[ ! -f "$indir/${run}_1.fastq.gz" || ! -f "$indir/${run}_2.fastq.gz" ]] && [[ -f "$indir/${run}.fastq.gz" ]]
		then
			echo -e "\nRun ${run} contains single-end reads. Paired-end reads are prioritized over single-end reads. Therefore single-end reads are skipped and not trimmed.\n" 1>&2
			sed -i "/$run/d" $(dirname $indir)/sra/runs.txt
			sed -i "/$run/d" $(dirname $indir)/sra/metadata.tsv
			sed -i "/$run/d" $(dirname $indir)/sra/RunInfoTable.csv
			echo "$run" >> $(dirname $indir)/sra/skipped.txt
			continue
		fi
	fi
	echo "Trimming ${run}..." 1>&2
	$ROOT_DIR/scripts/run-fastp.sh -t $threads -i $indir -o $outdir $run &
done < $(dirname $indir)/sra/runs.txt
wait

fail=false
failed_accs=()
while read run
do
	if [[ "$single" = true ]]
	then
		if [[ ! -s $outdir/${run}.fastq.gz ]]
		then
			fail=true
			failed_accs+=( ${run} )
		fi
	else
		if [[ ! -s $outdir/${run}_1.paired.fastq.gz || ! -s $outdir/${run}_2.paired.fastq.gz ]]
		then
			fail=true
			failed_accs+=( ${run} )
		fi
	fi

done < $(dirname $indir)/sra/runs.txt

if [[ "$fail" = true ]]
then
	touch $outdir/TRIM.FAIL

	if [[ -f "$outdir/TRIM.DONE" ]]
	then
		rm $outdir/TRIM.DONE
	fi

	if [[ "$email" = true ]]
	then
		org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		echo "${outdir}: ${failed_accs[*]}" | mail -s "Failed trimming reads for $org" "$address"
		echo "Email alert sent to $address." 1>&2
	fi
	echo "Failed to trim: ${failed_accs[*]}" 1>&2
	echo "STATUS: failed." 1>&2
	exit 2
fi

if ls $workdir/core.* &> /dev/null
then
	echo "ERROR: Core dumped." 1>&2
	rm $workdir/core.*
	exit 3
fi

# tally up the number of reads before and after trimming by parsing all the logs
total=$(awk '/reads passed filter:/ {print $NF}' $outdir/*.log | paste -s -d+ | bc)
low_qual=$(awk '/reads failed due to low quality:/ {print $NF}' $outdir/*.log | paste -s -d+ | bc)
many_Ns=$(awk '/reads failed due to too many N:/ {print $NF}' $outdir/*.log | paste -s -d+ | bc)
too_short=$(awk '/reads failed due to too short:/ {print $NF}' $outdir/*.log | paste -s -d+ | bc)
adapter_trimmed=$(awk '/reads with adapter trimmed:/ {print $NF}' $outdir/*.log | paste -s -d+ | bc)

echo -e "\nReads passed filter: $(printf "%'d" $total)" 1>&2
echo "Reads failed due to low quality: $(printf "%'d" $low_qual)" 1>&2
echo "Reads failed due to too many Ns: $(printf "%'d" $many_Ns)" 1>&2
echo "Reads failed due to short length: $(printf "%'d" $too_short)" 1>&2
echo "Reads with adapter trimmed: $(printf "%'d" $adapter_trimmed)" 1>&2

default_name="$(realpath -s $(dirname $outdir)/trimmed_reads)"
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
			echo -e "Since $default_name already exists, $default_name is renamed to $temp as to not overwrite old trimmed reads.\n" 1>&2
			mv $default_name $temp
		else
			unlink $default_name
		fi
	fi
		if [[ "$default_name" != "$outdir" ]]
		then
			echo -e "\n$outdir softlinked to $default_name\n" 1>&2
			(cd $(dirname $outdir) && ln -fs $(basename $outdir) $(basename $default_name))
		fi
fi
echo -e "\nEND: $(date)\n" 1>&2
end_sec=$(date '+%s')
$ROOT_DIR/scripts/get-runtime.sh -T $start_sec $end_sec 1>&2
echo 1>&2

touch $outdir/TRIM.DONE
if [[ "$email" = true ]]
then
	org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	echo "$outdir" | mail -s "Finished trimming reads for $org" "$address"
	echo "Email alert sent to $address." 1>&2
fi
echo "STATUS: complete." 1>&2
# EXAMPLE
# Subject: Finished trimming reads for SPECIES TISSUE
# Message: $ROOT_DIR/ORDER/SPECIES/TISSUE/trimmed_reads
