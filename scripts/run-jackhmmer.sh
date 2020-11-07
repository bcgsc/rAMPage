#!/bin/bash
set -euo pipefail
PROGRAM=$(basename $0)
function get_help() {
	# DESCRIPTION
	echo "DESCRIPTION:" 1>&2
	echo -e "\
		\tRuns jackhmmer from the HMMER package to find AMPs via homology search of protein sequences.\n \
		\tFor more information: http://eddylab.org/software/hmmer/Userguide.pdf\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2
	# USAGE
	echo "USAGE(S):" 1>&2
	echo -e "\
		\t$PROGRAM [OPTIONS] -i <input directory> -o <output directory>\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	# OPTIONS
	echo "OPTION(S):" 1>&2
	echo -e "\
		\t-a <address>\temail alert\n \
		\t-e <E-value>\tE-value threshold\t(default = 1e-3)\n \
		\t-h\tshow this help menu\n \
		\t-i <directory>\tinput (i.e. annotation) directory\t(required)\n \
		\t-o <directory>\toutput directory\t(required)\n \
		\t-s <0 to 1>\t CD-HIT global sequence similarity cut-off (default = 0.90)\n \
		\t-t <int>\tnumber of threads\t(default = 8)\n \
		" | column -s$'\t' -t 1>&2

	exit 1
}

evalue=1e-5
threads=8
email=false
similarity=0.90
if [[ "$#" -eq 0 ]]
then
	get_help
fi

while getopts :a:e:hi:o:s:t: opt
do
	case $opt in
		a) address="$OPTARG"; email=true;;
		e) evalue="$OPTARG";;
		h) get_help;;
		i) indir="$(realpath $OPTARG)" ;;
		o) outdir="$(realpath $OPTARG)" ;mkdir -p $outdir;;
		s) similarity="$OPTARG";;
		t) threads="$OPTARG" ;;
		\?) echo "ERROR: Invalid option: -$OPTARG" 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2; get_help;;
	esac
done

shift $((OPTIND-1))
workdir=$(realpath $(dirname $outdir))
if [[ -f "$workdir/AMPHIBIA.CLASS" ]]
then
	db=$ROOT_DIR/amp_seqs/amps.Amphibia.prot.combined.faa
elif [[ -f "$workdir/INSECTA.CLASS" ]]
then
	db=$ROOT_DIR/amp_seqs/amps.Insecta.prot.combined.faa
else
	echo "ERROR: No valid class taxon (*.CLASS file) found. This file is generated after running $ROOT_DIR/scripts/setup.sh." 1>&2; printf '%.0s=' $(seq $(tput cols)) 1>&2; echo 1>&2; exit 2;
fi

if [[ -f $outdir/HOMOLOGY.DONE ]]
then
	rm $outdir/HOMOLOGY.DONE
fi

if [[ -f $outdir/SEQUENCES.DONE ]]
then
	rm $outdir/SEQUENCES.DONE
elif [[ -f $outdir/SEQUENCES.FAIL ]]
then
	rm $outdir/SEQEUNCES.FAIL
fi

echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)\n" 1>&2
start_sec=$(date '+%s')
infile="$indir/rnabloom.transcripts.filtered.transdecoder.faa"
logfile="$outdir/jackhmmer.log" 

echo -e "PATH=$PATH\n" | tee $logfile 1>&2
echo "Running jackhmmer on ${infile}..." | tee -a $logfile 1>&2
echo "PROGRAM: $(command -v $RUN_JACKHMMER)" | tee -a $logfile 1>&2
echo -e "VERSION: $($RUN_JACKHMMER -h | awk '/HMMER/ {print $3, $4, $5}' | tr -d ';')\n" | tee -a $logfile 1>&2
echo "COMMAND: $RUN_JACKHMMER -o $outdir/jackhmmer.out --tblout $outdir/jackhmmer.tbl --cpu $threads --noali --notextw -E $evalue $db $infile &>> $logfile" | tee -a $logfile 1>&2

$RUN_JACKHMMER -o $outdir/jackhmmer.out --tblout $outdir/jackhmmer.tbl --cpu $threads --noali --notextw -E $evalue $db $infile &>> $logfile
echo -e "Finished running jackhmmer on $infile!\n" 1>&2
touch $outdir/HOMOLOGY.DONE

if [[ -s $outdir/jackhmmer.tbl ]]
then
	echo "Running seqtk subseq on $outdir/jackhmmer.tbl..." 1>&2
	echo "PROGRAM: $(command -v $RUN_SEQTK)" | tee -a $logfile 1>&2
	seqtk_version=$( $RUN_SEQTK 2>&1 || true )
	echo -e "VERSION: $( echo "$seqtk_version" | awk '/Version:/ {print $NF}')\n" | tee -a $logfile 1>&2
	echo -e "COMMAND: $RUN_SEQTK subseq $infile <(awk '/^#/ {print \$1}' $outdir/jackhmmer.tbl | sort -u) > $outdir/jackhmmer.faa\n" | tee -a $logfile 1>&2
	$RUN_SEQTK subseq $infile <(awk '!/^#/ {print $1}' $outdir/jackhmmer.tbl | sort -u) > $outdir/jackhmmer.faa

	touch $outdir/SEQUENCES.DONE
	count=$(grep -c '^>' $outdir/jackhmmer.faa)
	echo -e "Number of AMPs found (redundant): $(printf "%'d" $count)\n" 1>&2
	
	echo -e "Removing redundant sequences using CD-HIT...\n" 1>&2
	$ROOT_DIR/scripts/run-cdhit.sh -s $similarity -t $threads -o $outdir/jackhmmer.nr.faa $outdir/jackhmmer.faa

	if [[ -s $outdir/jackhmmer.nr.faa ]]
	then
		touch $outdir/SEQUENCES_NR.DONE
		count=$(grep -c '^>' $outdir/jackhmmer.nr.faa)
		echo -e "Number of AMPS found (non-redundant): $(printf "%'d" $count)\n" 1>&2
	else
		touch $outdir/SEQUENCES_NR.FAIL

		if [[ "$email" = true ]]
		then
			org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
			echo "$outdir" | mail -s "Failed redundancy removal after homology search on $org" $address
			echo "Email alert sent to $address." 1>&2
		fi

		exit 2
	fi
else
	echo -e "$outdir/jackhmmer.tbl is empty!\n" 1>&2
	touch $outdir/SEQUENCES.FAIL

	if [[ "$email" = true ]]
	then
		org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		echo "$outdir" | mail -s "Failed homology search on $org" $address
		echo "Email alert sent to $address." 1>&2
	fi
	exit 2
fi

default_name="$(realpath -s $(dirname $outdir)/homology)"
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

if [[ "$email" = true ]]
then
	org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	echo "$outdir" | mail -s "Finished homology search on $org" $address
fi

echo "STATUS: complete." 1>&2
