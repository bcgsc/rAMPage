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
	{
		echo -e "PROGRAM: $PROGRAM\n"
		echo "DESCRIPTION:"
		echo -e "\
		\tUses ProP (and SignalP, if available) to predict prepropeptide cleavage sites, and obtain the mature peptide sequence.\n \
		\n \
		\tOUTPUT:\n \
		\t-------\n \
		\t  - cleaved.mature.len.faa\n \
		\t  - CLEAVE.DONE or CLEAVE.FAIL\n \
		\t  - CLEAVE_LEN.DONE or CLEAVE_LEN.FAIL\n \
		\t  - CLEAVE_LEN_NR.DONE or CLEAVE_LEN_NR.FAIL\n \
		\n \
		\tEXIT CODES:\n \
		\t-----------\n \
		\t  - 0: successfully completed\n \
		\t  - 1: general error\n \
		\t  - 2: cleavage failed\n \
		\t  - 3: length filtering failed\n \
		\t  - 4: redundancy removal failed\n \
		\n \
		\tFor more information on ProP: https://services.healthtech.dtu.dk/service.php?ProP-1.0\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-a <address>] [-c] [-d] [-h] [-s <0 to 1>] -o <output directory> <input FASTA file>\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail address for alerts\n \
		\t-c\tallow consecutive (i.e. adjacent) segments to be recombined\n \
		\t-d\tdebug mode (skips running ProP)\n \
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n \
		\t-s <0 to 1>\tredundancy removal cut-off\t(default = 1.0)\n \
		" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com -c -o /path/to/cleavage/outdir /path/to/homology/jackhmmer.nr.faa\n \
		" | table
	} 1>&2
	exit 1

	#		\tFor more information on CD-HIT: http://weizhongli-lab.org/cd-hit/\n \
	#		\t-s <0 to 1>\tCD-HIT global sequence similarity cut-off\t(default = 0.90)\n \
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
email=false
# similarity=0.90
consecutive=false
outdir=""
similarity=1.0
debug=false
# 4 - read options
while getopts :a:cho:s:d opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	c)
		consecutive=true
		;;
	d)
		debug=true
		;;
	h) get_help ;;
	o)
		outdir="$(realpath $OPTARG)"
		;;
	s) similarity="$OPTARG" ;;
	\?)
		print_error "Invalid option: -$OPTARG" 1>&2
		;;
	esac
done

shift $((OPTIND - 1))

# 5 - wrong number arguments given
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

if (($(echo "$similarity <= 0" | bc -l) || $(echo "$similarity > 1" | bc -l))); then
	print_error "Invalid argument for -r <0 to 1>: $similarity"
fi

# 7 - remove existing status files
rm -f $outdir/CLEAVE.DONE
rm -f $outdir/CLEAVE.FAIL
rm -f $outdir/CLEAVE_LEN.DONE
rm -f $outdir/CLEAVE_LEN.FAIL
rm -f $outdir/CLEAVE_LEN_NR.DONE
rm -f $outdir/CLEAVE_LEN_NR.FAIL

# 8 - print env details
{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo -e "CALL: $args (wd: $(pwd))\n"
} 1>&2

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

infile=$(realpath $1)
tempfile=$outdir/prop.out

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

if [[ ! -v ROOT_DIR ]]; then
	print_error "ROOT_DIR is unbound. Please export ROOT_DIR=/rAMPage/GitHub/directory."
fi

if [[ ! -v RUN_PROP ]]; then
	# if not bound, look for it in PATH
	if command -v prop &>/dev/null; then
		RUN_PROP=$(command -v prop)
	else
		print_error "RUN_PROP is unbound and no 'prop' found in PATH. Please export RUN_PROP=/path/to/ProP/executable."
	fi
elif ! command -v $RUN_PROP &>/dev/null; then
	print_error "Unable to execute $RUN_PROP."
fi

echo "PROGRAM: $(command -v $RUN_PROP)" 1>&2
echo -e "VERSION: 1.0c\n" 1>&2

if [[ ! -v RUN_SIGNALP ]]; then
	if command -v signalp &>/dev/null; then
		RUN_SIGNALP=$(command -v signalp)
	else
		print_error "RUN_SIGNALP is unbound and no 'signalp' found in PATH. Please export RUN_SIGNALP=/path/to/SignalP/executable."
	fi
elif ! command -v $RUN_SIGNALP &>/dev/null; then
	print_error "Unable to execute $RUN_SIGNALP."
fi

echo "PROGRAM: $(command -v $RUN_SIGNALP)" 1>&2
echo -e "VERSION: $($RUN_SIGNALP -v)\n" 1>&2

