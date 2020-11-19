#!/bin/bash
set -euo pipefail
PROGRAM=$(basename $0)

# 1 - get_help function
function get_help() {
	# DESCRIPTION
	{
		echo "DESCRIPTION:"
		echo -e "\
		\tRuns jackhmmer from the HMMER package to find AMPs via homology search of protein sequences.\n \
		\n \
		\tOUTPUT:\n \
		\t-------\n \
		\t  - jackhmmer.nr.faa\n \
		\t  - HOMOLOGY.DONE or HOMOLOGY.FAIL\n \
		\t  - SEQUENCES.DONE or SEQUENCES.FAIL\n \
		\t  - SEQUENCES_NR.DONE or SEQUENCES_NR.FAIL\n \
		\n \
		\tEXIT CODES:\n \
		\t-----------\n \
		\t  - 0: successfully completed\n \
		\t  - 1: general error\n \
		\t  - 2: homology search failed\n \
		\t  - 3: sequence fetch failed\n \
		\t  - 4: homology search yielded 0 results\n \
		\t  - 5: sequence redundancy removal failed\n \
		\n \
		\tFor more information: http://eddylab.org/software/hmmer/Userguide.pdf\n \
		" | column -s$'\t' -t -L
		# USAGE
		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] -o <output directory> <input FASTA file>\n \
		" | column -s$'\t' -t -L

		# OPTIONS
		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail alert\n \
		\t-e <E-value>\tE-value threshold\t(default = 1e-3)\n \
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n \
		\t-s <0 to 1>\t CD-HIT global sequence similarity cut-off (default = 0.90)\n \
		\t-t <int>\tnumber of threads\t(default = 8)\n \
		" | column -s$'\t' -t -L
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

# default parameters
evalue=1e-5
threads=8
email=false
similarity=0.90

# 4 - read options
while getopts :a:e:ho:s:t: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	e) evalue="$OPTARG" ;;
	h) get_help ;;
	o)
		outdir="$(realpath $OPTARG)"
		mkdir -p $outdir
		;;
	s) similarity="$OPTARG" ;;
	t) threads="$OPTARG" ;;
	\?)
		print_error "Invalid option: -$OPTARG" 1>&2
		;;
	esac
done

shift $((OPTIND - 1))

# 5 - wrong number arguments
if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 - check input files
if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "input file $(realpath $1) is empty."
fi

workdir=$(realpath $(dirname $outdir))
if [[ -f "$workdir/AMPHIBIA.CLASS" ]]; then
	db=$ROOT_DIR/amp_seqs/amps.Amphibia.prot.combined.faa
elif [[ -f "$workdir/INSECTA.CLASS" ]]; then
	db=$ROOT_DIR/amp_seqs/amps.Insecta.prot.combined.faa
else
	echo "ERROR: No valid class taxon (*.CLASS file) found. This file is generated after running $ROOT_DIR/scripts/setup.sh." 1>&2
	exit 2
fi

# 7 - remove status files
rm -f $outdir/HOMOLOGY.DONE
rm -f $outdir/HOMOLOGY.FAIL
rm -f $outdir/SEQUENCES.DONE
rm -f $outdir/SEQEUNCES.FAIL
rm -f $outdir/SEQUENCES_NR.DONE
rm -f $outdir/SEQUENCES_NR.FAIL

# 8 - print env details
echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)\n" 1>&2
# start_sec=$(date '+%s')

logfile="$outdir/jackhmmer.log"
echo -e "PATH=$PATH\n" | tee $logfile 1>&2

infile=$(realpath $1)

echo "Running jackhmmer on ${infile}..." | tee -a $logfile 1>&2
echo "PROGRAM: $(command -v $RUN_JACKHMMER)" | tee -a $logfile 1>&2
echo -e "VERSION: $($RUN_JACKHMMER -h | awk '/HMMER/ {print $3, $4, $5}' | tr -d ';')\n" | tee -a $logfile 1>&2
echo "COMMAND: $RUN_JACKHMMER -o $outdir/jackhmmer.out --tblout $outdir/jackhmmer.tbl --cpu $threads --noali --notextw -E $evalue $db $infile &>> $logfile" | tee -a $logfile 1>&2

$RUN_JACKHMMER -o $outdir/jackhmmer.out --tblout $outdir/jackhmmer.tbl --cpu $threads --noali --notextw -E $evalue $db $infile &>>$logfile

