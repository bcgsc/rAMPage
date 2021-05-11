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
		\t  - amps.conf.short.charge.nr.faa\n \
		\t  - AMPlify_results.conf.short.charge.nr.tsv\n \
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
		\t-c <int>\tcharge cut-off [i.e. keep charge(sequences >= int]\t(default = 2)\n \
		\t-d\tdebug mode\t(skips running AMPlify)\n \
		\t-f\tforce final AMPs to be the lowest number of non-zero AMPs\n \
		\t-h\tshow this help menu\n \
		\t-l <int>\tlength cut-off [i.e. keep len(sequences) <= int]\t(default = 30)\n \
		\t-o <directory>\toutput directory\t(required)\n \
		\t-s <0 to 1>\tAMPlify score cut-off [i.e. keep score(sequences) >= dbl]\t(default = 0.90)\n \
		\t-t <int>\tnumber of threads\t(default = all)\n \
		" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com -c 2 -l 30 -s 0.90 -t 8 -o /path/to/amplify/outdir /path/to/cleavage/cleaved.mature.len.faa\n \
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
confidence=0.90
length=30
email=false
# threads=8
custom_threads=false
charge=2
outdir=""
debug=false
forced_characterization=false
# 4 - read options
while getopts :a:c:dfhl:o:s:t: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	c) charge="$OPTARG" ;;
	d) debug=true ;;
	f) forced_characterization=true ;;
	s) confidence="$OPTARG" ;;
	h) get_help ;;
	l) length="$OPTARG" ;;
	o)
		outdir=$(realpath $OPTARG)
		;;
	t)
		threads="$OPTARG"
		custom_threads=true
		;;
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

if (($(echo "$confidence < 0.5" | bc -l) || $(echo "$confidence > 1" | bc -l))); then
	print_error "Invalid argument for -c <0.5 to 1>: $confidence"
fi

# if [[ "$confidence" -lt 0 || "$confidence" -gt 1 ]]; then
# 	print_error "Invalid argument for -c <0 to 1>: $confidence"
# fi

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
		echo -e "THREADS: $threads"
	fi
} 1>&2

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

function lower() {
	conf=$1
	decimal_places=$(echo "$conf" | awk -F "." '{print length($2)}')
	last_digit=${conf: -1}
	if [[ "$last_digit" == "0" ]]; then
		factor="0.$(printf "%0${decimal_places}d" 10)"
	else
		factor="0.$(printf "%0${decimal_places}d" $last_digit)"
	fi
	printf "%.${decimal_places}f" "$(echo "${conf}-${factor}" | bc)"
}

confidence_lower=$(lower $confidence)
confidence_lower_lower=$(lower $confidence_lower)

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

echo "PROGRAM: $(command -v $RUN_AMPLIFY)" 1>&2
echo -e "VERSION: $(command -v $RUN_AMPLIFY | awk -F "/" '{print $(NF-2)}' | cut -f2 -d-)\n" 1>&2
# echo "VERSION: 1.0.0" 1>&2

# 1 - FILTER BY NOTHING
# outfile=$outdir/amps.faa
outfile_nr=$outdir/amps.nr.faa

# 2 - FILTER BY SCORE
# outfile_conf=$outdir/amps.conf.faa
outfile_conf_nr=$outdir/amps.conf_${confidence}.nr.faa
outfile_conf_nr_tsv=$outdir/AMPlify_results.conf_${confidence}.nr.tsv
outfile_conf_nr_ln=amps.conf.nr.faa
outfile_conf_nr_tsv_ln=AMPlify_results.conf.nr.tsv

# 3 - FILTER BY LENGTH
# outfile_short=$outdir/amps.short.faa
outfile_short_nr=$outdir/amps.short_${length}.nr.faa
outfile_short_nr_tsv=$outdir/AMPlify_results.short_${length}.nr.tsv
outfile_short_nr_ln=amps.short.nr.faa
outfile_short_nr_tsv_ln=AMPlify_results.short.nr.tsv

# 4 - FILTER BY CHARGE
# outfile_charge=$outdir/amps.charge.faa
outfile_charge_nr=$outdir/amps.charge_${charge}.nr.faa
outfile_charge_nr_tsv=$outdir/AMPlify_results.charge_${charge}.nr.tsv
outfile_charge_nr_ln=amps.charge.nr.faa
outfile_charge_nr_tsv_ln=AMPlify_results.charge.nr.tsv

# 5 - FILTER BY SCORE, CHARGE - NEW
# outfile_conf_charge=$outdir/amps.conf.charge.faa
outfile_conf_charge_nr=$outdir/amps.conf_${confidence}.charge_${charge}.nr.faa
outfile_conf_charge_nr_tsv=$outdir/AMPlify_results.conf_${confidence}.charge_${charge}.nr.tsv
outfile_conf_charge_nr_ln=amps.conf.charge.nr.faa
outfile_conf_charge_nr_tsv_ln=AMPlify_results.conf.charge.nr.tsv

# 6 - FILTER BY SCORE, LENGTH
# outfile_conf_short=$outdir/amps.conf.short.faa
outfile_conf_short_nr=$outdir/amps.conf_${confidence}.short_${length}.nr.faa
outfile_conf_short_nr_tsv=$outdir/AMPlify_results.conf_${confidence}.short_${length}.nr.tsv
outfile_conf_short_nr_ln=amps.conf.short.nr.faa
outfile_conf_short_nr_tsv_ln=AMPlify_results.conf.short.nr.tsv

