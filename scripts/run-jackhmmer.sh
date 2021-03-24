#!/usr/bin/env bash
set -euo pipefail
FULL_PROGRAM=$0
PROGRAM=$(basename $FULL_PROGRAM)
if [[ "$PROGRAM" == "slurm_script" ]]; then
	FULL_PROGRAM=$(scontrol show job $SLURM_JOBID | awk '/Command=/ {print $1}' | awk -F "=" '{print $2}')
	PROGRAM=$(basename ${FULL_PROGRAM})

fi
args="$FULL_PROGRAM $*"
# 0 - table function
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
	# DESCRIPTION
	{
		echo -e "PROGRAM: $PROGRAM\n"
		echo "DESCRIPTION:"
		echo -e "\
		\tRuns jackhmmer from the HMMER package to find AMPs via homology search of protein sequences.\n \
		\tRequires \$ROOT_DIR/amp_seqs/amps.Amphibia.prot.combined.faa or \$ROOT_DIR/amp_seqs/amps.Insecta.prot.combined.faa file.\n \
		\n \
		\tOUTPUT:\n \
		\t-------\n \
		\t  - jackhmmer.nr.faa\n \
		\t  - HOMOLOGY.DONE or HOMOLOGY.FAIL\n \
		\t  - JACKHMMER.DONE or JACKHMMER.FAIL\n \
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
		" | table
		# USAGE
		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-a <address>] [-e <E-value>] [-h] [-s <0 to 1>] [-t <int>] -o <output directory> <input FASTA file>\n \
		" | table

		# OPTIONS
		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail address for alerts\n \
		\t-e <E-value>\tE-value threshold\t(default = 1e-3)\n \
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n \
		\t-s <0 to 1>\tCD-HIT global sequence similarity cut-off\t(default = 1.00)\n \
		\t-t <int>\tnumber of threads\t(default = 8)\n \
		" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com -e 1e-3 -s 0.90 -t 8 -o /path/to/homology/outdir /path/to/translation/rnabloom.transcripts.filtered.transdecoder.faa\n \
		" | table
	} 1>&2

	exit 1
}

# 1.5 - print_line function
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
		echo -e "CALL: $args (wd: $(pwd))\n"
		message="$1"
		echo "ERROR: $message"
		print_line
		get_help
	} 1>&2
}

# 3 - no arguments given
if [[ "$#" -eq 0 ]]; then
	get_help
fi

# default parameters
evalue="1e-5"
threads=8
email=false
similarity=1.00
outdir=""
db=""
# 4 - read options
while getopts :a:d:e:ho:s:t: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	d) db="$(realpath -s $OPTARG)" ;;
	e) evalue="$OPTARG" ;;
	h) get_help ;;
	o)
		outdir="$(realpath $OPTARG)"
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

if [[ ! -v WORKDIR ]]; then
	workdir=$(dirname $outdir)
else
	workdir=$(realpath $WORKDIR)
fi

if [[ ! -v SPECIES ]]; then
	# get species from workdir
	species=$(echo "$workdir" | awk -F "/" '{print $(NF-1)}')
else
	species=$SPECIES
fi
if [[ ! -v CLASS ]]; then
	class=$(echo "$workdir" | awk -F "/" '{print $(NF-2)}')
else
	class=$CLASS
fi

if [[ ! -v ROOT_DIR ]]; then
	print_error "ROOT_DIR is unbound. Please export ROOT_DIR=/path/to/rAMPage/GitHub/directory."
fi

if [[ -z "$db" ]]; then
	db=$ROOT_DIR/amp_seqs/amps.${class^}.prot.combined.faa
fi

if [[ ! -s $db ]]; then
	print_error "Required FASTA databse $db does not exist."
fi

# 7 - remove status files
rm -f $outdir/HOMOLOGY.DONE
rm -f $outdir/HOMOLOGY.FAIL
rm -f $outdir/JACKHMMER.FAIL
rm -f $outdir/JACKHMMER.DONE
rm -f $outdir/SEQUENCES.DONE
rm -f $outdir/SEQEUNCES.FAIL
rm -f $outdir/SEQUENCES_NR.DONE
rm -f $outdir/SEQUENCES_NR.FAIL

# 8 - print env details
logfile="$outdir/jackhmmer.log"

{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n" | tee $logfile

	echo "CALL: $args (wd: $(pwd))"
	echo -e "THREADS: $threads\n"
} 1>&2

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

infile=$(realpath $1)
if [[ ! -v RUN_JACKHMMER ]]; then
	if command -v jackhmmer &>/dev/null; then
		RUN_JACKHMMER=$(command -v jackhmmer)
	else
		print_error "RUN_JACKHMMER is unbound and no 'jackhmmer' found in PATH. Please export RUN_JACKHMMER=/path/to/jackhmmer/executable."
	fi
elif ! command -v $RUN_JACKHMMER &>/dev/null; then
	print_error "Unable to execute $RUN_JACKHMMER."