if [[ ! -s $outdir/jackhmmer.tbl ]]; then
	echo "ERROR: jackhmmer output file $outdir/jackhmmer.tbl does not exist or is empty." 1>&2
	touch $outdir/HOMOLOGY.FAIL

	if [[ "$email" = true ]]; then
		org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		echo "$outdir" | mail -s "Failed homology search on $org" $address
		echo "Email alert sent to $address." 1>&2
	fi

	exit 2
fi

echo -e "Finished running jackhmmer on $infile!\n" 1>&2
touch $outdir/HOMOLOGY.DONE

if [[ -s $outdir/jackhmmer.tbl ]]; then
	echo "Running seqtk subseq on $outdir/jackhmmer.tbl..." 1>&2
	echo "PROGRAM: $(command -v $RUN_SEQTK)" | tee -a $logfile 1>&2
	seqtk_version=$($RUN_SEQTK 2>&1 || true)
	echo -e "VERSION: $(echo "$seqtk_version" | awk '/Version:/ {print $NF}')\n" | tee -a $logfile 1>&2
	echo -e "COMMAND: $RUN_SEQTK subseq $infile <(awk '/^#/ {print \$1}' $outdir/jackhmmer.tbl | sort -u) > $outdir/jackhmmer.faa\n" | tee -a $logfile 1>&2
	$RUN_SEQTK subseq $infile <(awk '!/^#/ {print $1}' $outdir/jackhmmer.tbl | sort -u) >$outdir/jackhmmer.faa
	if [[ ! -s $outdir/jackhmmer.faa ]]; then
		if [[ ! -f $outdir/jackhmmer.faa ]]; then
			echo "ERROR: seqtk subseq output file $outdir/jackhmmer.faa does not exist." 1>&2
			touch $outdir/SEQUENCES.FAIL
			if [[ "$email" = true ]]; then
				org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
				echo "$outdir" | mail -s "Failed to fetch sequences after homology search on $org" $address
				echo "Email alert sent to $address." 1>&2
			fi
			exit 3
		else
			echo "ERROR: seqtk subseq output file $outdir/jackhmmer.faa is empty." 1>&2
			touch $outdir/SEQUENCES.FAIL

			if [[ "$email" = true ]]; then
				org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
				echo "$outdir" | mail -s "No sequences remaining after homology search on $org" $address
				echo "Email alert sent to $address." 1>&2
			fi
			exit 4
		fi

	fi
	touch $outdir/SEQUENCES.DONE
	count=$(grep -c '^>' $outdir/jackhmmer.faa)
	echo -e "Number of AMPs found (redundant): $(printf "%'d" $count)\n" 1>&2

	echo -e "Removing redundant sequences using CD-HIT...\n" 1>&2
	$ROOT_DIR/scripts/run-cdhit.sh -s $similarity -t $threads -o $outdir/jackhmmer.nr.faa $outdir/jackhmmer.faa

	if [[ -s $outdir/jackhmmer.nr.faa ]]; then
		touch $outdir/SEQUENCES_NR.DONE

		count=$(grep -c '^>' $outdir/jackhmmer.nr.faa)
		echo -e "Number of AMPS found (non-redundant): $(printf "%'d" $count)\n" 1>&2
	else
		touch $outdir/SEQUENCES_NR.FAIL

		if [[ "$email" = true ]]; then
			org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
			echo "$outdir" | mail -s "Failed redundancy removal after homology search on $org" $address
			echo "Email alert sent to $address." 1>&2
		fi

		exit 5
	fi
else
	echo "ERROR: jackhmmer output file $outdir/jackhmmer.tbl is empty." 1>&2
	touch $outdir/HOMOLOGY.FAIL

	if [[ "$email" = true ]]; then
		org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		echo "$outdir" | mail -s "Failed homology search on $org" $address
		echo "Email alert sent to $address." 1>&2
	fi

	exit 2
fi

default_name="$(realpath -s $(dirname $outdir)/homology)"
if [[ "$default_name" != "$outdir" ]]; then
	if [[ -d "$default_name" ]]; then
		count=1
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
		fi
	fi
	echo -e "$outdir softlinked to $default_name\n" 1>&2
	(cd $(dirname $outdir) && ln -fs $(basename $outdir) $(basename $default_name))
fi

echo -e "END: $(date)\n" 1>&2
# end_sec=$(date '+%s')
# $ROOT_DIR/scripts/get-runtime.sh -T $start_sec $end_sec 1>&2
# echo 1>&2

if [[ "$email" = true ]]; then
	org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	echo "$outdir" | mail -s "Finished homology search on $org" $address
fi

echo "STATUS: complete." 1>&2