# 7 - FILTER BY LENGTH, CHARGE - NEW
# outfile_short_charge=$outdir/amps.short.charge.faa
outfile_short_charge_nr=$outdir/amps.short_${length}.charge_${charge}.nr.faa
outfile_short_charge_nr_tsv=$outdir/AMPlify_results.short_${length}.charge_${charge}.nr.tsv
outfile_short_charge_nr_ln=amps.short.charge.nr.faa
outfile_short_charge_nr_tsv_ln=AMPlify_results.short.charge.nr.tsv

# outfile_short_charge_lower_lower=$outdir/amps.conf_${confidence_lower_lower}.short.charge.faa
outfile_short_charge_lower_lower_nr=$outdir/amps.conf_${confidence_lower_lower}.short_${length}.charge_${charge}.nr.faa
outfile_short_charge_lower_lower_nr_tsv=$outdir/AMPlify_results.conf_${confidence_lower_lower}.short_${length}.charge_${charge}.nr.tsv
outfile_short_charge_lower_lower_nr_ln=amps.conf_${confidence_lower_lower}.short.charge.nr.faa
outfile_short_charge_lower_lower_nr_tsv_ln=AMPlify_results.conf_${confidence_lower_lower}.short.charge.nr.tsv

# 7.5 - FILTER BY LENGTH, CHARGE - NEW,  + by lenient score
# outfile_short_charge_lower=$outdir/amps.conf_${confidence_lower}.short.charge.faa
outfile_short_charge_lower_nr=$outdir/amps.conf_${confidence_lower}.short_${length}.charge_${charge}.nr.faa
outfile_short_charge_lower_nr_tsv=$outdir/AMPlify_results.conf_${confidence_lower}.short_${length}.charge_${charge}.nr.tsv
outfile_short_charge_lower_nr_ln=amps.conf_${confidence_lower}.short.charge.nr.faa
outfile_short_charge_lower_nr_tsv_ln=AMPlify_results.conf_${confidence_lower}.short.charge.nr.tsv
# 8 - FILTER BY ALL
# outfile_conf_short_charge=$outdir/amps.conf.short.charge.faa
outfile_conf_short_charge_nr=$outdir/amps.conf_${confidence}.short_${length}.charge_${charge}.nr.faa
outfile_conf_short_charge_nr_tsv=$outdir/AMPlify_results.conf_${confidence}.short_${length}.charge_${charge}.nr.tsv
outfile_conf_short_charge_nr_ln=amps.conf_${confidence}.short.charge.nr.faa
outfile_conf_short_charge_nr_tsv_ln=AMPlify_results.conf_${confidence}.short.charge.nr.tsv

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
	echo -e "COMMAND: $RUN_SEQTK subseq $outdir/AMPlify_results.nr.faa <($RUN_SEQTK comp $input | awk '{if(\$2>=2 && \$2<=200) print \$1}') > ${input/.faa/.len.faa}\n" 1>&2
	$RUN_SEQTK subseq $outdir/AMPlify_results.nr.faa <($RUN_SEQTK comp $input | awk '{if($2>=2 && $2<=200) print $1}') >${input/.faa/.len.faa}
	echo -e "Removed $len_seq sequences.\n" 1>&2
	input=${input/.faa/.len.faa}
	echo -e "Output: $input\n" 1>&2
else
	echo -e "Sequences are already between 2 and 200 amino acids long.\n" 1>&2
fi

# RUNNING AMPLIFY
# -------------------
if [[ "$debug" = false ]]; then
	model_dir=$(dirname $(dirname $RUN_AMPLIFY))/models
	echo "Classifying sequences as 'AMP' or 'non-AMP' using AMPlify..." 1>&2
	echo -e "COMMAND: $RUN_AMPLIFY --model_dir $model_dir -s $input --out_dir $outdir --out_format txt 1> $outdir/amplify.out 2> $outdir/amplify.err || true\n" 1>&2
	$RUN_AMPLIFY --model_dir $model_dir -s $input --out_dir $outdir --out_format txt 1>$outdir/amplify.out 2>$outdir/amplify.err || true

	echo "Finished running AMPlify." 1>&2
else
	echo "DEBUG MODE: Skipping AMPlify..." 1>&2
	# echo "Classifying sequences as 'AMP' or 'non-AMP' using AMPlify..." 1>&2
	# model_dir=$(dirname $(dirname $RUN_AMPLIFY))/models
	# echo -e "COMMAND: $RUN_AMPLIFY --model_dir $model_dir -s $input --out_dir $outdir --out_format txt 1> $outdir/amplify.out 2> $outdir/amplify.err || true\n" 1>&2
	# echo "Finished running AMPlify." 1>&2
fi
# -------------------
file=$(ls -t $outdir/AMPlify_results_*.txt 2>/dev/null | head -n1 || true)
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

# remove empty lines
(cd $outdir && ln -fs $(basename $file) AMPlify_results.nr.txt)
file=$outdir/AMPlify_results.nr.txt
sed -i --follow-symlinks '/^$/d' $file