if [[ "$(grep -c "|" $infile)" -gt 0 ]]; then
	echo -e "NOTE: Pipes detected in sequence headers will be converted to underscores for ProP.\n" 1>&2
	sed -i 's/|/_/g' $infile
fi

# RUN PROP and get output
echo "Predicting cleavage sites..." 1>&2
echo "COMMAND: $RUN_PROP -p -s $infile > $tempfile" 1>&2

if [[ "$debug" = false ]]; then
	$RUN_PROP -p -s $infile >$tempfile
	cp $tempfile $outdir/prop.raw.out
	sed -i 's/ \+$//' $tempfile
	sed -i 's/^[[:space:]]*[0-9]\+[[:space:]]*/Sequence: /' $tempfile
fi
# echo 1>&2
echo -e "Output: $tempfile\n" 1>&2

# Parse the output
# Write each sequence and cleavage site to the F*.txt
echo "Writing ProP results into a separate file for each sequence..." 1>&2
echo -e "COMAMND: awk -v var=\"$outdir\" 'BEGIN{x=\"/dev/null\"}/^Sequence:/{x=var\"/F\"++i\".txt\";}{print > x;}' $tempfile\n" 1>&2
if [[ "$debug" = false ]]; then
	awk -v var="$outdir" 'BEGIN{x="/dev/null"}/^Sequence:/{x=var"/F"++i".txt";}{print > x;}' $tempfile
fi
# exit 0
echo "Converting ProP output to a TSV file..." 1>&2
tsv=$outdir/prop.tsv

if [[ "$debug" = false ]]; then
	echo -e "Sequence\tSignal Peptide\tPropeptide Cleavage" >$tsv
	for i in $outdir/F*.txt; do
		seqname=$(head -n1 $i | awk '{print $NF}')
		signal_site=$(awk '/Signal peptide cleavage site predicted/ {print $NF}' $i)

		if [[ "$signal_site" == "none" ]]; then # || -z "$signal_site" ]] for if -s isn't used for prop
			signal_site=0
		else
			signal_site=$(awk '/Signal peptide cleavage site predicted/ {print $(NF-3)}' $i)
		fi

		prop_sites=$(awk '/\*ProP\*/ {print $2}' $i | tr '\n' ',' | sed 's/,$//')

		if [[ -z "$prop_sites" ]]; then
			prop_sites=0
		fi

		echo -e "$seqname\t$signal_site\t$prop_sites" >>$tsv
		rm $i
	done
fi

# Sambina's cleaving script
echo "Cleaving peptides..." 1>&2
# start_cleave=$(date '+%s')
echo -e "COMMAND: $ROOT_DIR/scripts/cleave-seq.py $infile $tsv $outdir\n" 1>&2
if [[ "$debug" = false ]]; then
	$ROOT_DIR/scripts/cleave-seq.py $infile $tsv $outdir
fi

# DESCRIBE OUTPUT FILES HERE
echo "Output Files:" 1>&2
echo -e "\
- signal_seq.faa: contains all the signal sequences\n\
- adjacent_seq.faa: contains all the recombined peptide sequences that have adjacent cleaved sequences\n\
- mature_cleaved_seq.faa: contains all the cleaved sequences\n\
\t- includes all mature, prop and prepro sequences\n\
- recombined_seq.faa: Contains all the non-adjacent recombined sequences, both two and three cleaved sequences stitched together\n\
\t- includes all mature, pro, and prepro sequences)\n\
" 1>&2

echo "Combining mature_cleaved_seq.faa and recombined_seq.faa into cleaved.mature.faa..." 1>&2
if [[ "$consecutive" = true ]]; then
	cat $outdir/mature_cleaved_seq.faa $outdir/recombined_seq.faa $outdir/adjacent_seq.faa >$outdir/cleaved.mature.faa
else
	cat $outdir/mature_cleaved_seq.faa $outdir/recombined_seq.faa >$outdir/cleaved.mature.faa
fi

outfile=$outdir/cleaved.mature.faa
outfile_len=$outdir/cleaved.mature.len.faa
if [[ ! -s "$outfile" ]]; then
	touch $outdir/CLEAVE.FAIL
	echo "ERROR: Cleaving output file $outfile does not exist or is empty." 1>&2
	if [[ "$email" = true ]]; then
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		# echo "$outdir" | mail -s "Failed cleaving peptides for $org" $address
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
		echo "$outdir" | mail -s "${species^}: STAGE 09: CLEAVAGE: FAILED" $address
		echo "Email alert sent to $address." 1>&2
	fi
	exit 2
fi

