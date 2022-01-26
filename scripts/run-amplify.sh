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
		\tPredicts AMP vs. non-AMP from the peptide sequence using AMPlify.\n \
		\n \
		\tOUTPUT:\n \
		\t-------\n \
		\t  - amps.final.faa\n \
		\t  - AMPlify_results.final.tsv\n \
		\n \
		\tEXIT CODES:\n \
		\t-----------\n \
		\t  - 0: successfully completed\n \
		\t  - 1: general errors\n \
		\t  - 2: AMPlify failed\n \
		\n \
		\tFor more information on AMPlify: https://github.com/bcgsc/amplify\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-a <address>] [-c <int>] [-d] [-f] [-h] [-l <int>] [-s <0 to 1>] [-t <int>] -o <output directory> <input FASTA file>\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail address for alerts\n \
		\t-c <int>\tcharge cut-off (multiple accepted for sweeps) [i.e. keep charge(sequences >= int]\t(default = 2)\n \
		\t-d\tdownstream filtering only\t(skips running AMPlify)\n \
		\t-e <str>\texplicitly force final AMPs to be specified cut-offs [overrides -f, -F]\t(e.g. Score:Length:Charge, AMP:Length:Charge, AMP::)\n \
		\t-f\tforce final AMPs to be the least number of non-zero AMPs*\n \
		\t-F\tforce final AMPs to be those passing the most lenient cut-offs [overrides -f]\n \
		\t-h\tshow this help menu\n \
		\t-l <int>\tlength cut-off (multiple accepted for sweeps) [i.e. keep len(sequences) <= int]\t(default = 30)\n \
		\t-o <directory>\toutput directory\t(required)\n \
		\t-s <3.0103 to 80>\tAMPlify score cut-off (multiple accepted for sweeps) [i.e. keep score(sequences) >= dbl]\t(default = 10 or 7)\n \
		\t-t <int>\tnumber of threads\t(default = all)\n
		\t-T\tstop after obtaining AMPlify TSV file\n\
		" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com -c 2 -l 30 -l 50 -s 10 -s 7 -t 8 -o /path/to/amplify/outdir /path/to/cleavage/cleaved.mature.len.rmdup.nr.faa\n \
		\t$PROGRAM -a user@example.com -c 2 -l 30 -l 50 -s 10 -s 7 -e 10:30:2 -t 8 -o /path/to/amplify/outdir /path/to/cleavage/cleaved.mature.len.rmdup.nr.faa\n \
		\t$PROGRAM -a user@example.com -c 2 -l 30 -l 50 -s 10 -s 7 -e AMP:30:2 -t 8 -o /path/to/amplify/outdir /path/to/cleavage/cleaved.mature.len.rmdup.nr.faa\n \
		" | table

		echo "*i.e. if filtering by score >= 10, length <= 30, and charge >= 2 yields zero AMPs, then score >= 10, length <= 50, and charge >= 2 will be used for the next step of the pipeline, etc."
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
confidence=()
length=()
email=false
# threads=8
custom_threads=false
charge=()
outdir=""
debug=false
forced_characterization=false
tsv_file_only=false
all=false
explicit=""
score_amp=false
# 4 - read options
while getopts :a:c:de:fFhl:o:s:t:T opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	F) all=true ;;
	c) charge+=("$OPTARG") ;;
	d) debug=true ;;
	e) explicit="$OPTARG";;
	f) forced_characterization=true ;;
	s) if [[ "$OPTARG" == [Aa][Mm][Pp] ]]; then score_amp=true; else confidence+=("$OPTARG"); fi ;;
	h) get_help ;;
	l) length+=("$OPTARG") ;;
	o)
		outdir=$(realpath $OPTARG)
		;;
	t)
		threads="$OPTARG"
		custom_threads=true
		;;
	T) tsv_file_only=true ;;
	\?)
		print_error "Invalid option: -$OPTARG"
		;;
	esac
done

shift $((OPTIND - 1))

# 5 - wrong arguments given
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

if [[ ! -v CLASS ]]; then
	class=$(echo "$workdir" | awk -F "/" '{print $(NF-2)}')
else
	class=$CLASS
fi

if [[ ! -v SPECIES ]]; then
	# get species from workdir
	# species=$(echo "$workdir" | awk -F "/" '{print $(NF-1)}' | sed 's/^./&./')
	species=$(echo "$workdir" | awk -F "/" '{print $(NF-1)}')
else
	species=$SPECIES
fi

# if force_char is bound then use it instead of -f
if [[ -v FORCE_CHAR ]]; then
	forced_characterization=$FORCE_CHAR
fi

if [[ "$all" = true ]]; then
	forced_characterization=false
fi

if [[ -n "$explicit" ]]; then
	all=false
	forced_characterization=false
fi

# 7 - remove status files
rm -f $outdir/AMPLIFY.DONE

# 8 - print env details
{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"
	echo "CALL: $args (wd: $(pwd))"
	if [[ "$custom_threads" = true ]]; then
		echo
		echo "THREADS: $threads"
	fi
	echo
} 1>&2

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

input=$(realpath $1)

