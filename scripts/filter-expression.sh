#!/bin/bash
#SBATCH --partition=upgrade
#SBATCH --exclusive
set -euo pipefail
PROGRAM=$(basename $0)

function get_help() {

	echo "DESCRIPTION:" 1>&2
	echo -e "\
		\tQuantifies the expression of each transcript using Salmon and filters out lowly expressed transcripts specified by the given TPM cut-off.\n \
		\tFor more information: https://combine-lab.github.io/salmon/\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	echo "USAGE(S):" 1>&2
	echo -e "\
		\t$PROGRAM [OPTIONS] -o <output directory> -r <reference transcriptome> <readslist TXT file>\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	echo "OPTION(S):" 1>&2
	echo -e "\
		\t-a <address>\temail alert\n \
		\t-c <dbl>\tTPM cut-off\t(default = 0.50)\n \
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n \
		\t-r <FASTA file>\treference transcriptome\t(required)\n \
		\t-t <int>\tnumber of threads\t(default = 2)\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	exit 1
}
email=false
threads=2
cutoff=0.50
while getopts :a:c:ho:r:t: opt
do
	case $opt in
		a) address="$OPTARG"; email=true;;
		c) cutoff="$OPTARG";;
		h) get_help;;
		o) outdir="$(realpath $OPTARG)";;
		r) ref="$OPTARG";;
		t) threads="$OPTARG";;
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

readslist=$1
workdir=$(dirname $outdir)

if [[ -f $workdir/STRANDED.LIB ]]
then
	stranded=true
elif [[ -f $workdir/NONSTRANDED.LIB || -f $workdir/AGNOSTIC.LIB ]]
then
	stranded=false
else
	echo "ERROR: *.LIB file not found. Please check that you specified in your TSV file whether or not the library preparation was strand-specific." 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2; get_help
fi

if [[ -f $workdir/PAIRED.END ]]
then
	paired=true
elif [[ -f $workdir/SINGLE.END ]]
then
	paired=false
else
	echo "ERROR: *.END file not found." 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2; get_help;
fi
mkdir -p $outdir

if [[ -f $outdir/FILTER.DONE ]]
then
	rm $outdir/FILTER.DONE
fi

if [[ -f $outdir/FILTER.FAIL ]]
then
	rm $outdir/FILTER.FAIL
fi
echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)\n" 1>&2
start_sec=$(date '+%s')

echo -e "PATH=$PATH\n" 1>&2
echo "PROGRAM: $(command -v $RUN_SALMON)" 1>&2
echo -e "VERSION: $( $RUN_SALMON --version 2>&1 | awk '{print $NF}')\n" 1>&2

# index the reference transcriptome
echo "Creating an index from the reference transcriptome..." 1>&2
echo -e "COMMAND: $RUN_SALMON index --transcripts $ref --index $outdir/index --threads $threads &> $outdir/index.log\n" 1>&2
$RUN_SALMON index --transcripts $ref --index $outdir/index --threads $threads &> $outdir/index.log 

echo "Quantifying expression..." 1>&2

# quantify
if [[ "$paired" = true ]]
then
	if [[ "$stranded" = true ]]
	then
		libtype=ISR
		echo -e "COMMAND: $RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -1 $(awk '{print $3}' $readslist) -2 $(awk '{print $2}' $readslist) -o $outdir &> $outdir/quant.log\n" 1>&2
		$RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -1 $(awk '{print $3}' $readslist) -2 $(awk '{print $2}' $readslist) -o $outdir &> $outdir/quant.log
	else
		libtype=IU
		echo -e "COMMAND: $RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -1 $(awk '{print $2}' $readslist) -2 $(awk '{print $3}' $readslist) -o $outdir &> $outdir/quant.log\n" 1>&2
		$RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -1 $(awk '{print $2}' $readslist) -2 $(awk '{print $3}' $readslist) -o $outdir &> $outdir/quant.log
	fi
else
	if [[ "$stranded" = true ]]
	then
		libtype=SR
	else
		libtype=U
	fi
	echo -e "COMMAND: $RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -r $(awk '{print $2}' $readslist) -o $outdir &> $outdir/quant.log\n" 1>&2
	$RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -r $(awk '{print $2}' $readslist) -o $outdir &> $outdir/quant.log
fi

echo "Filtering the transcriptome for transcripts whose TPM >= ${cutoff}..." 1>&2
echo "PROGRAM: $(command -v $RUN_SEQTK)" 1>&2
seqtk_version=$( $RUN_SEQTK 2>&1 || true )
echo -e "VERSION: $( echo "$seqtk_version" | awk '/Version:/ {print $NF}')\n" 1>&2

awk -v var="$cutoff" '{if($4>=var) print}' $outdir/quant.sf > $outdir/remaining.sf
awk -v var="$cutoff" '{if($4<var) print}' $outdir/quant.sf > $outdir/discarded.sf

echo -e "COMMAND: $RUN_SEQTK subseq $ref <(awk -v var="$cutoff" '{if(\$4>=var) print \$1}' $outdir/quant.sf) > $outdir/rnabloom.transcripts.filtered.fa\n" 1>&2
$RUN_SEQTK subseq $ref <(awk -v var="$cutoff" '{if($4>=var) print $1}' $outdir/quant.sf) > $outdir/rnabloom.transcripts.filtered.fa



if [[ ! -s $outdir/rnabloom.transcripts.filtered.fa ]]
then
	touch $outdir/FILTER.FAIL
	echo "STATUS: failed." 1>&2
	
	if [[ "$email" = true ]]
	then
		org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		echo "$outdir" |  mail -s "Failed expression filtering $org" $address
		echo "Email alert sent to $address." 1>&2
	fi
	exit 2
fi

before=$(grep -c '^>' $ref)
after=$(grep -c '^>' $outdir/rnabloom.transcripts.filtered.fa)
echo -e "\
	Kept: kept.sf\n \
	Discarded: discarded.sf\n \
	" | column -t 1>&2
echo 1>&2

echo -e "\
	Before filtering: $(printf "%'d" $before)\n \
	After filtering: $(printf "%'d" $after)\n \
	" | column -t 1>&2

echo 1>&2
default_name="$(realpath -s $(dirname $outdir)/filtering)"
if [[ "$default_name" != "$outdir" ]]
then
	count=1
	if [[ -d "$default_name" ]]
	then
		if [[ ! -h "$default_name" ]]
		then
			# if 'default' assembly directory already exists, then rename it.
			# rename it to name +1 so the assembly doesn't overwrite
			temp="${default_name}-${count}"
			while [[ -d "$temp" ]]
			do
					count=$((count+1))
					temp="${default_name}-${count}"
			done
			echo -e "Since $default_name already exists, $default_name is renamed to $temp as to not overwrite old assemblies.\n" 1>&2
			mv $default_name $temp
		else
			unlink $default_name
		fi
	fi
		if [[ "$default_name" != "$outdir" ]]
		then
			echo -e "$outdir softlinked to $default_name\n" 1>&2
			(cd $(dirname $outdir) && ln -fs $(basename $outdir) $(basename $default_name))
		fi
fi
echo -e "END: $(date)\n" 1>&2
end_sec=$(date '+%s')

$ROOT_DIR/scripts/get-runtime.sh -T $start_sec $end_sec 1>&2
echo 1>&2

if [[ "$email" = true ]]
then
	org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
        echo "$outdir" |  mail -s "Finished expression filtering for $org" $address
        echo "Email alert sent to $address." 1>&2
fi

echo "STATUS: complete." 1>&2
touch $outdir/FILTER.DONE