fi

echo "Running jackhmmer on ${infile}..." | tee -a $logfile 1>&2
echo "PROGRAM: $(command -v $RUN_JACKHMMER)" | tee -a $logfile 1>&2
echo -e "VERSION: $($RUN_JACKHMMER -h | awk '/HMMER/ {print $3, $4, $5}' | tr -d ';')\n" | tee -a $logfile 1>&2
echo "COMMAND: $RUN_JACKHMMER -o $outdir/jackhmmer.out --tblout $outdir/jackhmmer.tbl --cpu $threads --noali --notextw -E $evalue $db $infile &>> $logfile" | tee -a $logfile 1>&2

$RUN_JACKHMMER -o $outdir/jackhmmer.out --tblout $outdir/jackhmmer.tbl --cpu $threads --noali --notextw -E $evalue $db $infile &>>$logfile

if [[ ! -s $outdir/jackhmmer.tbl ]]; then
	echo "ERROR: jackhmmer output file $outdir/jackhmmer.tbl does not exist or is empty." 1>&2
	touch $outdir/JACKHMMER.FAIL
	touch $outdir/HOMOLOGY.FAIL

	if [[ "$email" = true ]]; then
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
		echo "$outdir" | mail -s "${species^}: STAGE 08: HOMOLOGY SEARCH: FAILED" $address
		# echo "$outdir" | mail -s "Failed homology search on $org" $address
		echo "Email alert sent to $address." 1>&2
	fi

	exit 2
fi

echo -e "Finished running jackhmmer on $infile!\n" 1>&2
touch $outdir/JACKHMMER.DONE

if [[ -s $outdir/jackhmmer.tbl ]]; then

	if [[ ! -v RUN_SEQTK ]]; then
		if command -v seqtk &>/dev/null; then
			RUN_SEQTK=$(command -v seqtk)
		else
			print_error "RUN_SEQTK is unbound and not 'seqtk' found in PATH. Please export RUN_SEQTK=/path/to/seqtk/executable."
		fi
	elif ! command -v $RUN_SEQTK &>/dev/null; then
		print_error "Unable to execute $RUN_SEQTK."
	fi

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
			touch $outdir/HOMOLOGY.FAIL
			if [[ "$email" = true ]]; then
				# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
				# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
				echo "$outdir" | mail -s "${species^}: STAGE 08: HOMOLOGY SEARCH: FAILED" $address
				# echo "$outdir" | mail -s "Failed to fetch sequences after homology search on $org" $address
				echo "Email alert sent to $address." 1>&2
			fi
			exit 3
		else
			echo "ERROR: seqtk subseq output file $outdir/jackhmmer.faa is empty." 1>&2
			touch $outdir/SEQUENCES.FAIL
			touch $outdir/HOMOLOGY.FAIL
			if [[ "$email" = true ]]; then
				# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
				# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
				echo "$outdir" | mail -s "${species^}: STAGE 08: HOMOLOGY SEARCH: FAILED" $address
				# echo "$outdir" | mail -s "No sequences remaining after homology search on $org" $address
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
		echo -e "Number of AMPs found (non-redundant): $(printf "%'d" $count)\n" 1>&2
	else
		touch $outdir/SEQUENCES_NR.FAIL
		touch $outdir/HOMOLOGY.FAIL

		if [[ "$email" = true ]]; then
			# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
			# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
			echo "$outdir" | mail -s "${species^}: STAGE 08: HOMOLOGY SEARCH: FAILED" $address
			# echo "$outdir" | mail -s "Failed redundancy removal after homology search on $org" $address
			echo "Email alert sent to $address." 1>&2
		fi

		exit 5
	fi
else
	echo "ERROR: jackhmmer output file $outdir/jackhmmer.tbl is empty." 1>&2
	touch $outdir/JACKHMMER.FAIL
	touch $outdir/HOMOLOGY.FAIL

	if [[ "$email" = true ]]; then
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		# echo "$outdir" | mail -s "Failed homology search on $org" $address
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
		echo "$outdir" | mail -s "${species^}: STAGE 08: HOMOLOGY SEARCH: SUCCESS" $address
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
# echo 1>&2

touch $outdir/HOMOLOGY.DONE
echo -e "STATUS: DONE.\n" 1>&2

echo "Output: $outdir/jackhmmer.nr.faa" 1>&2

if [[ "$email" = true ]]; then
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	# echo "$outdir" | mail -s "Finished homology search on $org" $address
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
	species=$(echo "$species" | sed 's/^./\u&. /')
	# echo "$outdir" | mail -s "${species^}: STAGE 08: HOMOLOGY SEARCH: SUCCESS" $address
	echo "$outdir" | mail -s "${species}: STAGE 08: HOMOLOGY SEARCH: SUCCESS" $address
	echo -e "\nEmail alert sent to ${address}." 1>&2
fi