# convert TXT to TSV
if [[ "$debug" = false ]]; then
	if [[ -s $outdir/AMPlify_results.nr.faa ]]; then
		rm $outdir/AMPlify_results.nr.faa
	fi

	echo -e "Converting the AMPlify TXT output to a TSV file and a FASTA file...\n" 1>&2
	echo -e "Sequence_ID\tSequence\tLength\tScore\tPrediction\tCharge\tAttention" >$outdir/AMPlify_results.nr.tsv
	while read line; do
		seq_id=$(echo "$line" | awk '{print $NF}')
		read line
		sequence=$(echo "$line" | awk '{print $NF}')
		read line
		score=$(echo "$line" | awk '{print $NF}')
		read line
		pred=$(echo "$line" | awk '{print $NF}')
		read line
		attn=$(echo "$line" | awk -F ": " '{print $NF}')

		# calculate charge
		num_K=$(echo "$sequence" | tr -cd "K" | wc -c)
		num_R=$(echo "$sequence" | tr -cd "R" | wc -c)
		num_D=$(echo "$sequence" | tr -cd "D" | wc -c)
		num_E=$(echo "$sequence" | tr -cd "E" | wc -c)

		num_pos=$((num_K + num_R))
		num_neg=$((num_D + num_E))

		pepcharge=$((num_pos - num_neg))

		len=$(echo -n "$sequence" | wc -c)
		echo ">$seq_id length=$len score=$score prediction=$pred charge=$pepcharge" >>$outdir/AMPlify_results.nr.faa
		echo "$sequence" >>$outdir/AMPlify_results.nr.faa

		echo -e "$seq_id\t$sequence\t$len\t$score\t$pred\t$pepcharge\t$attn" >>$outdir/AMPlify_results.nr.tsv
	done <$file
else
	if [[ -s $outdir/AMPlify_results.nr.faa && -s $outdir/AMPlify_results.nr.tsv ]]; then
		# echo -e "Converting the AMPlify TXT output to a TSV file and a FASTA file...\n" 1>&2
		echo -e "DEBUG MODE: Skipping TXT to TSV conversion...\n" 1>&2
	else
		if [[ -s $outdir/AMPlify_results.nr.faa ]]; then
			rm $outdir/AMPlify_results.nr.faa
		fi

		echo -e "Converting the AMPlify TXT output to a TSV file and a FASTA file...\n" 1>&2
		echo -e "Sequence_ID\tSequence\tLength\tScore\tPrediction\tCharge\tAttention" >$outdir/AMPlify_results.nr.tsv
		while read line; do
			seq_id=$(echo "$line" | awk '{print $NF}')
			read line
			sequence=$(echo "$line" | awk '{print $NF}')
			read line
			score=$(echo "$line" | awk '{print $NF}')
			read line
			pred=$(echo "$line" | awk '{print $NF}')
			read line
			attn=$(echo "$line" | awk -F ": " '{print $NF}')

			# calculate charge
			num_K=$(echo "$sequence" | tr -cd "K" | wc -c)
			num_R=$(echo "$sequence" | tr -cd "R" | wc -c)
			num_D=$(echo "$sequence" | tr -cd "D" | wc -c)
			num_E=$(echo "$sequence" | tr -cd "E" | wc -c)

			num_pos=$((num_K + num_R))
			num_neg=$((num_D + num_E))

			pepcharge=$((num_pos - num_neg))

			len=$(echo -n "$sequence" | wc -c)
			echo ">$seq_id length=$len score=$score prediction=$pred charge=$pepcharge" >>$outdir/AMPlify_results.nr.faa
			echo "$sequence" >>$outdir/AMPlify_results.nr.faa

			echo -e "$seq_id\t$sequence\t$len\t$score\t$pred\t$pepcharge\t$attn" >>$outdir/AMPlify_results.nr.tsv
		done <$file
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
echo "${filter_counter} >>> Filtering for AMP sequences (AMPlify score >= 0.50)..." 1>&2
echo "$header" >$outdir/AMPlify_results.amps.nr.tsv
echo -e "COMMAND: awk -F \"\\\t\" '{if(\$5==\"AMP\") print}' <(tail -n +2 $outdir/AMPlify_results.nr.tsv) >> $outdir/AMPlify_results.amps.nr.tsv\n" 1>&2
awk -F "\t" '{if($5=="AMP") print}' <(tail -n +2 $outdir/AMPlify_results.nr.tsv) >>$outdir/AMPlify_results.amps.nr.tsv

echo "Converting those sequences to FASTA format..." 1>&2
# 4th field is prediction, and 1st field is sequence ID:
echo -e "COMMAND: $RUN_SEQTK subseq $outdir/AMPlify_results.nr.faa <(awk -F \"\\\t\" '{if(\$5==\"AMP\") print \$1}' <(tail -n +2 $outdir/AMPlify_results.nr.tsv)) > ${outfile_nr} || true\n" 1>&2
$RUN_SEQTK subseq $outdir/AMPlify_results.nr.faa <(awk -F "\t" '{if($5=="AMP") print $1}' <(tail -n +2 $outdir/AMPlify_results.nr.tsv)) >${outfile_nr} || true

echo "SUMMARY" 1>&2
print_line

count=$(grep -c '^>' ${outfile_nr} || true)

{
	echo "Output: ${outfile_nr}"
	echo "Number of unique AMPs: $(printf "%'d" $count)"
} | sed 's/^/\t/' 1>&2