touch $outdir/CLEAVE.DONE
echo "PROGRAM: $(command -v $RUN_SEQTK)" 1>&2
seqtk_version=$($RUN_SEQTK 2>&1 || true)
echo -e "VERSION: $(echo "$seqtk_version" | awk '/Version:/ {print $NF}')\n" 1>&2

# keep only sequences that are >=2 and  <=200
echo "Removing sequences with length < 2 or > 200 amino acids..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq $outfile <($RUN_SEQTK comp $outfile | awk '{if(\$2>=2 && \$2<=200) print \$1}') > $outfile_len\n" 1>&2
$RUN_SEQTK subseq $outfile <($RUN_SEQTK comp $outfile | awk '{if($2>=2 && $2<=200) print $1}') >$outfile_len
remove_seqs=$($RUN_SEQTK comp $outfile | awk '{if($2<2 || $2>200) print $1}' | wc -l)
echo -e "Removed $(printf "%'d" $remove_seqs) sequences due to length.\n" 1>&2

if [[ ! -s $outfile_len ]]; then
	touch $outdir/CLEAVE_LEN.FAIL
	echo "ERROR: Length filtering output file $outfile_len does not exist or is empty." 1>&2
	if [[ "$email" = true ]]; then
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
		echo "$outdir" | mail -s "${species^}: STAGE 09: CLEAVAGE: SUCCESS" $address
		# echo "$outdir" | mail -s "Failed filtering out long sequences for $org" $address
		echo "Email alert sent to $address." 1>&2
	fi
	exit 3
else
	touch $outdir/CLEAVE_LEN.DONE
fi

echo "Removing duplicate sequences..." 1>&2
outfile_len_nr=$outdir/cleaved.mature.len.nr.faa
$ROOT_DIR/scripts/run-cdhit.sh -s $similarity -o ${outfile_len_nr} ${outfile_len}

if [[ ! -s ${outfile_len_nr} ]]; then
	touch $outdir/CLEAVE_LEN_NR.FAIL
	echo "ERROR: Redundancy removal output file $outfile_len_nr does not exist or is empty." 1>&2
	if [[ "$email" = true ]]; then
		species=$(echo "$species" | sed 's/^./\u&. /')
		echo "$outdir" | mail -s "${species}: STAGE 09: CLEAVAGE: FAILED" $address
		echo -e "\nEmail alert sent to $address." 1>&2
	fi
	exit 4
else
	touch $outdir/CLEAVE_LEN_NR.DONE
fi

num_len=$(grep -c '^>' $outfile_len || true)
num_nr=$(grep -c '^>' $outfile_len_nr || true)

remove_seqs=$(echo "$num_len - $num_nr" | bc)
echo -e "\nRemoved $(printf "%'d" $remove_seqs) duplicate sequences.\n" 1>&2

echo -e "Number of sequences remaining: $(printf "%'d" $num_nr)\n" 1>&2

# echo -e "Output: $outfile_len_nr\n" 1>&2

default_name="$(realpath -s $(dirname $outdir)/cleavage)"
if [[ "$default_name" != "$outdir" ]]; then
	count=1
	if [[ -d "$default_name" ]]; then
		if [[ ! -L "$default_name" ]]; then
			# if 'default' assembly directory already exists, then rename it.
			# rename it to name +1 so the assembly doesn't overwrite
			temp="${default_name}-${count}"
			while [[ -d "$temp" ]]; do
				count=$((count + 1))
				temp="${default_name}-${count}"
			done
			echo -e "Since $default_name already exists, $default_name is renamed to $temp as to not overwrite old assemblies.\n" 1>&2
			mv $default_name $temp
		else
			unlink $default_name
		fi
	fi
	if [[ "$default_name" != "$outdir" ]]; then
		echo -e "$outdir softlinked to $default_name\n" 1>&2
		(cd $(dirname $outdir) && ln -fs $(basename $outdir) $(basename $default_name))
	fi
fi

echo -e "END: $(date)\n" 1>&2

# echo 1>&2

echo -e "STATUS: DONE.\n" 1>&2

echo "Output: $outfile_len_nr" 1>&2
if [[ "$email" = true ]]; then
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	# echo "$outdir" | mail -s "Finished cleaving peptides for $org" $address
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
	species=$(echo "$species" | sed 's/^./\u&. /')
	# echo "$outdir" | mail -s "${species^}: STAGE 09: CLEAVAGE: SUCCESS" $address
	echo "$outdir" | mail -s "${species}: STAGE 09: CLEAVAGE: SUCCESS" $address
	echo -e "\nEmail alert sent to $address." 1>&2
fi