if [[ "$input" != *.faa ]]; then
	ext=${input##*.}
	ln -s $input $(dirname $input)/$(basename $input $ext).faa
fi

if [[ "$custom_threads" = true ]]; then
	export OPENBLAS_NUM_THREADS=$threads
	export OMP_NUM_THREADS=$threads
	export MKL_NUM_THREADS=$threads
	export BLIS_NUM_THREADS=$threads
	export NUMEXPR_NUM_THREADS=$threads
	export VECLIB_MAXIMUM_THREADS=$threads
fi

# Check AMPlify
if [[ ! -v RUN_AMPLIFY ]]; then
	# if not bound, look for it in PATH
	if command -v AMPlify.py &>/dev/null; then
		RUN_AMPLIFY=$(command -v AMPlify.py)
	else
		print_error "RUN_AMPLIFY is unbound and no AMPlify.py found in PATH. Please export RUN_PROP=/path/to/AMPlify.py."
	fi
elif ! command -v $RUN_AMPLIFY &>/dev/null; then
	print_error "Unable to execute $RUN_AMPLIFY."
fi

# set default confidence
# default values are used if no input is given through -s
# if -s AMP is used, then defaults are NOT used
if [[ "${#confidence[@]}" -eq 0  && "$score_amp" = false ]]; then
	no_score_given=true
	if [[ "$class" == [Aa]mphibia ]]; then
		confidence=(10 7 5)
		# corresponds to 0.9, 0.8, 0.7
	else
		confidence=(7 5 4)
		# corresponds to 0.8, 0.7, 0.6
	fi
elif [[ "$score_amp" = true ]]; then
	no_score_given=true
else
	no_score_given=false
fi
# if explicit score is given using -e 6::, then the explicit score is added 
# to default only if -s is NOT used 
# if -s is used, then it is added to those values, and no default sweep done.
# there is no circumstance where it is the ONLY value done in the sweep?
if [[ -n "$explicit" ]]; then
	explicit_score=$(echo "$explicit" | cut -f1 -d:)
	if [[ -n "$explicit_score" ]]; then
		if [[ "$explicit_score" == [Aa][Mm][Pp] ]]; then
			score_amp=true
			no_score_given=true
			# explicit_score=""
		else
			confidence+=("$explicit_score")
			score_amp=false
			no_score_given=false
		fi
	fi
fi

# sort / unique
if [[ "$score_amp" = false ]]; then
	sorted_confidence=($(echo "${confidence[@]}" | tr ' ' '\n' | sort -nu | tr '\n' ' '))

	for i in "${sorted_confidence[@]}"; do
		if (($(echo "$i < 3.0103" | bc -l) || $(echo "$i > 80" | bc -l))); then
			print_error "Invalid argument for -c <3.0103 to 80>: $i"
		fi
	done
fi
if [[ "${#confidence[@]}" -gt 0 ]]; then
	echo "Score thresholds: ${sorted_confidence[*]}" 1>&2
else
	if [[ "$score_amp" = true ]]; then
		echo "Score thresholds: None (prediction == \"AMP\" instead)" 1>&2
	else
		echo "Score thresholds: None" 1>&2
	fi
fi
# default values only used if -l is not used
if [[ "${#length[@]}" -eq 0 ]]; then
	no_length_given=true
	length=(50 30)
else
	no_length_given=false
fi
# if -e :10: is used, then the value is either added to default, or other specified values
# there is no circumstance where it is the only value in the sweep?
if [[ -n "$explicit" ]]; then
	explicit_length=$(echo "$explicit" | cut -f2 -d:)
	if [[ -n "$explicit_length" ]]; then
		length+=("$explicit_length")
		no_length_given=false
	fi
fi
sorted_length=($(echo "${length[@]}" | tr ' ' '\n' | sort -nru | tr '\n' ' '))

if [[ "${#sorted_length[@]}" -gt 0 ]]; then
	echo "Length thresholds: ${sorted_length[*]}" 1>&2
else
	echo "Length thresholds: None" 1>&2
fi
# default used if no input passed through -c
if [[ "${#charge[@]}" -eq 0 ]]; then
	charge=(2 4 6 8)
	no_charge_given=true
else
	no_charge_given=false
fi

# there is no circumstance where it is the only value in the sweep
if [[ -n "$explicit" && "$explicit" != [Aa][Mm][Pp] ]]; then
	explicit_charge=$(echo "$explicit" | cut -f3 -d:)
	if [[ -n "$explicit_charge" ]]; then
		charge+=("$explicit_charge")
		no_charge_given=false
	fi
fi
sorted_charge=($(echo "${charge[@]}" | tr ' ' '\n' | sort -nu | tr '\n' ' '))

if [[ "${#sorted_charge[@]}" -gt 0 ]]; then
	echo "Charge thresholds: ${sorted_charge[*]}" 1>&2
else
	echo "Charge thresholds: None" 1>&2
fi
echo 1>&2
echo "PROGRAM: $(command -v $RUN_AMPLIFY)" 1>&2
echo -e "VERSION: $(command -v $RUN_AMPLIFY | awk -F "/" '{print $(NF-2)}' | cut -f2 -d-)\n" 1>&2
# echo "VERSION: 1.0.0" 1>&2

echo "Checking sequence lengths..." 1>&2
if [[ ! -v RUN_SEQTK ]]; then
	if command -v seqtk &>/dev/null; then
		RUN_SEQTK=$(command -v seqtk)
	else
		print_error "RUN_SEQTK is unbound and no 'seqtk' found in PATH. Please export RUN_SEQTK=/path/to/seqtk/executable."
	fi
elif ! command -v $RUN_SEQTK &>/dev/null; then
	print_error "Unable to execute $RUN_SEQTK."
fi

echo "PROGRAM: $(command -v $RUN_SEQTK)" 1>&2
seqtk_version=$($RUN_SEQTK 2>&1 || true)
echo -e "VERSION: $(echo "$seqtk_version" | awk '/Version:/ {print $NF}')\n" 1>&2
len_seq=$($RUN_SEQTK comp $input | awk '{if($2<2 || $2>200) print $1}' | wc -l)

if [[ "$len_seq" -ne 0 ]]; then
	echo "Removing sequences with length < 2 or > 200 amino acids..." 1>&2
	echo -e "COMMAND: $RUN_SEQTK subseq $input <($RUN_SEQTK comp $input | awk '{if(\$2>=2 && \$2<=200) print \$1}') > ${input/.faa/.len.faa}\n" 1>&2
	$RUN_SEQTK subseq $input <($RUN_SEQTK comp $input | awk '{if($2>=2 && $2<=200) print $1}') >${input/.faa/.len.faa}
	echo -e "Removed $len_seq sequences.\n" 1>&2
	input=${input/.faa/.len.faa}
	echo -e "Output: $input\n" 1>&2
else
	echo -e "Sequences are already between 2 and 200 amino acids long.\n" 1>&2
fi

if [[ $input != *.nr.* ]]; then
	$ROOT_DIR/scripts/run-cdhit.sh -d $input
	input=${input/.faa/.rmdup.nr.faa}
	echo 1>&2
fi

# remove ambiguous bases if there are any

if [[ "$(grep -v '^>' $input | grep -c '.*[BJOUZX]' || true)" -ne 0 ]]; then
	$RUN_SEQTK seq $input | sed '/^>/N; s/\n/\t/' | grep -v $'\t''.*[BJOUZX]' | tr '\t' '\n' >${input/.faa/.unambiguous.faa}
	input=${input/.faa/.unambiguous.faa}
fi

# RUNNING AMPLIFY
# -------------------
if [[ "$debug" = false ]]; then
	model_dir=$(dirname $(dirname $RUN_AMPLIFY))/models
	echo "Classifying sequences as 'AMP' or 'non-AMP' using AMPlify..." 1>&2
	echo -e "COMMAND: $RUN_AMPLIFY --model_dir $model_dir -s $input --out_dir $outdir --out_format tsv --atention on 1> $outdir/amplify.out 2> $outdir/amplify.err || true\n" 1>&2
	$RUN_AMPLIFY --model_dir $model_dir -s $input --out_dir $outdir --out_format tsv --attention on 1>$outdir/amplify.out 2>$outdir/amplify.err || true

	echo "Finished running AMPlify." 1>&2
else
	echo "FILTERING ONLY: Skipping AMPlify..." 1>&2
	# echo "Classifying sequences as 'AMP' or 'non-AMP' using AMPlify..." 1>&2
	# model_dir=$(dirname $(dirname $RUN_AMPLIFY))/models
	# echo -e "COMMAND: $RUN_AMPLIFY --model_dir $model_dir -s $input --out_dir $outdir --out_format txt 1> $outdir/amplify.out 2> $outdir/amplify.err || true\n" 1>&2
	# echo "Finished running AMPlify." 1>&2
fi
# -------------------

# just do a TSV check instead!
file=$(ls -t $outdir/AMPlify_results_*.tsv 2>/dev/null | head -n1 || true)
echo -e "Output: $file\n" 1>&2

if [[ ! -s $file ]]; then
	touch $outdir/AMPLIFY.FAIL
	if [[ "$email" = true ]]; then
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
		echo "$outdir" | mail -s "${species^}: STAGE 10: AMPLIFY: FAILED" $address
		# echo "$outdir" | mail -s "Failed AMPlify run on $org" $address
		echo "Email alert sent to $address." 1>&2
	fi
	echo "ERROR: AMPlify output file $file does not exist or is empty!" 1>&2
	exit 2
fi

# (cd $outdir && ln -fs $(basename $file) AMPlify_results.nr.tsv)
# file=$outdir/AMPlify_results.nr.tsv

# convert TXT to TSV
# if length or charge is added to next version, do not need to calculate it here
# only need to add "Class" variable
if [[ "$debug" = false ]]; then
	if [[ -s $outdir/AMPlify_results.nr.faa ]]; then
		rm $outdir/AMPlify_results.nr.faa
	fi

	echo -e "Adding taxonomic class to AMPlify TSV...\n" 1>&2
		# do NOT change this order or downstream may be affected
	echo -e "Sequence_ID\tSequence\tLength\tScore\tPrediction\tCharge\tAttention\tClass" >$outdir/AMPlify_results.nr.tsv
		# Change order of these according to AMPlify v1.0.3
	while IFS=$'\t' read seq_id sequence length charge raw_score score pred attn; do
		echo ">$seq_id length=$length charge=$charge score=$score prediction=$pred" >>$outdir/AMPlify_results.nr.faa
		echo "$sequence" >>$outdir/AMPlify_results.nr.faa

		# do NOT change this order or downstream may be affected
		echo -e "$seq_id\t$sequence\t$length\t$score\t$pred\t$charge\t$attn\t$class" >>$outdir/AMPlify_results.nr.tsv
	done < <(tail -n +2 $file)
else
	if [[ -s $outdir/AMPlify_results.nr.faa && -s $outdir/AMPlify_results.nr.tsv ]]; then
		# echo -e "Converting the AMPlify TXT output to a TSV file and a FASTA file...\n" 1>&2
		echo -e "FILTERING ONLY: Skipping TSV processing...\n" 1>&2
	else
		if [[ -s $outdir/AMPlify_results.nr.faa ]]; then
			rm $outdir/AMPlify_results.nr.faa
		fi

		echo -e "Adding taxonomic class to AMPlify TSV...\n" 1>&2
		# do NOT change this order or downstream may be affected
		echo -e "Sequence_ID\tSequence\tLength\tScore\tPrediction\tCharge\tAttention\tClass" >$outdir/AMPlify_results.nr.tsv
		# change teh order of these read while loop after AMPlify v1.0.3 comes out
		while IFS=$'\t' read seq_id sequence length charge raw_score score pred attn; do
			echo ">$seq_id length=$length charge=$charge score=$score prediction=$pred" >>$outdir/AMPlify_results.nr.faa
			echo "$sequence" >>$outdir/AMPlify_results.nr.faa

			# do NOT change this order or downstream may be affected
			echo -e "$seq_id\t$sequence\t$length\t$score\t$pred\t$charge\t$attn\t$class" >>$outdir/AMPlify_results.nr.tsv
			done < <(tail -n +2 $file)
	fi
fi

header=$(head -n1 $outdir/AMPlify_results.nr.tsv)

input_count=$(grep -c '^>' $input || true)

echo "Input sequences: $input" 1>&2
echo -e "Number of input sequences: $(printf "%'d" $input_count)\n" 1>&2

echo "PROGRAM: $(command -v $RUN_SEQTK)" 1>&2
seqtk_version=$($RUN_SEQTK 2>&1 || true)
echo -e "VERSION: $(echo "$seqtk_version" | awk '/Version:/ {print $NF}')\n" 1>&2

### 1 - Filter all sequences for those that are labelled AMP
#----------------------------------------------------------
filter_counter=1
echo "${filter_counter} >>> Filtering for AMP sequences (prediction == \"AMP\")..." 1>&2

amps_fasta=$outdir/amps.nr.faa
amps_tsv=$outdir/AMPlify_results.amps.nr.tsv

all_fastas=($amps_fasta)
all_tsv=($amps_tsv)
echo "$header" >$amps_tsv
echo -e "COMMAND: awk -F \"\\\t\" '{if(\$5==\"AMP\") print}' <(tail -n +2 $outdir/AMPlify_results.nr.tsv) >> $outdir/AMPlify_results.amps.nr.tsv\n" 1>&2
awk -F "\t" '{if($5=="AMP") print}' <(tail -n +2 $outdir/AMPlify_results.nr.tsv) >>$amps_tsv

echo "Converting those sequences to FASTA format..." 1>&2
# 4th field is prediction, and 1st field is sequence ID:
echo -e "COMMAND: $RUN_SEQTK subseq $outdir/AMPlify_results.nr.faa <(awk -F \"\\\t\" '{if(\$5==\"AMP\") print \$1}' <(tail -n +2 $outdir/AMPlify_results.nr.tsv)) > $amps_fasta || true\n" 1>&2
$RUN_SEQTK subseq $outdir/AMPlify_results.nr.faa <(awk -F "\t" '{if($5=="AMP") print $1}' <(tail -n +2 $outdir/AMPlify_results.nr.tsv)) >$amps_fasta || true

echo "SUMMARY" 1>&2
print_line

count=$(grep -c '^>' $amps_fasta || true)

{
	echo "Output: $amps_fasta"
	echo "Number of unique AMPs: $(printf "%'d" $count)"
} | sed 's/^/\t/' 1>&2

print_line
echo 1>&2
#----------------------------------------------------------
if [[ $tsv_file_only == true ]]; then

	echo -e "END: $(date)\n" 1>&2
	echo -e "STATUS: DONE.\n" 1>&2
	touch $outdir/AMPLIFY.DONE

	echo "Output: $amps_tsv" 1>&2
	if [[ "$email" = true ]]; then
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
		species=$(echo "$species" | sed 's/^./\u&. /')
		#	echo "$outdir" | mail -s "${species^}: STAGE 10: AMPLIFY: SUCCESS" $address
		echo "$outdir" | mail -s "${species}: STAGE 10: AMPLIFY: SUCCESS" $address
		# echo "$outdir" | mail -s "Successful AMPlify run on $org" $address
		echo -e "\nEmail alert sent to $address." 1>&2
	fi
	exit 0
fi

#----------------------------------------------------------
if [[ "$score_amp" = false ]]; then
	((filter_counter += 1))
	mkdir -p $outdir/sweep/score
	# Go through sorted confidence loop
	for score in "${sorted_confidence[@]}"; do
		loop_tsv=$outdir/sweep/score/AMPlify_results.amps.score_${score}.nr.tsv
		loop_fasta=$outdir/sweep/score/amps.score_${score}.nr.faa
		all_fastas+=($loop_fasta)
		all_tsv+=($loop_tsv)
		### 2 - Filter all sequences for those with AMPlify score >= $confidence
		#--------------------------------------------------------------------
		echo "${filter_counter} >>> Filtering for AMP sequences (prediction == \"AMP\") with an AMPlify score >= $score..." 1>&2
		echo "$header" >$loop_tsv
		echo -e "COMMAND: awk -F \"\\\t\" -v var=$score '{if(\$4>=var) print}' <(tail -n +2 $amps_tsv) >> $loop_tsv\n" 1>&2
		awk -F "\t" -v var=$score '{if($4>=var) print}' <(tail -n +2 $amps_tsv) >>$loop_tsv

		echo "Converting those sequences to FASTA format..." 1>&2
		echo -e "COMMAND: $RUN_SEQTK subseq $amps_fasta <(awk -F \"\\\t\" -v var=$score '{if(\$4>=var) print \$1}' <(tail -n +2 $amps_tsv)) > ${loop_fasta}\n" 1>&2
		$RUN_SEQTK subseq $amps_fasta <(awk -F "\t" -v var=$score '{if($4>=var) print $1}' <(tail -n +2 $amps_tsv)) >${loop_fasta}
		# 	(
		# 		cd $outdir &&
		# 			ln -fs $(basename $outfile_conf_nr) $outfile_conf_nr_ln &&
		# 			ln -fs $(basename $outfile_conf_nr_tsv) $outfile_conf_nr_tsv_ln
		# 	)

		echo "SUMMARY" 1>&2
		print_line

		count_conf=$(grep -c '^>' ${loop_fasta} || true)

		{
			echo "Output: ${loop_fasta}"
			echo "Number of unique predicted AMPs (score >= $score): $(printf "%'d" ${count_conf})"
		} | sed 's/^/\t/' 1>&2

		print_line
		echo 1>&2
		#--------------------------------------------------------------------
	done
fi

mkdir -p $outdir/sweep/length
for len in "${sorted_length[@]}"; do
	((filter_counter += 1))
	loop_fasta=$outdir/sweep/length/amps.length_${len}.nr.faa
	loop_tsv=$outdir/sweep/length/AMPlify_results.amps.length_${len}.nr.tsv
	all_fastas+=($loop_fasta)
	all_tsv+=($loop_tsv)
	### 3 - Filter all sequences for those labelled 'AMP' and length <= $length
	#--------------------------------------------------------------------
	echo "${filter_counter} >>> Filtering for AMP sequences (prediction == \"AMP\") and with length <= $len..." 1>&2
	echo "$header" >$loop_tsv
	echo -e "COMMAND: awk -F \"\\\t\" -v var=$len '{if(\$3<=var) print }' <(tail -n +2 $amps_tsv) >> $loop_tsv\n" 1>&2
	awk -F "\t" -v var=$len '{if($3<=var) print }' <(tail -n +2 $amps_tsv) >>$loop_tsv

	echo "Converting those sequences into FASTA format..." 1>&2
	echo -e "COMMAND: $RUN_SEQTK subseq $amps_fasta <(awk -F \"\\\t\" -v var=$len '{if(\$3<=var) print \$1}' <(tail -n +2 $amps_tsv)) > ${loop_fasta}\n" 1>&2
	$RUN_SEQTK subseq ${amps_fasta} <(awk -F "\t" -v var=$len '{if($3<=var) print $1}' <(tail -n +2 $amps_tsv)) >${loop_fasta}

	# 	(
	# 		cd $outdir &&
	# 			ln -fs $(basename $outfile_short_nr) $outfile_short_nr_ln &&
	# 			ln -fs $(basename $outfile_short_nr_tsv) $outfile_short_nr_tsv_ln
	# 	)

	echo "SUMMARY" 1>&2
	print_line

	count_short=$(grep -c '^>' ${loop_fasta} || true)

	{
		echo "Output: ${loop_fasta}"
		echo "Number of unique predicted AMPs (length <= $len): $(printf "%'d" ${count_short})"
	} | sed 's/^/\t/' 1>&2

	print_line
	echo 1>&2
done
mkdir -p $outdir/sweep/charge
for net in "${sorted_charge[@]}"; do
	((filter_counter += 1))
	loop_fasta=$outdir/sweep/charge/amps.charge_${net}.nr.faa
	loop_tsv=$outdir/sweep/charge/AMPlify_results.amps.charge_${net}.nr.tsv
	all_fastas+=($loop_fasta)
	all_tsv+=($loop_tsv)
	### 4 - Filter all sequences labelled 'AMP' and have charge >= $charge
	#--------------------------------------------------------------------
	echo "${filter_counter} >>> Filtering for AMP sequences (prediction == \"AMP\") and with charge >= ${net}..." 1>&2
	echo "$header" >$loop_tsv
	echo -e "COMMAND: awk -F \"\\\t\" -v var=$net '{if(\$6>=var) print }' <(tail -n +2 $amps_tsv) >> $loop_tsv\n" 1>&2
	awk -F "\t" -v var=$net '{if($6>=var) print }' <(tail -n +2 $amps_tsv) >>$loop_tsv

	echo "Converting those sequences into FASTA format..." 1>&2
	echo -e "COMMAND: $RUN_SEQTK subseq ${amps_fasta} <(awk -F \"\\\t\" -v var=$net '{if(\$6>=var) print \$1}' <(tail -n +2 $amps_tsv)) > $loop_fasta\n" 1>&2
	$RUN_SEQTK subseq ${amps_fasta} <(awk -F "\t" -v var=$net '{if($6>=var) print $1}' <(tail -n +2 $amps_tsv)) >$loop_fasta

	# (
	# 	cd $outdir &&
	# 		ln -fs $(basename $outfile_charge_nr) $outfile_charge_nr_ln &&
	# 		ln -fs $(basename $outfile_charge_nr_tsv) $outfile_charge_nr_tsv_ln
	# )

	echo "SUMMARY" 1>&2
	print_line

	count_charge=$(grep -c '^>' ${loop_fasta} || true)

	{
		echo "Output: ${loop_fasta}"
		echo "Number of unique predicted AMPs (charge >= $net): $(printf "%'d" ${count_charge})"
	} | sed 's/^/\t/' 1>&2

	print_line
	echo 1>&2
	#--------------------------------------------------------------------
done

if [[ "$score_amp" = false ]]; then
	mkdir -p $outdir/sweep/score_charge
	for score in "${sorted_confidence[@]}"; do
		for net in "${sorted_charge[@]}"; do
			loop_fasta=$outdir/sweep/score_charge/amps.score_${score}-charge_${net}.nr.faa
			loop_tsv=$outdir/sweep/score_charge/AMPlify_results.amps.score_${score}-charge_${net}.nr.tsv
			all_fastas+=($loop_fasta)
			all_tsv+=($loop_tsv)
			((filter_counter += 1))
			### 5 - Filter all sequences for those AMPlify score >= $confidence and have charge >= $charge
			#--------------------------------------------------------------------
			echo "${filter_counter} >>> Filtering for AMP sequences (prediction == \"AMP\") with AMPlify score >= ${score} and with charge >= ${net}..." 1>&2
			echo "$header" >$loop_tsv
			echo -e "COMMAND: awk -F \"\\\t\" -v var=$net -v c=$score '{if(\$6>=var && \$4>=c) print }' <(tail -n +2 $amps_tsv) >> $loop_tsv\n" 1>&2
			awk -F "\t" -v var=$net -v c=$score '{if($6>=var && $4>=c) print }' <(tail -n +2 $amps_tsv) >>$loop_tsv

			echo "Converting those sequences into FASTA format..." 1>&2
			echo -e "COMMAND: $RUN_SEQTK subseq ${amps_fasta} <(awk -F \"\\\t\" -v var=$net -v c=$score '{if(\$6>=var && \$4>=c) print \$1}' <(tail -n +2 $amps_tsv)) > $loop_fasta\n" 1>&2
			$RUN_SEQTK subseq ${amps_fasta} <(awk -F "\t" -v var=$net -v c=$score '{if($6>=var && $4>=c) print $1}' <(tail -n +2 $amps_tsv)) >${loop_fasta}

			# (
			# 	cd $outdir &&
			# 		ln -fs $(basename $outfile_conf_charge_nr) $outfile_conf_charge_nr_ln &&
			# 		ln -fs $(basename $outfile_conf_charge_nr_tsv) $outfile_conf_charge_nr_tsv_ln
			# )

			echo "SUMMARY" 1>&2
			print_line

			count_conf_charge=$(grep -c '^>' ${loop_fasta} || true)

			{
				echo "Output: ${loop_fasta}"
				echo "Number of unique predicted AMPs (score >= $score, charge >= ${net}): $(printf "%'d" ${count_conf_charge})"
			} | sed 's/^/\t/' 1>&2

			print_line
			echo 1>&2
			#--------------------------------------------------------------------
		done
	done
fi

if [[ "$score_amp" = false ]]; then
	mkdir -p $outdir/sweep/score_length
	for score in "${sorted_confidence[@]}"; do
		for len in "${sorted_length[@]}"; do
			((filter_counter += 1))
			loop_fasta=$outdir/sweep/score_length/amps.score_${score}-length_${len}.nr.faa
			loop_tsv=$outdir/sweep/score_length/AMPlify_results.amps.score_${score}-length_${len}.nr.tsv
			all_fastas+=($loop_fasta)
			all_tsv+=($loop_tsv)
			#--------------------------------------------------------------------
			### 6 - Filter all sequences for those with AMPlify score >= $confidence and length <= $length
			#--------------------------------------------------------------------
			echo "${filter_counter} >>> Filtering for AMP sequences (prediction == \"AMP\") with AMPlify score >= ${score} and length <= $len..." 1>&2
			echo "$header" >$loop_tsv
			echo -e "COMMAND: awk -F \"\\\t\" -v l=$len -v c=$score '{if(\$3<=l && \$4>=c) print}' <(tail -n +2 $amps_tsv) >> $loop_tsv\n" 1>&2
			awk -F "\t" -v l=$len -v c=$score '{if($3<=l && $4>=c) print}' <(tail -n +2 $amps_tsv) >>$loop_tsv

			echo "Converting those sequences to FASTA format..." 1>&2
			echo -e "COMMAND: $RUN_SEQTK subseq ${amps_fasta} <(awk -F \"\\\t\" -v l=$len -v c=$score '{if(\$3<=l && \$4>=c) print \$1}' <(tail -n +2 $amps_tsv)) > ${loop_fasta}\n" 1>&2
			$RUN_SEQTK subseq ${amps_fasta} <(awk -F "\t" -v l=$len -v c=$score '{if($3<=l && $4>=c) print $1}' <(tail -n +2 $amps_tsv)) >${loop_fasta}

			# (
			# 	cd $outdir &&
			# 		ln -fs $(basename $outfile_conf_short_nr) $outfile_conf_short_nr_ln &&
			# 		ln -fs $(basename $outfile_conf_short_nr_tsv) $outfile_conf_short_nr_tsv_ln
			# )

			echo "SUMMARY" 1>&2
			print_line

			count_conf_short=$(grep -c '^>' ${loop_fasta} || true)

			{
				echo "Output: ${loop_fasta}"
				echo "Number of unique predicted AMPs (score >= $score, length <= $len): $(printf "%'d" ${count_conf_short})"
			} | sed 's/^/\t/' 1>&2

			print_line
			echo 1>&2
			#--------------------------------------------------------------------
		done
	done
fi

mkdir -p $outdir/sweep/length_charge
for len in "${sorted_length[@]}"; do
	for net in "${sorted_charge[@]}"; do
		loop_fasta=$outdir/sweep/length_charge/amps.length_${len}-charge_${net}.nr.faa
		loop_tsv=$outdir/sweep/length_charge/AMPlify_results.amps.length_${len}-charge_${net}.nr.tsv
		all_fastas+=($loop_fasta)
		all_tsv+=($loop_tsv)
		((filter_counter += 1))
		#--------------------------------------------------------------------
		### 7 - Filter all sequences for those with charge >= $charge and length <= $length
		#--------------------------------------------------------------------
		echo "${filter_counter} >>> Filtering for AMP sequences (prediction == \"AMP\") with length <= $len and charge >= ${net}..." 1>&2
		echo "$header" >$loop_tsv
		echo -e "COMMAND: awk -F \"\\\t\" -v l=$len -v c=$net '{if(\$3<=l && \$6>=c) print}' <(tail -n +2 $amps_tsv) >> $loop_tsv\n" 1>&2
		awk -F "\t" -v l=$len -v c=$net '{if($3<=l && $6>=c) print}' <(tail -n +2 $amps_tsv) >>$loop_tsv

		echo "Converting those sequences to FASTA format..." 1>&2
		echo -e "COMMAND: $RUN_SEQTK subseq ${amps_fasta} <(awk -F \"\\\t\" -v l=$len -v c=$net '{if(\$3<=l && \$6>=c) print \$1}' <(tail -n +2 $amps_tsv)) > ${loop_fasta}\n" 1>&2
		$RUN_SEQTK subseq ${amps_fasta} <(awk -F "\t" -v l=$len -v c=$net '{if($3<=l && $6>=c) print $1}' <(tail -n +2 $amps_tsv)) >${loop_fasta}

		# (
		# 	cd $outdir &&
		# 		ln -fs $(basename $outfile_short_charge_nr) $outfile_short_charge_nr_ln &&
		# 		ln -fs $(basename $outfile_short_charge_nr_tsv) $outfile_short_charge_nr_tsv_ln
		# )

		echo "SUMMARY" 1>&2
		print_line

		count_short_charge=$(grep -c '^>' ${loop_fasta} || true)

		{
			echo "Output: ${loop_fasta}"
			echo "Number of unique predicted AMPs (length <= $len, charge >= $net): $(printf "%'d" ${count_short_charge})"
		} | sed 's/^/\t/' 1>&2

		print_line
		echo 1>&2
		#--------------------------------------------------------------------
	done
done

if [[ "$score_amp" = false ]]; then
	mkdir -p $outdir/sweep/score_length_charge
	for score in "${sorted_confidence[@]}"; do
		for len in "${sorted_length[@]}"; do
			for net in "${sorted_charge[@]}"; do
				loop_fasta=$outdir/sweep/score_length_charge/amps.score_${score}-length_${len}-charge_${net}.nr.faa
				loop_tsv=$outdir/sweep/score_length_charge/AMPlify_results.amps.score_${score}-length_${len}-charge_${net}.nr.tsv
				all_fastas+=($loop_fasta)
				all_tsv+=($loop_tsv)
				((filter_counter += 1))
				### 9 - Filter short and confident sequences for those with AMPlify score >= $confidence and length <= $length, and charge >= $charge
				#--------------------------------------------------------------------
				echo "${filter_counter} >>> Filtering for AMP sequences (prediction == \"AMP\") with AMPlify score >= ${score}, length <= $len, and charge >= $net..." 1>&2

				echo "$header" >$loop_tsv
				echo -e "COMMAND: awk -F \"\\\t\" -v l=$len -v c=$score -v p=$net '{if(\$3<=l && \$4>=c && \$6>=p) print}' <(tail -n +2 $amps_tsv) >> $loop_tsv\n" 1>&2
				awk -F "\t" -v l=$len -v c=$score -v p=$net '{if($3<=l && $4>=c && $6>=p) print}' <(tail -n +2 $amps_tsv) >>$loop_tsv

				echo "Converting those sequences to FASTA format..." 1>&2
				echo -e "COMMAND: $RUN_SEQTK subseq ${amps_fasta} <(awk -F \"\\\t\" -v l=$len -v c=$score -v p=$net '{if(\$3<=l && \$4>=c && \$6>=p) print \$1}' <(tail -n +2 $amps_tsv)) > ${loop_fasta}\n" 1>&2
				$RUN_SEQTK subseq ${amps_fasta} <(awk -F "\t" -v l=$len -v c=$score -v p=$net '{if($3<=l && $4>=c && $6>=p) print $1}' <(tail -n +2 $amps_tsv)) >${loop_fasta}

				# (
				# cd $outdir &&
				# ln -fs $(basename $outfile_conf_short_charge_nr) $outfile_conf_short_charge_nr_ln &&
				# ln -fs $(basename $outfile_conf_short_charge_nr_tsv) $outfile_conf_short_charge_nr_tsv_ln &&
				# ln -fs $outfile_conf_short_charge_nr_ln amps.conf.short.charge.nr.faa &&
				# ln -fs $outfile_conf_short_charge_nr_tsv_ln AMPlify_results.conf.short.charge.nr.tsv
				# )

				echo "SUMMARY" 1>&2
				print_line

				count_conf_short_charge=$(grep -c '^>' ${loop_fasta} || true)

				{
					echo "Output: ${loop_fasta}"
					echo "Number of unique AMPs (score >= $score, length <= $len, charge >= $net): $(printf "%'d" ${count_conf_short_charge})"
				} | sed 's/^/\t/' 1>&2

				print_line
				echo 1>&2
				#--------------------------------------------------------------------

			done
		done
	done
fi

most_filtered_fasta=$loop_fasta
most_filtered_tsv=$loop_tsv

# echo $outdir/*.faa
# sed --follow-symlinks -i '/^$/d' $outdir/*.faa

# rewrite final summary using all_tsv and all_fastas and their counts!! trying in ptoftae amplify-new
echo "FINAL SUMMARY" 1>&2
print_line

{
	echo -e "File\tDescription"
	echo -e "--------\t-----------"
	echo -e "$(basename $file)\traw AMPlify results in TSV format"
	echo -e "AMPlify_results.nr.tsv\tprocessed AMPlify results in TSV format"
	echo -e "AMPlify_results.nr.faa\tprocessed AMPlify results in FASTA format"

	for i in "${!all_tsv[@]}"; do
		tsv=${all_tsv[$i]}
		if [[ "$score_amp" = false ]]; then
			score=$(echo "$tsv" | grep -o 'score_[0-9]\+\.\?[0-9]*' | cut -f2 -d_ | sed 's/\.$//' || true)
		else
			score=""
		fi	
		length=$(echo "$tsv" | grep -o 'length_[0-9]\+' | cut -f2 -d_ || true)
		charge=$(echo "$tsv" | grep -o 'charge_[0-9]\+' | cut -f2 -d_ || true)

		if [[ -n "$score" && -n "$length" && -n "$charge" ]]; then
			desc="AMPlify results with score >= ${score}, length <= ${length}, and charge >= ${charge}"
		elif [[ -n "$score" && -n "$length" ]]; then
			desc="AMPlify results with score >= ${score} and length <= ${length}"
		elif [[ -n "$score" && -n "$charge" ]]; then
			desc="AMPlify results with score >= ${score} and charge >= ${charge}"
		elif [[ -n "$length" && -n "$charge" ]]; then
			desc="AMPlify results with length <= ${length} and charge >= ${charge}"
		elif [[ -n "$score" ]]; then
			desc="AMPlify results with score >= ${score}"
		elif [[ -n "$length" ]]; then
			desc="AMPlify results with length <= ${length}"
		elif [[ -n "$charge" ]]; then
			desc="AMPlify results with charge >= ${charge}"
		else
			desc="AMPlify results with labelled AMPs (prediction == \"AMP\")"
		fi

		echo -e "$(basename $tsv)\t$desc"
	done
} | table | tee $outdir/README 1>&2
# table <$outdir/README 1>&2
echo >>$outdir/README
echo 1>&2
{
	echo -e "TSV File\tFASTA File\tAMP Count"
	echo -e "--------\t----------\t---------"

	for i in "${!all_fastas[@]}"; do
		tsv=${all_tsv[$i]}
		fasta=${all_fastas[$i]}
		echo -e "$(basename $tsv)\t$(basename $fasta)\t$(grep -c '^>' $fasta || true)"
	done | sed 's/^\s\+//g' | sed '/^$/d' | grep -v "NA" >>$outdir/amps.summary.tsv
} >$outdir/amps.summary.tsv

table <$outdir/amps.summary.tsv | tee -a $outdir/README 1>&2
sed -i '/^-\+\t-\+/d' $outdir/amps.summary.tsv

# exit 0
# {
# 	echo -e "\
# 	File (nr = non-redundant)\tDescription\n \
# 	-------------------------\t-----------\n \
# 	AMPlify_results.nr.txt\traw AMPlify results\n \
# 	AMPlify_results.nr.tsv\traw AMPlify results parsed into a TSV\n \
# 	AMPlify_results.nr.faa\tsequences of raw AMPlify results with new headers\n \
# 	$(basename $outfile_nr)\tnr sequences in AMPlify results labelled 'AMP'\n \
# 	$outfile_conf_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= $confidence\n \
# 	$outfile_charge_nr_ln\tnr sequences labelled 'AMP' with charge >= $charge\n \
# 	$outfile_short_nr_ln\tnr sequences labelled 'AMP' with length <= $length\n \
# 	$outfile_conf_charge_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= $confidence and charge >= $charge\n \
# 	$outfile_conf_short_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= $confidence and length <= $length\n \
# 	$outfile_short_charge_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with length <= $length and charge >= $charge\n \
# 	$outfile_short_charge_lower_lower_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= ${confidence_lower_lower}, length <= $length, and charge >= $charge\n \
# 	$outfile_short_charge_lower_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= ${confidence_lower}, length <= $length, and charge >= $charge\n \
# 	$outfile_conf_short_charge_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= $confidence, length <= $length, and charge >= $charge\n \
# 	"
#
# 	echo -e "\
# 		FASTA\tTSV\n \
# 		-----\t---\n \
# 		AMPlify_results.nr.faa\tAMPlify_results.nr.tsv\n \
# 		$outfile_nr\tAMPlify_results.amps.nr.tsv\n \
# 		$outfile_conf_nr_ln\tAMPlify_results.conf.nr.tsv\n \
# 		$outfile_charge_nr_ln\tAMPlify_results.charge.nr.tsv\n \
# 		$outfile_short_nr_ln\tAMPlify_results.short.nr.tsv\n \
# 		$outfile_conf_charge_nr_ln\tAMPlify_results.conf.charge.nr.tsv\n \
# 		$outfile_conf_short_nr_ln\tAMPlify_results.conf.short.nr.tsv\n \
# 		$outfile_short_charge_nr_ln\tAMPlify_results.short.charge.nr.tsv\n \
# 		$outfile_short_charge_lower_lower_nr_ln\tAMPlify_results.conf_${confidence_lower_lower}.short.charge.nr.tsv\n \
# 		$outfile_short_charge_lower_nr_ln\tAMPlify_results.conf_${confidence_lower}.short.charge.nr.tsv\n \
# 		$outfile_conf_short_charge_nr_ln\tAMPlify_results.conf.short.charge.nr.tsv\n \
# 	"
# } | sed 's/^\s\+//g' | sed '/^$/d' | table >$outdir/README

# {
# 	echo -e "\
# 		File (nr = non-redundant)\tDescription\n \
# 		-------------------------\t-----------\n \
# 		AMPlify_results.nr.txt\traw AMPlify results\n \
# 		AMPlify_results.nr.tsv\traw AMPlify results parsed into a TSV\n \
# 		AMPlify_results.nr.faa\tsequences of raw AMPlify results with new headers\n \
# 		$(basename $outfile_nr)\tnr sequences in AMPlify results labelled 'AMP'\n \
# 		$outfile_conf_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= $confidence\n \
# 		$outfile_charge_nr_ln\tnr sequences labelled 'AMP' with charge >= $charge\n \
# 		$outfile_short_nr_ln\tnr sequences labelled 'AMP' with length <= $length\n \
# 		$outfile_conf_charge_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= $confidence and charge >= $charge\n \
# 		$outfile_conf_short_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= $confidence and length <= $length\n \
# 		$outfile_short_charge_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with length <= $length and charge >= $charge\n \
# 		$outfile_short_charge_lower_lower_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= ${confidence_lower_lower}, length <= $length, and charge >= $charge\n \
# 		$outfile_short_charge_lower_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= ${confidence_lower}, length <= $length, and charge >= $charge\n \
# 		$outfile_conf_short_charge_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= $confidence, length <= $length, and charge >= $charge\n \
# 		"
# 	echo -e "\
# 		FASTA\tTSV\n \
# 		-----\t---\n \
# 		AMPlify_results.nr.faa\tAMPlify_results.nr.tsv\n \
# 		$outfile_nr\tAMPlify_results.amps.nr.tsv\n \
# 		$outfile_conf_nr_ln\tAMPlify_results.conf.nr.tsv\n \
# 		$outfile_charge_nr_ln\tAMPlify_results.charge.nr.tsv\n \
# 		$outfile_short_nr_ln\tAMPlify_results.short.nr.tsv\n \
# 		$outfile_conf_charge_nr_ln\tAMPlify_results.conf.charge.nr.tsv\n \
# 		$outfile_conf_short_nr_ln\tAMPlify_results.conf.short.nr.tsv\n \
# 		$outfile_short_charge_nr_ln\tAMPlify_results.short.charge.nr.tsv\n \
# 		$outfile_short_charge_lower_lower_nr_ln\tAMPlify_results.conf_${confidence_lower_lower}.short.charge.nr.tsv\n \
# 		$outfile_short_charge_lower_nr_ln\tAMPlify_results.conf_${confidence_lower}.short.charge.nr.tsv\n \
# 		$outfile_conf_short_charge_nr_ln\tAMPlify_results.conf.short.charge.nr.tsv\n \
# 	"
# 	echo -e "\
# 	File (nr = non-redundant)\tAMP Count\n \
# 	-------------------------\t-----------"
# 	cat $outdir/amps.summary.tsv
#
# } | sed 's/^\s\+//g' | table | sed 's/^/\t/' 1>&2
#
# echo 1>&2

# sed -i "s|^|$outdir/|" $outdir/amps.summary.tsv
# soft link the file that has the least number of AMPs but isn't 0
# final_amps=$most_filtered_fasta
least_nonzero_amps=$(find $(basename $outdir) -maxdepth 3 -name "$(awk -F "\t" '{if($3!=0) print $2}' $outdir/amps.summary.tsv | tail -n1)" | cut -f2- -d/)
least_nonzero_amps_tsv=$(find $(basename $outdir) -maxdepth 3 -name "$(awk -F "\t" '{if($3!=0) print $1}' $outdir/amps.summary.tsv | tail -n1)" | cut -f2- -d/)

if [[ "$score_amp" = false ]]; then
	highest_score=${sorted_confidence[-1]}
	lowest_score=${sorted_confidence[0]}
fi

shortest_length=${sorted_length[-1]}
longest_length=${sorted_length[0]}
lowest_charge=${sorted_charge[0]}
highest_charge=${sorted_charge[-1]}

if [[ "$all" = true ]]; then
	echo -e "\n~~~ Final AMPs determined by -F option used: most lenient thresholds ~~~" 1>&2
	if [[ "$no_score_given" = false && "$no_length_given" = false && "$no_charge_given" = false ]]; then
		final_amps=sweep/score_length_charge/amps.score_${lowest_score}-length_${longest_length}-charge_${lowest_charge}.nr.faa
	elif [[ "$no_score_given" = false && "$no_length_given" = false ]]; then
		final_amps=sweep/score_length/amps.score_${lowest_score}-length_${longest_length}.nr.faa
	elif [[ "$no_score_given" = false && "$no_charge_given" = false ]]; then
		final_amps=sweep/score_charge/amps.score_${lowest_score}-score_${lowest_charge}.nr.faa
	elif [[ "$no_length_given" = false && "$no_charge_given" = false ]]; then
		final_amps=sweep/length_charge/amps.length_${longest_length}-charge_${lowest_charge}.nr.faa
	elif [[ "$no_score_given" = false ]]; then
		final_amps=sweep/score/amps.score_${lowest_score}.nr.faa
	elif [[ "$no_length_given" = false ]]; then
		final_amps=sweep/length/amps.length_${longest_length}.nr.faa
	elif [[ "$no_charge_given" = false ]]; then
		final_amps=sweep/charge/amps.charge_${lowest_charge}.nr.faa
	fi
	filename=$(echo "$final_amps" | sed 's|amps|AMPlify_results.\0|' | sed 's|\.faa|.tsv|')
elif [[ -n "$explicit" ]]; then
	echo -e "\n~~~ Final AMPs determined by -e $explicit parameter ~~~" 1>&2
	if [[ -n "$explicit_score" && -n "$explicit_length" && -n "$explicit_charge" ]]; then
		if [[ "$score_amp" = true ]]; then
			final_amps=sweep/length_charge/amps.length_${explicit_length}-charge_${explicit_charge}.nr.faa
			echo "~~~ Score: AMP | Length: $explicit_length | Charge: $explicit_charge ~~~" 1>&2
		else
			final_amps=sweep/score_length_charge/amps.score_${explicit_score}-length_${explicit_length}-charge_${explicit_charge}.nr.faa
			echo "~~~ Score: $explicit_score | Length: $explicit_length | Charge: $explicit_charge ~~~" 1>&2
		fi
	elif [[ -n "$explicit_score" && -n "$explicit_length" ]]; then
		if [[ "$score_amp" = true ]]; then
			final_amps=sweep/length/amps.length_${explicit_length}.nr.faa
			echo "~~~ Score: AMP | Length: $explicit_length ~~~" 1>&2
		else
			final_amps=sweep/score_length/amps.score_${explicit_score}-length_${explicit_length}.nr.faa
			echo "~~~ Score: $explicit_score | Length: $explicit_length ~~~" 1>&2
		fi
	elif [[ -n "$explicit_score" && -n "$explicit_charge" ]]; then
		if [[ "$score_amp" = true ]]; then
			final_amps=sweep/charge/amps.charge_${explicit_charge}.nr.faa
			echo "~~~ Score: AMP | Charge: $explicit_charge ~~~" 1>&2
		else
			final_amps=sweep/score_charge/amps.score_${explicit_score}-charge_${explicit_charge}.nr.faa
			echo "~~~ Score: $explicit_score | Charge: $explicit_charge ~~~" 1>&2
		fi
	elif [[ -n "$explicit_length" && -n "$explicit_charge" ]]; then
		final_amps=sweep/length_charge/amps.length_${explicit_length}-charge_${explicit_charge}.nr.faa
		echo "~~~ Length: $explicit_length | Charge: $explicit_charge ~~~" 1>&2
	elif [[ -n "$explicit_score" ]]; then
		final_amps=sweep/score/amps.score_${explicit_score}.nr.faa
		echo "~~~ Score: $explicit_score ~~~" 1>&2
	elif [[ -n "$explicit_length" ]]; then
		final_amps=sweep/length/amps.length_${explicit_length}.nr.faa
		echo "~~~ Length: $explicit_length ~~~" 1>&2
	elif [[ -n "$explicit_charge" ]]; then
		final_amps=sweep/charge/amps.charge_${explicit_charge}.nr.faa
		echo "~~~ Charge: $explicit_charge ~~~" 1>&2
	else
		final_amps=$(basename $amps_fasta)
		echo "~~~ Prediction: AMP ~~~" 1>&2
	fi
	filename=$(echo "$final_amps" | sed 's|amps|AMPlify_results.\0|' | sed 's|\.faa|.tsv|')
elif [[ "$forced_characterization" = true ]]; then
	echo -e "\n~~~ Final AMPs determined by -f: strictest non-zero AMP filters ~~~" 1>&2
else
	echo -e "\n~~~ Final AMPs determined to be strictest putative AMP filters (default) ~~~" 1>&2
	if [[ "$no_score_given" = false && "$no_length_given" = false && "$no_charge_given" = false ]]; then
		final_amps=sweep/score_length_charge/amps.score_${highest_score}-length_${shortest_length}-charge_${highest_charge}.nr.faa
	elif [[ "$no_score_given" = false && "$no_length_given" = false ]]; then
		final_amps=sweep/score_length/amps.score_${highest_score}-length_${shortest_length}.nr.faa
	elif [[ "$no_score_given" = false && "$no_charge_given" = false ]]; then
		final_amps=sweep/score_charge/amps.score_${highest_score}-score_${highest_charge}.nr.faa
	elif [[ "$no_length_given" = false && "$no_charge_given" = false ]]; then
		final_amps=sweep/length_charge/amps.length_${shortest_length}-charge_${highest_charge}.nr.faa
	elif [[ "$no_score_given" = false ]]; then
		final_amps=sweep/score/amps.score_${highest_score}.nr.faa
	elif [[ "$no_length_given" = false ]]; then
		final_amps=sweep/length/amps.length_${shortest_length}.nr.faa
	elif [[ "$no_charge_given" = false ]]; then
		final_amps=sweep/charge/amps.charge_${highest_charge}.nr.faa
	fi
	filename=$(echo "$final_amps" | sed 's|amps|AMPlify_results.\0|' | sed 's|\.faa|.tsv|')
fi

# filename=$most_filtered_tsv

if [[ $forced_characterization = false ]]; then
	(cd $outdir && ln -fs ${final_amps} amps.final.faa && ln -fs ${filename} AMPlify_results.final.tsv)
else
	(cd $outdir && ln -fs $least_nonzero_amps amps.final.faa && ln -fs $least_nonzero_amps_tsv AMPlify_results.final.tsv)
fi

final_count=$(grep -c '^>' $outdir/amps.final.faa || true)
echo -e "\nSYMLINKS:" 1>&2
cd $outdir && ls -l amps.final.faa AMPlify_results.final.tsv | awk '{print $(NF-2), $(NF-1), $NF}' | column -s $' ' -t 1>&2

echo 1>&2
# echo "---> $outdir/${filename} softlinked to $outdir/amps.final.faa" 1>&2
# echo -e "---> $outdir/${final_amps} softlinked to $outdir/AMPlify_results.final.tsv\n" 1>&2
{
	echo
	echo -e "Link\tTarget"
	echo -e "----\t------"
	ls -l $outdir | awk 'BEGIN{OFS="\t"} /^l/ {print $(NF-2), $(NF)}'
} | table >>$outdir/README

echo "Number of Final AMPs: $(printf "%'d" $final_count)" 1>&2
echo 1>&2
print_line
echo 1>&2

# default_name="$(realpath -s $(dirname $outdir)/amplify)"
# if [[ "$default_name" != "$outdir" ]]; then
# 	if [[ -d "$default_name" ]]; then
# 		count=1
# 		if [[ ! -L "$default_name" ]]; then
# 			temp="${default_name}-${count}"
# 			while [[ -d "$temp" ]]; do
# 				count=$((count + 1))
# 				temp="${default_name}-${count}"
# 			done
# 			echo -e "Since $default_name already exists, $default_name is renamed to $temp as to not overwrite old files.\n" 1>&2
# 			mv $default_name $temp
# 		else
# 			unlink $default_name
# 		fi
# 	fi
# 	echo -e "$outdir softlinked to $default_name\n" 1>&2
# 	(cd $(dirname $outdir) && ln -fs $(basename $outdir) $(basename $default_name))
# fi

echo -e "END: $(date)\n" 1>&2
echo -e "STATUS: DONE.\n" 1>&2
touch $outdir/AMPLIFY.DONE

echo "Output: $outdir/amps.final.faa" 1>&2
if [[ "$email" = true ]]; then
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
	species=$(echo "$species" | sed 's/^./\u&. /')
	#	echo "$outdir" | mail -s "${species^}: STAGE 10: AMPLIFY: SUCCESS" $address
	echo "$outdir" | mail -s "${species}: STAGE 10: AMPLIFY: SUCCESS" $address
	# echo "$outdir" | mail -s "Successful AMPlify run on $org" $address
	echo -e "\nEmail alert sent to $address." 1>&2
fi