print_line
echo 1>&2
#----------------------------------------------------------
((filter_counter += 1))
### 2 - Filter all sequences for those with AMPlify score >= $confidence
#--------------------------------------------------------------------
echo "${filter_counter} >>> Filtering for AMP sequences (AMPlify score >= 0.50) with an AMPlify score >= $confidence..." 1>&2
echo "$header" >$outfile_conf_nr_tsv
echo -e "COMMAND: awk -F \"\\\t\" -v var=$confidence '{if(\$4>=var) print}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >> $outfile_conf_nr_tsv\n" 1>&2
awk -F "\t" -v var=$confidence '{if($4>=var) print}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >>$outfile_conf_nr_tsv

echo "Converting those sequences to FASTA format..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq ${outfile_nr} <(awk -F \"\\\t\" -v var=$confidence '{if(\$4>=var) print \$1}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv)) > ${outfile_conf_nr}\n" 1>&2
$RUN_SEQTK subseq ${outfile_nr} <(awk -F "\t" -v var=$confidence '{if($4>=var) print $1}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv)) >${outfile_conf_nr}
(
	cd $outdir &&
		ln -fs $(basename $outfile_conf_nr) $outfile_conf_nr_ln &&
		ln -fs $(basename $outfile_conf_nr_tsv) $outfile_conf_nr_tsv_ln
)

echo "SUMMARY" 1>&2
print_line

count_conf=$(grep -c '^>' ${outfile_conf_nr} || true)

{
	echo "Output: ${outfile_conf_nr}"
	echo "Number of high-confidence (score >= $confidence) unique AMPs: $(printf "%'d" ${count_conf})"
} | sed 's/^/\t/' 1>&2

print_line
echo 1>&2
#--------------------------------------------------------------------

((filter_counter += 1))
### 3 - Filter all sequences for those labelled 'AMP' and length <= $length
#--------------------------------------------------------------------
echo "${filter_counter} >>> Filtering for AMP sequences (AMPlify score >= 0.50) and with length <= $length..." 1>&2
echo "$header" >$outfile_short_nr_tsv
echo -e "COMMAND: awk -F \"\\\t\" -v var=$length '{if(\$3<=var) print }' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >> $outfile_short_nr_tsv\n" 1>&2
awk -F "\t" -v var=$length '{if($3<=var) print }' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >>$outfile_short_nr_tsv

echo "Converting those sequences into FASTA format..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq ${outfile_nr} <(awk -F \"\\\t\" -v var=$length '{if(\$3<=var) print \$1}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv)) > ${outfile_short_nr}\n" 1>&2
$RUN_SEQTK subseq ${outfile_nr} <(awk -F "\t" -v var=$length '{if($3<=var) print $1}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv)) >${outfile_short_nr}

(
	cd $outdir &&
		ln -fs $(basename $outfile_short_nr) $outfile_short_nr_ln &&
		ln -fs $(basename $outfile_short_nr_tsv) $outfile_short_nr_tsv_ln
)

echo "SUMMARY" 1>&2
print_line

count_short=$(grep -c '^>' ${outfile_short_nr} || true)

{
	echo "Output: ${outfile_short_nr}"
	echo "Number of short (length <= $length) unique AMPs: $(printf "%'d" ${count_short})"
} | sed 's/^/\t/' 1>&2

print_line
echo 1>&2

((filter_counter += 1))
### 4 - Filter all sequences labelled 'AMP' and have charge >= $charge
#--------------------------------------------------------------------
echo "${filter_counter} >>> Filtering for AMP sequences (AMPlify score >= 0.50) and with charge >= ${charge}..." 1>&2
echo "$header" >$outfile_charge_nr_tsv
echo -e "COMMAND: awk -F \"\\\t\" -v var=$charge '{if(\$6>=var) print }' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >> $outfile_charge_nr_tsv\n" 1>&2
awk -F "\t" -v var=$charge '{if($6>=var) print }' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >>$outfile_charge_nr_tsv

echo "Converting those sequences into FASTA format..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq ${outfile_nr} <(awk -F \"\\\t\" -v var=$charge '{if(\$6>=var) print \$1}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv)) > $outfile_charge_nr\n" 1>&2
$RUN_SEQTK subseq ${outfile_nr} <(awk -F "\t" -v var=$charge '{if($6>=var) print $1}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv)) >${outfile_charge_nr}

(
	cd $outdir &&
		ln -fs $(basename $outfile_charge_nr) $outfile_charge_nr_ln &&
		ln -fs $(basename $outfile_charge_nr_tsv) $outfile_charge_nr_tsv_ln
)

echo "SUMMARY" 1>&2
print_line

count_charge=$(grep -c '^>' ${outfile_charge_nr} || true)

{
	echo "Output: ${outfile_charge_nr}"
	echo "Number of positive (charge >= $charge) unique AMPs: $(printf "%'d" ${count_charge})"
} | sed 's/^/\t/' 1>&2

print_line
echo 1>&2
#--------------------------------------------------------------------

((filter_counter += 1))
### 5 - Filter all sequences for those AMPlify score >= $confidence and have charge >= $charge
#--------------------------------------------------------------------
echo "${filter_counter} >>> Filtering for AMP sequences (AMPlify score >= 0.50) with AMPlify score >= $confidence and with charge >= ${charge}..." 1>&2
echo "$header" >$outfile_conf_charge_nr_tsv
echo -e "COMMAND: awk -F \"\\\t\" -v var=$charge -v c=$confidence'{if(\$6>=var && \$4>=c) print }' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >> $outfile_conf_charge_nr_tsv\n" 1>&2
awk -F "\t" -v var=$charge -v c=$confidence '{if($6>=var && $4>=c) print }' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >>$outfile_conf_charge_nr_tsv

echo "Converting those sequences into FASTA format..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq ${outfile_nr} <(awk -F \"\\\t\" -v var=$charge -v c=$confidence '{if(\$6>=var && \$4>=c) print \$1}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv)) > $outfile_conf_charge_nr\n" 1>&2
$RUN_SEQTK subseq ${outfile_nr} <(awk -F "\t" -v var=$charge -v c=$confidence '{if($6>=var && $4>=c) print $1}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv)) >${outfile_conf_charge_nr}

(
	cd $outdir &&
		ln -fs $(basename $outfile_conf_charge_nr) $outfile_conf_charge_nr_ln &&
		ln -fs $(basename $outfile_conf_charge_nr_tsv) $outfile_conf_charge_nr_tsv_ln
)

echo "SUMMARY" 1>&2
print_line

count_conf_charge=$(grep -c '^>' ${outfile_conf_charge_nr} || true)

{
	echo "Output: ${outfile_conf_charge_nr}"
	echo "Number of high confidence (score >= $confidence) and positive (charge >= $charge) unique AMPs: $(printf "%'d" ${count_conf_charge})"
} | sed 's/^/\t/' 1>&2

print_line
echo 1>&2
#--------------------------------------------------------------------

((filter_counter += 1))
#--------------------------------------------------------------------
### 6 - Filter all sequences for those with AMPlify score >= $confidence and length <= $length
#--------------------------------------------------------------------
echo "${filter_counter} >>> Filtering for AMP sequences (AMPlify score >= 0.50) with length <= $length and AMPlify score >= ${confidence}..." 1>&2
echo "$header" >$outfile_conf_short_nr_tsv
echo -e "COMMAND: awk -F \"\\\t\" -v l=$length -v c=$confidence '{if(\$3<=l && \$4>=c) print}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >> $outfile_conf_short_nr_tsv\n" 1>&2
awk -F "\t" -v l=$length -v c=$confidence '{if($3<=l && $4>=c) print}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >>$outfile_conf_short_nr_tsv

echo "Converting those sequences to FASTA format..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq ${outfile_nr} <(awk -F \"\\\t\" -v l=$length -v c=$confidence '{if(\$3<=l && \$4>=c) print \$1}' <(tail -n +2 $outdir/AMPlify_results..amps.nr.tsv)) > ${outfile_conf_short_nr}\n" 1>&2
$RUN_SEQTK subseq ${outfile_nr} <(awk -F "\t" -v l=$length -v c=$confidence '{if($3<=l && $4>=c) print $1}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv)) >${outfile_conf_short_nr}

(
	cd $outdir &&
		ln -fs $(basename $outfile_conf_short_nr) $outfile_conf_short_nr_ln &&
		ln -fs $(basename $outfile_conf_short_nr_tsv) $outfile_conf_short_nr_tsv_ln
)

echo "SUMMARY" 1>&2
print_line

count_conf_short=$(grep -c '^>' ${outfile_conf_short_nr} || true)

{
	echo "Output: ${outfile_conf_short_nr}"
	echo "Number of high-confidence (score >= $confidence) and short (length <= $length) unique AMPs: $(printf "%'d" ${count_conf_short})"
} | sed 's/^/\t/' 1>&2

print_line
echo 1>&2
#--------------------------------------------------------------------

((filter_counter += 1))
#--------------------------------------------------------------------
### 7 - Filter all sequences for those with charge >= $charge and length <= $length
#--------------------------------------------------------------------
echo "${filter_counter} >>> Filtering for AMP sequences (AMPlify score >= 0.5) with length <= $length and charge >= ${charge}..." 1>&2
echo "$header" >$outfile_short_charge_nr_tsv
echo -e "COMMAND: awk -F \"\\\t\" -v l=$length -v c=$charge '{if(\$3<=l && \$6>=c) print}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >> $outfile_short_charge_nr_tsv\n" 1>&2
awk -F "\t" -v l=$length -v c=$charge '{if($3<=l && $6>=c) print}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >>$outfile_short_charge_nr_tsv

echo "Converting those sequences to FASTA format..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq ${outfile_nr} <(awk -F \"\\\t\" -v l=$length -v c=$charge '{if(\$3<=l && \$6>=c) print \$1}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv)) > ${outfile_short_charge_nr}\n" 1>&2
$RUN_SEQTK subseq ${outfile_nr} <(awk -F "\t" -v l=$length -v c=$charge '{if($3<=l && $6>=c) print $1}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv)) >${outfile_short_charge_nr}

(
	cd $outdir &&
		ln -fs $(basename $outfile_short_charge_nr) $outfile_short_charge_nr_ln &&
		ln -fs $(basename $outfile_short_charge_nr_tsv) $outfile_short_charge_nr_tsv_ln
)

echo "SUMMARY" 1>&2
print_line

count_short_charge=$(grep -c '^>' ${outfile_short_charge_nr} || true)

{
	echo "Output: ${outfile_short_charge_nr}"
	echo "Number of short (length <= $length) and positive (charge >= $charge) unique AMPs: $(printf "%'d" ${count_short_charge})"
} | sed 's/^/\t/' 1>&2

print_line
echo 1>&2
#--------------------------------------------------------------------
# ONLY DO THE MORE LENIENT SCORE IF the lenient score is still > 0.50
if [[ $(echo "${confidence_lower_lower} > 0.50" | bc -l) ]]; then
	((filter_counter += 1))
	#--------------------------------------------------------------------
	### 8 - Filter all sequences for those with charge >= $charge and length <= $length, and more leninet score
	#--------------------------------------------------------------------
	echo "${filter_counter} >>> Filtering for AMP sequences (AMPlify score >= 0.5) with length <= $length, charge >= ${charge}, and AMPlify score >= ${confidence_lower_lower}..." 1>&2
	echo "$header" >$outfile_short_charge_lower_lower_nr_tsv
	echo -e "COMMAND: awk -F \"\\\t\" -v l=$length -v c=$charge -v s=${confidence_lower_lower}'{if(\$3<=l && \$6>=c && \$4>=s) print}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >> $outfile_short_charge_lower_lower_nr_tsv\n" 1>&2
	awk -F "\t" -v l=$length -v c=$charge -v s=${confidence_lower_lower} '{if($3<=l && $6>=c && $4>=s) print}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >>$outfile_short_charge_lower_lower_nr_tsv

	echo "Converting those sequences to FASTA format..." 1>&2
	echo -e "COMMAND: $RUN_SEQTK subseq ${outfile_nr} <(awk -F \"\\\t\" -v l=$length -v c=$charge -v s=${confidence_lower_lower} '{if(\$3<=l && \$6>=c && \$4>=s) print \$1}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv)) > ${outfile_short_charge_lower_lower_nr}\n" 1>&2
	$RUN_SEQTK subseq ${outfile_nr} <(awk -F "\t" -v l=$length -v c=$charge -v s=${confidence_lower_lower} '{if($3<=l && $6>=c && $4>=s) print $1}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv)) >${outfile_short_charge_lower_lower_nr}

	(
		cd $outdir &&
			ln -fs $(basename $outfile_short_charge_lower_lower_nr) $outfile_short_charge_lower_lower_nr_ln &&
			ln -fs $(basename $outfile_short_charge_lower_lower_nr_tsv) $outfile_short_charge_lower_lower_nr_tsv_ln
	)

	echo "SUMMARY" 1>&2
	print_line

	count_short_charge_lower_lower=$(grep -c '^>' ${outfile_short_charge_lower_lower_nr} || true)

	{
		echo "Output: ${outfile_short_charge_lower_lower_nr}"
		echo "Number of lower-confidence (score >= ${confidence_lower_lower}), short (length <= $length), and positive (charge >= $charge) unique AMPs: $(printf "%'d" ${count_short_charge_lower_lower})"
	} | sed 's/^/\t/' 1>&2

	print_line
	echo 1>&2
else
	count_short_charge_lower_lower="NA"
fi
#--------------------------------------------------------------------
# ONLY DO THE MORE LENIENT SCORE IF the lenient score is still > 0.50
if [[ $(echo "${confidence_lower} > 0.50" | bc -l) ]]; then
	((filter_counter += 1))
	#--------------------------------------------------------------------
	### 8 - Filter all sequences for those with charge >= $charge and length <= $length, and more leninet score
	#--------------------------------------------------------------------
	echo "${filter_counter} >>> Filtering for AMP sequences (AMPlify score >= 0.5) with length <= $length, charge >= ${charge}, and AMPlify score >= ${confidence_lower}..." 1>&2
	echo "$header" >$outfile_short_charge_lower_nr_tsv
	echo -e "COMMAND: awk -F \"\\\t\" -v l=$length -v c=$charge -v s=${confidence_lower}'{if(\$3<=l && \$6>=c && \$4>=s) print}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >> $outfile_short_charge_lower_nr_tsv\n" 1>&2
	awk -F "\t" -v l=$length -v c=$charge -v s=${confidence_lower} '{if($3<=l && $6>=c && $4>=s) print}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >>$outfile_short_charge_lower_nr_tsv

	echo "Converting those sequences to FASTA format..." 1>&2
	echo -e "COMMAND: $RUN_SEQTK subseq ${outfile_nr} <(awk -F \"\\\t\" -v l=$length -v c=$charge -v s=${confidence_lower} '{if(\$3<=l && \$6>=c && \$4>=s) print \$1}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv)) > ${outfile_short_charge_lower_nr}\n" 1>&2
	$RUN_SEQTK subseq ${outfile_nr} <(awk -F "\t" -v l=$length -v c=$charge -v s=${confidence_lower} '{if($3<=l && $6>=c && $4>=s) print $1}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv)) >${outfile_short_charge_lower_nr}

	(
		cd $outdir &&
			ln -fs $(basename $outfile_short_charge_lower_nr) $outfile_short_charge_lower_nr_ln &&
			ln -fs $(basename $outfile_short_charge_lower_nr_tsv) $outfile_short_charge_lower_nr_tsv_ln
	)

	echo "SUMMARY" 1>&2
	print_line

	count_short_charge_lower=$(grep -c '^>' ${outfile_short_charge_lower_nr} || true)

	{
		echo "Output: ${outfile_short_charge_lower_nr}"
		echo "Number of medium-confidence (score >= ${confidence_lower}), short (length <= $length), and positive (charge >= $charge) unique AMPs: $(printf "%'d" ${count_short_charge_lower})"
	} | sed 's/^/\t/' 1>&2

	print_line
	echo 1>&2
else
	count_short_charge_lower="NA"
fi

#--------------------------------------------------------------------
((filter_counter += 1))
### 9 - Filter short and confident sequences for those with AMPlify score >= $confidence and length <= $length, and charge >= $charge
#--------------------------------------------------------------------
echo "${filter_counter} >>> Filtering for AMP sequences (AMPlify score >= 0.50) with charge >= $charge, length <= $length and AMPlify score >= ${confidence}..." 1>&2
echo "$header" >$outfile_conf_short_charge_nr_tsv
echo -e "COMMAND: awk -F \"\\\t\" -v l=$length -v c=$confidence -v p=$charge '{if(\$3<=l && \$4>=c && \$6>=p) print}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >> $outfile_conf_short_charge_nr_tsv\n" 1>&2
awk -F "\t" -v l=$length -v c=$confidence -v p=$charge '{if($3<=l && $4>=c && $6>=p) print}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv) >>$outfile_conf_short_charge_nr_tsv

echo "Converting those sequences to FASTA format..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq ${outfile_nr} <(awk -F \"\\\t\" -v l=$length -v c=$confidence -v p=$charge '{if(\$3<=l && \$4>=c && \$6>=p) print \$1}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv)) > ${outfile_conf_short_charge_nr}\n" 1>&2
$RUN_SEQTK subseq ${outfile_nr} <(awk -F "\t" -v l=$length -v c=$confidence -v p=$charge '{if($3<=l && $4>=c && $6>=p) print $1}' <(tail -n +2 $outdir/AMPlify_results.amps.nr.tsv)) >${outfile_conf_short_charge_nr}

(
	cd $outdir &&
		ln -fs $(basename $outfile_conf_short_charge_nr) $outfile_conf_short_charge_nr_ln &&
		ln -fs $(basename $outfile_conf_short_charge_nr_tsv) $outfile_conf_short_charge_nr_tsv_ln &&
		ln -fs $outfile_conf_short_charge_nr_ln amps.conf.short.charge.nr.faa &&
		ln -fs $outfile_conf_short_charge_nr_tsv_ln AMPlify_results.conf.short.charge.nr.tsv
)

echo "SUMMARY" 1>&2
print_line

count_conf_short_charge=$(grep -c '^>' ${outfile_conf_short_charge_nr} || true)

{
	echo "Output: ${outfile_conf_short_charge_nr}"
	echo "Number of high-confidence (score >= $confidence), short (length <= $length), and positive (charge >= $charge) unique AMPs: $(printf "%'d" ${count_conf_short_charge})"
} | sed 's/^/\t/' 1>&2

print_line
echo 1>&2
#--------------------------------------------------------------------
# echo $outdir/*.faa
sed --follow-symlinks -i '/^$/d' $outdir/*.faa

echo "FINAL SUMMARY" 1>&2
print_line

echo 1>&2
echo -e "$(basename $outfile_nr)\t$count\n \
	$outfile_conf_nr_ln\t$count_conf\n \
	$outfile_charge_nr_ln\t$count_charge\n \
	$outfile_short_nr_ln\t$count_short\n \
	$outfile_conf_charge_nr_ln\t$count_conf_charge\n \
	$outfile_conf_short_nr_ln\t$count_conf_short\n \
	$outfile_short_charge_nr_ln\t$count_short_charge\n \
	$outfile_short_charge_lower_lower_nr_ln\t$count_short_charge_lower_lower\n \
	$outfile_short_charge_lower_nr_ln\t$count_short_charge_lower\n \
	$outfile_conf_short_charge_nr_ln\t$count_conf_short_charge\n \
	" | sed 's/^\s\+//g' | sed '/^$/d' | grep -v "NA" >$outdir/amps.summary.tsv
{
	echo -e "\
	File (nr = non-redundant)\tDescription\n \
	-------------------------\t-----------\n \
	AMPlify_results.nr.txt\traw AMPlify results\n \
	AMPlify_results.nr.tsv\traw AMPlify results parsed into a TSV\n \
	AMPlify_results.nr.faa\tsequences of raw AMPlify results with new headers\n \
	$(basename $outfile_nr)\tnr sequences in AMPlify results labelled 'AMP'\n \
	$outfile_conf_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= $confidence\n \
	$outfile_charge_nr_ln\tnr sequences labelled 'AMP' with charge >= $charge\n \
	$outfile_short_nr_ln\tnr sequences labelled 'AMP' with length <= $length\n \
	$outfile_conf_charge_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= $confidence and charge >= $charge\n \
	$outfile_conf_short_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= $confidence and length <= $length\n \
	$outfile_short_charge_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with length <= $length and charge >= $charge\n \
	$outfile_short_charge_lower_lower_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= ${confidence_lower_lower}, length <= $length, and charge >= $charge\n \
	$outfile_short_charge_lower_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= ${confidence_lower}, length <= $length, and charge >= $charge\n \
	$outfile_conf_short_charge_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= $confidence, length <= $length, and charge >= $charge\n \
	"

	echo -e "\
		FASTA\tTSV\n \
		-----\t---\n \
		AMPlify_results.nr.faa\tAMPlify_results.nr.tsv\n \
		$outfile_nr\tAMPlify_results.amps.nr.tsv\n \
		$outfile_conf_nr_ln\tAMPlify_results.conf.nr.tsv\n \
		$outfile_charge_nr_ln\tAMPlify_results.charge.nr.tsv\n \
		$outfile_short_nr_ln\tAMPlify_results.short.nr.tsv\n \
		$outfile_conf_charge_nr_ln\tAMPlify_results.conf.charge.nr.tsv\n \
		$outfile_conf_short_nr_ln\tAMPlify_results.conf.short.nr.tsv\n \
		$outfile_short_charge_nr_ln\tAMPlify_results.short.charge.nr.tsv\n \
		$outfile_short_charge_lower_lower_nr_ln\tAMPlify_results.conf_${confidence_lower_lower}.short.charge.nr.tsv\n \
		$outfile_short_charge_lower_nr_ln\tAMPlify_results.conf_${confidence_lower}.short.charge.nr.tsv\n \
		$outfile_conf_short_charge_nr_ln\tAMPlify_results.conf.short.charge.nr.tsv\n \
	"
} | sed 's/^\s\+//g' | sed '/^$/d' | table >$outdir/README

{
	echo -e "\
		File (nr = non-redundant)\tDescription\n \
		-------------------------\t-----------\n \
		AMPlify_results.nr.txt\traw AMPlify results\n \
		AMPlify_results.nr.tsv\traw AMPlify results parsed into a TSV\n \
		AMPlify_results.nr.faa\tsequences of raw AMPlify results with new headers\n \
		$(basename $outfile_nr)\tnr sequences in AMPlify results labelled 'AMP'\n \
		$outfile_conf_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= $confidence\n \
		$outfile_charge_nr_ln\tnr sequences labelled 'AMP' with charge >= $charge\n \
		$outfile_short_nr_ln\tnr sequences labelled 'AMP' with length <= $length\n \
		$outfile_conf_charge_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= $confidence and charge >= $charge\n \
		$outfile_conf_short_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= $confidence and length <= $length\n \
		$outfile_short_charge_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with length <= $length and charge >= $charge\n \
		$outfile_short_charge_lower_lower_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= ${confidence_lower_lower}, length <= $length, and charge >= $charge\n \
		$outfile_short_charge_lower_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= ${confidence_lower}, length <= $length, and charge >= $charge\n \
		$outfile_conf_short_charge_nr_ln\tnr sequences labelled 'AMP' in AMPlify results with score >= $confidence, length <= $length, and charge >= $charge\n \
		"
	echo -e "\
		FASTA\tTSV\n \
		-----\t---\n \
		AMPlify_results.nr.faa\tAMPlify_results.nr.tsv\n \
		$outfile_nr\tAMPlify_results.amps.nr.tsv\n \
		$outfile_conf_nr_ln\tAMPlify_results.conf.nr.tsv\n \
		$outfile_charge_nr_ln\tAMPlify_results.charge.nr.tsv\n \
		$outfile_short_nr_ln\tAMPlify_results.short.nr.tsv\n \
		$outfile_conf_charge_nr_ln\tAMPlify_results.conf.charge.nr.tsv\n \
		$outfile_conf_short_nr_ln\tAMPlify_results.conf.short.nr.tsv\n \
		$outfile_short_charge_nr_ln\tAMPlify_results.short.charge.nr.tsv\n \
		$outfile_short_charge_lower_lower_nr_ln\tAMPlify_results.conf_${confidence_lower_lower}.short.charge.nr.tsv\n \
		$outfile_short_charge_lower_nr_ln\tAMPlify_results.conf_${confidence_lower}.short.charge.nr.tsv\n \
		$outfile_conf_short_charge_nr_ln\tAMPlify_results.conf.short.charge.nr.tsv\n \
	"
	echo -e "\
	File (nr = non-redundant)\tAMP Count\n \
	-------------------------\t-----------"
	cat $outdir/amps.summary.tsv

} | sed 's/^\s\+//g' | table | sed 's/^/\t/' 1>&2

echo 1>&2

# sed -i "s|^|$outdir/|" $outdir/amps.summary.tsv
# soft link the file that has the least number of AMPs but isn't 0
final_amps=$(awk -F "\t" '{if($2!=0) print $1}' $outdir/amps.summary.tsv | tail -n1)
filename=$(echo "$final_amps" | sed 's/amps/AMPlify_results/' | sed 's/\.faa/.tsv/')

if [[ $forced_characterization = true ]]; then
	(cd $outdir && ln -fs ${final_amps} amps.final.faa && ln -fs ${filename} AMPlify_results.final.tsv)
else
	(cd $outdir && ln -fs $(basename $outfile_conf_short_charge_nr_ln) amps.final.faa && ln -fs $(basename $outfile_conf_short_charge_nr_tsv_ln) AMPlify_results.final.tsv)
fi

final_count=$(grep -c '^>' $outdir/amps.final.faa || true)
echo "SYMLINKS:" 1>&2
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

default_name="$(realpath -s $(dirname $outdir)/amplify)"
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
