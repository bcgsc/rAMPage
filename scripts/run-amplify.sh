#!/bin/bash

set -euo pipefail
PROGRAM=$(basename $0)

# 1 - get_help function
function get_help() {
	{
		echo "DESCRIPTION:"
		echo -e "\
		\tPredicts AMP vs. non-AMP from the peptide sequence using AMPlify.\n \
		\n \
		\tOUTPUT:\n \
		\t-------\n \
		\t  - amps.conf.short.charge.nr.faa\n \
		\t  - AMPlify_results.conf.short.charge.tsv\n \
		\n \
		\tEXIT CODES:\n \
		\t-----------\n \
		\t  - 0: successfully completed\n \
		\t  - 1: general errors\n \
		\t  - 2: AMPlify failed\n \
		\n \
		\tFor more information on AMPlify: https://github.com/bcgsc/amplify\n \
		" | column -s $'\t' -t -L

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM -o <output directory> <input FASTA file>\n \
		" | column -s $'\t' -t -L

		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail address alert\n \
		\t-c <INT>\tcharge cut-off (i.e. keep charge(sequences >= INT)\t(default = 2)\n \
		\t-h\tshow this help menu\n \
		\t-l <INT>\tlength cut-off (i.e. keep len(sequences) <= INT)\t(default = 50)\n \
		\t-o <directory>\toutput directory\t(required)\n \
		\t-s <0 to 1>\tAMPlify score cut-off (i.e. keep score(sequences) >= DBL)\t(default = 0.99)\n \
		\t-t <INT>\tnumber of threads\t(default = 8)\n \
		" | column -s $'\t' -t -L
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

function print_line() {
	{
		printf '%.0s=' $(seq $(tput cols))
		echo
	} 1>&2
}

# 3 - no arguments given
if [[ "$#" -eq 0 ]]; then
	get_help
fi

# default parameters
confidence=0.99
length=50
email=false
threads=8
custom_threads=false
charge=2

# 4 - read options
while getopts :a:c:hl:o:s:t: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	c) charge="$OPTARG" ;;
	s) confidence="$OPTARG" ;;
	h) get_help ;;
	l) length="$OPTARG" ;;
	o)
		outdir=$(realpath $OPTARG)
		mkdir -p $outdir
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
if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "input file $(realpath $1) is empty."
fi

# 7 - remove status files
rm -f $outdir/AMPLIFY.DONE

# 8 - print env details
echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)\n" 1>&2

echo -e "PATH=$PATH\n" 1>&2
start_sec=$(date '+%s')

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
echo "PROGRAM: $(command -v $RUN_AMPLIFY)" 1>&2
echo -e "VERSION: $(command -v $RUN_AMPLIFY | awk -F "/" '{print $(NF-2)}' | cut -f2 -d-)\n" 1>&2
# echo "VERSION: 1.0.0" 1>&2

# 1 - FILTER BY NOTHING
outfile=$outdir/amps.faa
outfile_nr=$outdir/amps.nr.faa

# 2 - FILTER BY SCORE
outfile_conf=$outdir/amps.conf.faa
outfile_conf_nr=$outdir/amps.conf.nr.faa

# 3 - FILTER BY LENGTH
outfile_short=$outdir/amps.short.faa
outfile_short_nr=$outdir/amps.short.nr.faa

# 4 - FILTER BY CHARGE
outfile_charge=$outdir/amps.charge.faa
outfile_charge_nr=$outdir/amps.charge.nr.faa

# 5 - FILTER BY SCORE, CHARGE - NEW
outfile_conf_charge=$outdir/amps.conf.charge.faa
outfile_conf_charge_nr=$outdir/amps.conf.charge.nr.faa

# 6 - FILTER BY SCORE, LENGTH
outfile_conf_short=$outdir/amps.conf.short.faa
outfile_conf_short_nr=$outdir/amps.conf.short.nr.faa

# 7 - FILTER BY LENGTH, CHARGE - NEW
outfile_short_charge=$outdir/amps.short.charge.faa
outfile_short_charge_nr=$outdir/amps.short.charge.nr.faa

# 8 - FILTER BY ALL
outfile_conf_short_charge=$outdir/amps.conf.short.charge.faa
outfile_conf_short_charge_nr=$outdir/amps.conf.short.charge.nr.faa

echo "Checking sequence lengths..." 1>&2
len_seq=$($RUN_SEQTK comp $input | awk '{if($2<2 || $2>200) print $1}' | wc -l)

if [[ "$len_seq" -ne 0 ]]; then
	echo "Removing sequences with length < 2 or > 200 amino acids..." 1>&2
	echo -e "COMMAND: $RUN_SEQTK subseq $outdir/AMPlify_results.faa <($RUN_SEQTK comp $input | awk '{if(\$2>=2 && \$2<=200) print \$1}') > ${input/.faa/.len.faa}\n" 1>&2
	$RUN_SEQTK subseq $outdir/AMPlify_results.faa <($RUN_SEQTK comp $input | awk '{if($2>=2 && $2<=200) print $1}') >${input/.faa/.len.faa}
	echo -e "Removed $len_seq sequences.\n" 1>&2
	input=${input/.faa/.len.faa}
	echo -e "Output: $input\n" 1>&2
else
	echo -e "Sequences are already between 2 and 200 amino acids long.\n" 1>&2
fi

# RUNNING AMPLIFY
# -------------------
model_dir=$(dirname $(dirname $RUN_AMPLIFY))/models
echo "Classifying sequences as 'AMP' or 'non-AMP' using AMPlify..." 1>&2
echo -e "COMMAND: $RUN_AMPLIFY --model_dir $model_dir -s $input --out_dir $outdir --out_format txt 1> $outdir/amplify.out 2> $outdir/amplify.err || true\n" 1>&2
$RUN_AMPLIFY --model_dir $model_dir -s $input --out_dir $outdir --out_format txt 1>$outdir/amplify.out 2>$outdir/amplify.err || true

echo "Finished running AMPlify." 1>&2
# -------------------

file=$(ls -t $outdir/AMPlify_results_*.txt 2>/dev/null | head -n1 || true)
echo -e "Output: $file\n" 1>&2

if [[ ! -s $file ]]; then
	touch $outdir/AMPLIFY.FAIL
	if [[ "$email" = true ]]; then
		org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		echo "$outdir" | mail -s "Failed AMPlify run on $org" $address
		echo "Email alert sent to $address." 1>&2
	fi
	echo "ERROR: AMPlify output file $file does not exist or is empty!" 1>&2
	exit 2
fi

# echo -e "Softlinking $file to $outdir/AMPlify_results.txt...\n" 1>&2
if [[ ! -f $outdir/AMPlify_results.txt ]]; then
	cp $file $outdir/AMPlify_results.txt
fi
file=$outdir/AMPlify_results.txt

# remove empty lines
sed -i '/^$/d' $file

# convert TXT to TSV
if [[ -s $outdir/AMPlify_results.faa ]]; then
	rm $outdir/AMPlify_results.faa
fi

echo -e "Converting the AMPlify TXT output to a TSV file and a FASTA file...\n" 1>&2
echo -e "Sequence_ID\tSequence\tLength\tScore\tPrediction\tCharge\tAttention" >$outdir/AMPlify_results.tsv
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
	echo ">$seq_id length=$len score=$score prediction=$pred charge=$pepcharge" >>$outdir/AMPlify_results.faa
	echo "$sequence" >>$outdir/AMPlify_results.faa

	echo -e "$seq_id\t$sequence\t$len\t$score\t$pred\t$pepcharge\t$attn" >>$outdir/AMPlify_results.tsv
done <$file

header=$(head -n1 $outdir/AMPlify_results.tsv)
input_count=$(grep -c '^>' $input || true)
echo "Input sequences: $input" 1>&2
echo -e "Number of input sequences: $(printf "%'d" $input_count)\n" 1>&2

echo "PROGRAM: $(command -v $RUN_SEQTK)" 1>&2
seqtk_version=$($RUN_SEQTK 2>&1 || true)
echo -e "VERSION: $(echo "$seqtk_version" | awk '/Version:/ {print $NF}')\n" 1>&2
### 1 - Filter all sequences for those that are labelled AMP
#----------------------------------------------------------
echo "Filtering for those sequences labelled 'AMP' by AMPlify..." 1>&2
echo "$header" >$outdir/AMPlify_results.amps.tsv
echo -e "COMMAND: awk -F \"\\\t\" '{if(\$5==\"AMP\") print}' <(tail -n +2 $outdir/AMPlify_results.tsv) >> $outdir/AMPlify_results.amps.tsv\n" 1>&2
awk -F "\t" '{if($5=="AMP") print}' <(tail -n +2 $outdir/AMPlify_results.tsv) >>$outdir/AMPlify_results.amps.tsv

echo "Converting those sequences to FASTA format..." 1>&2
# 4th field is prediction, and 1st field is sequence ID:
echo -e "COMMAND: $RUN_SEQTK subseq $outdir/AMPlify_results.faa <(awk -F \"\\\t\" '{if(\$5==\"AMP\") print \$1}' <(tail -n +2 $outdir/AMPlify_results.tsv)) > ${outfile} || true\n" 1>&2
$RUN_SEQTK subseq $outdir/AMPlify_results.faa <(awk -F "\t" '{if($5=="AMP") print $1}' <(tail -n +2 $outdir/AMPlify_results.tsv)) >${outfile} || true

if [[ -s ${outfile} || $(grep -c '^>' $outfile) -gt 1 ]]; then
	echo "Removing duplicate sequences..." 1>&2
	$ROOT_DIR/scripts/run-cdhit.sh -o ${outfile_nr} -s 1.0 -t 8 ${outfile}
	echo 1>&2

	echo "Filtering for those resulting unique sequences in the AMPlify results..." 1>&2
	echo "$header" >$outdir/AMPlify_results.amps.nr.tsv
	echo -e "COMMAND: grep -Fwf <(grep '^>' ${outfile_nr} | tr -d '>') $outdir/AMPlify_results.amps.tsv >> $outdir/AMPlify_results.amps.nr.tsv\n" 1>&2
	grep -Fwf <(grep '^>' ${outfile_nr} | tr -d '>') $outdir/AMPlify_results.amps.tsv >>$outdir/AMPlify_results.amps.nr.tsv || true
else
	cp $outfile $outfile_nr
fi

echo "SUMMARY" 1>&2
print_line

count=$(grep -c '^>' ${outfile_nr} || true)
{
	echo "Output: ${outfile_nr}"
	echo "Number of unique AMPs: $(printf "%'d" $count)"
} 1>&2

print_line
echo 1>&2
#----------------------------------------------------------

### 2 - Filter all sequences for those with AMPlify score >= $confidence
#--------------------------------------------------------------------
echo "Filtering for sequences with an AMPlify score >= $confidence..." 1>&2
echo "$header" >$outdir/AMPlify_results.conf.tsv
echo -e "COMMAND: awk -F \"\\\t\" -v var=$confidence '{if(\$4>=var) print}' <(tail -n +2 $outdir/AMPlify_results.tsv) >> $outdir/AMPlify_results.conf.tsv\n" 1>&2
awk -F "\t" -v var=$confidence '{if($4>=var) print}' <(tail -n +2 $outdir/AMPlify_results.tsv) >>$outdir/AMPlify_results.conf.tsv

echo "Converting those sequences to FASTA format..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq $outdir/AMPlify_results.faa <(awk -F \"\\\t\" -v var=$confidence '{if(\$4>=var) print \$1}' <(tail -n +2 $outdir/AMPlify_results.tsv)) > ${outfile_conf}\n" 1>&2
$RUN_SEQTK subseq $outdir/AMPlify_results.faa <(awk -F "\t" -v var=$confidence '{if($4>=var) print $1}' <(tail -n +2 $outdir/AMPlify_results.tsv)) >${outfile_conf}

if [[ -s ${outfile_conf} || $(grep -c '^>' $outfile_conf) -gt 1 ]]; then
	echo "Removing duplicate sequences..." 1>&2
	$ROOT_DIR/scripts/run-cdhit.sh -o ${outfile_conf_nr} -s 1.0 -t 8 ${outfile_conf}
	echo 1>&2

	echo "Filtering for those resulting unique sequences in the AMPlify results..." 1>&2
	echo "$header" >$outdir/AMPlify_results.conf.nr.tsv
	echo -e "COMMAND: grep -Fwf <(grep '^>' ${outfile_conf_nr} | tr -d '>') $outdir/AMPlify_results.conf.tsv >> $outdir/AMPlify_results.conf.nr.tsv\n" 1>&2
	grep -Fwf <(grep '^>' ${outfile_conf_nr} | tr -d '>') $outdir/AMPlify_results.conf.tsv >>$outdir/AMPlify_results.conf.nr.tsv || true
else
	cp $outfile_conf $outfile_conf_nr
fi

echo "SUMMARY" 1>&2
print_line

count_conf=$(grep -c '^>' ${outfile_conf_nr} || true)
{
	echo "Output: ${outfile_conf_nr}"
	echo "Number of high-confidence (score >= $confidence) unique AMPs: $(printf "%'d" ${count_conf})"
} 1>&2

print_line
echo 1>&2
#--------------------------------------------------------------------

### 3 - Filter all sequences for those labelled 'AMP' and length <= $length
#--------------------------------------------------------------------
echo "Filtering for those sequences labelled 'AMP' by AMPlify and with length <= $length..." 1>&2
echo "$header" >$outdir/AMPlify_results.short.tsv
echo -e "COMMAND: awk -F \"\\\t\" -v var=$length '{if(\$3<=var && \$5==\"AMP\") print }' <(tail -n +2 $outdir/AMPlify_results.tsv) >> $outdir/AMPlify_results.short.tsv\n" 1>&2
awk -F "\t" -v var=$length '{if($3<=var && $5=="AMP") print }' <(tail -n +2 $outdir/AMPlify_results.tsv) >>$outdir/AMPlify_results.short.tsv

echo "Converting those sequences into FASTA format..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq $outdir/AMPlify_results.faa <(awk -F \"\\\t\" -v var=$length '{if(\$3<=var && \$5==\"AMP\") print \$1}' <(tail -n +2 $outdir/AMPlify_results.tsv)) > ${outfile_short}\n" 1>&2
$RUN_SEQTK subseq $outdir/AMPlify_results.faa <(awk -F "\t" -v var=$length '{if($3<=var && $5=="AMP") print $1}' <(tail -n +2 $outdir/AMPlify_results.tsv)) >${outfile_short}

if [[ -s ${outfile_short} || $(grep -c '^>' ${outfile_short}) -gt 1 ]]; then
	echo "Removing duplicate sequences..." 1>&2
	$ROOT_DIR/scripts/run-cdhit.sh -o ${outfile_short_nr} -s 1.0 -t 8 ${outfile_short}
	echo 1>&2

	echo "Filtering for those resulting unique sequences in the AMPlify results..." 1>&2
	echo "$header" >$outdir/AMPlify_results.short.nr.tsv
	echo -e "COMMAND: grep -Fwf <(grep '^>' ${outfile_short_nr} | tr -d '>') $outdir/AMPlify_results.short.tsv >> $outdir/AMPlify_results.short.nr.tsv\n" 1>&2
	grep -Fwf <(grep '^>' ${outfile_short_nr} | tr -d '>') $outdir/AMPlify_results.short.tsv >>$outdir/AMPlify_results.short.nr.tsv || true
else
	cp $outfile_short $outfile_short_nr
fi

echo "SUMMARY" 1>&2
print_line

count_short=$(grep -c '^>' ${outfile_short_nr} || true)
{
	echo "Output: ${outfile_short_nr}"
	echo "Number of short (length <= $length) unique AMPs: $(printf "%'d" ${count_short})"
} 1>&2

print_line
echo 1>&2

### 4 - Filter all sequences labelled 'AMP' and have charge >= $charge
#--------------------------------------------------------------------
echo "Filtering for those sequences labelled 'AMP' by AMPlify and with charge >= ${charge}..." 1>&2
echo "$header" >$outdir/AMPlify_results.charge.tsv
echo -e "COMMAND: awk -F \"\\\t\" -v var=$charge '{if(\$6>=var && \$5==\"AMP\") print }' <(tail -n +2 $outdir/AMPlify_results.tsv) >> $outdir/AMPlify_results.charge.tsv\n" 1>&2
awk -F "\t" -v var=$charge '{if($6>=var && $5=="AMP") print }' <(tail -n +2 $outdir/AMPlify_results.tsv) >>$outdir/AMPlify_results.charge.tsv

echo "Converting those sequences into FASTA format..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq $outdir/AMPlify_results.faa <(awk -F \"\\\t\" -v var=$charge '{if(\$6>=var && \$5==\"AMP\") print \$1}' <(tail -n +2 $outdir/AMPlify_results.tsv)) > $outfile_charge\n" 1>&2
$RUN_SEQTK subseq $outdir/AMPlify_results.faa <(awk -F "\t" -v var=$charge '{if($6>=var && $5=="AMP") print $1}' <(tail -n +2 $outdir/AMPlify_results.tsv)) >${outfile_charge}

if [[ -s $outfile_charge || $(grep -c '^>' $outfile_charge) -gt 1 ]]; then
	echo "Removing duplicate sequences..." 1>&2
	$ROOT_DIR/scripts/run-cdhit.sh -o ${outfile_charge_nr} -s 1.0 -t 8 ${outfile_charge}
	echo 1>&2

	echo "Filtering for those resulting unique sequences in the AMPlify results..." 1>&2
	echo "$header" >$outdir/AMPlify_results.charge.nr.tsv
	echo -e "COMMAND: grep -Fwf <(grep '^>' ${outfile_charge_nr} | tr -d '>') $outdir/AMPlify_results.charge.tsv >> $outdir/AMPlify_results.charge.nr.tsv\n" 1>&2
	grep -Fwf <(grep '^>' ${outfile_charge_nr} | tr -d '>') $outdir/AMPlify_results.charge.tsv >>$outdir/AMPlify_results.charge.nr.tsv || true
else
	cp $outfile_charge $outfile_charge_nr
fi

echo "SUMMARY" 1>&2
print_line

count_charge=$(grep -c '^>' ${outfile_charge_nr} || true)
{
	echo "Output: ${outfile_charge_nr}"
	echo "Number of positive (charge >= $charge) unique AMPs: $(printf "%'d" ${count_charge})"
} 1>&2

print_line
echo 1>&2
#--------------------------------------------------------------------

### 5 - Filter all sequences for those AMPlify score >= $confidence and have charge >= $charge
#--------------------------------------------------------------------
echo "Filtering for those sequences with AMPlify score >= $confidence and with charge >= ${charge}..." 1>&2
echo "$header" >$outdir/AMPlify_results.conf.charge.tsv
echo -e "COMMAND: awk -F \"\\\t\" -v var=$charge -v c=$confidence'{if(\$6>=var && \$4>=c) print }' <(tail -n +2 $outdir/AMPlify_results.tsv) >> $outdir/AMPlify_results.conf.charge.tsv\n" 1>&2
awk -F "\t" -v var=$charge -v c=$confidence '{if($6>=var && $4>=c) print }' <(tail -n +2 $outdir/AMPlify_results.tsv) >>$outdir/AMPlify_results.conf.charge.tsv

echo "Converting those sequences into FASTA format..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq $outdir/AMPlify_results.faa <(awk -F \"\\\t\" -v var=$charge -v c=$confidence '{if(\$6>=var && \$4>=c) print \$1}' <(tail -n +2 $outdir/AMPlify_results.tsv)) > $outfile_conf_charge\n" 1>&2
$RUN_SEQTK subseq $outdir/AMPlify_results.faa <(awk -F "\t" -v var=$charge -v c=$confidence '{if($6>=var && $4>=c) print $1}' <(tail -n +2 $outdir/AMPlify_results.tsv)) >${outfile_conf_charge}

if [[ -s $outfile_conf_charge || $(grep -c '^>' $outfile_conf_charge) -gt 1 ]]; then
	echo "Removing duplicate sequences..." 1>&2
	$ROOT_DIR/scripts/run-cdhit.sh -o ${outfile_conf_charge_nr} -s 1.0 -t 8 ${outfile_conf_charge}
	echo 1>&2

	echo "Filtering for those resulting unique sequences in the AMPlify results..." 1>&2
	echo "$header" >$outdir/AMPlify_results.conf.charge.nr.tsv
	echo -e "COMMAND: grep -Fwf <(grep '^>' ${outfile_conf_charge_nr} | tr -d '>') $outdir/AMPlify_results.conf.charge.tsv >> $outdir/AMPlify_results.conf.charge.nr.tsv\n" 1>&2
	grep -Fwf <(grep '^>' ${outfile_conf_charge_nr} | tr -d '>') $outdir/AMPlify_results.conf.charge.tsv >>$outdir/AMPlify_results.conf.charge.nr.tsv || true
else
	cp $outfile_conf_charge $outfile_conf_charge_nr
fi

echo "SUMMARY" 1>&2
print_line

count_conf_charge=$(grep -c '^>' ${outfile_conf_charge_nr} || true)
{
	echo "Output: ${outfile_conf_charge_nr}"
	echo "Number of confident (score >= $confidence) and positive (charge >= $charge) unique AMPs: $(printf "%'d" ${count_conf_charge})"
} 1>&2

print_line
echo 1>&2
#--------------------------------------------------------------------

#--------------------------------------------------------------------
### 6 - Filter all sequences for those with AMPlify score >= $confidence and length <= $length
#--------------------------------------------------------------------
echo "Filtering for those sequences with length <= $length and AMPlify score >= ${confidence}..." 1>&2
echo "$header" >$outdir/AMPlify_results.conf.short.tsv
echo -e "COMMAND: awk -F \"\\\t\" -v l=$length -v c=$confidence '{if(\$3<=l && \$4>=c) print}' <(tail -n +2 $outdir/AMPlify_results.tsv) >> $outdir/AMPlify_results.conf.short.tsv\n" 1>&2
awk -F "\t" -v l=$length -v c=$confidence '{if($3<=l && $4>=c) print}' <(tail -n +2 $outdir/AMPlify_results.tsv) >>$outdir/AMPlify_results.conf.short.tsv

echo "Converting those sequences to FASTA format..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq $outdir/AMPlify_results.faa <(awk -F \"\\\t\" -v l=$length -v c=$confidence '{if(\$3<=l && \$4>=c) print \$1}' <(tail -n +2 $outdir/AMPlify_results.tsv)) > ${outfile_conf_short}\n" 1>&2
$RUN_SEQTK subseq $outdir/AMPlify_results.faa <(awk -F "\t" -v l=$length -v c=$confidence '{if($3<=l && $4>=c) print $1}' <(tail -n +2 $outdir/AMPlify_results.tsv)) >${outfile_conf_short}

if [[ -s $outfile_conf_short || $(grep -c '^>' $outfile_conf_short) -gt 1 ]]; then
	echo "Removing duplicate sequences..." 1>&2
	$ROOT_DIR/scripts/run-cdhit.sh -o ${outfile_conf_short_nr} -s 1.0 -t 8 ${outfile_conf_short}
	echo 1>&2

	echo "Filtering for those resulting unique sequences in the AMPlify results..." 1>&2
	echo "$header" >$outdir/AMPlify_results.conf.short.nr.tsv
	echo -e "COMMAND: grep -Fwf <(grep '^>' ${outfile_conf_short_nr} | tr -d '>') $outdir/AMPlify_results.conf.short.tsv >> $outdir/AMPlify_results.conf.short.nr.tsv\n" 1>&2
	grep -Fwf <(grep '^>' ${outfile_conf_short_nr} | tr -d '>') $outdir/AMPlify_results.conf.short.tsv >>$outdir/AMPlify_results.conf.short.nr.tsv || true
else
	cp $outfile_conf_short $outfile_conf_short_nr
fi
echo "SUMMARY" 1>&2
print_line

count_conf_short=$(grep -c '^>' ${outfile_conf_short_nr} || true)
{
	echo "Output: ${outfile_conf_short_nr}"
	echo "Number of short (length <= $length) and high-confidence (score >= $confidence) unique AMPs: $(printf "%'d" ${count_conf_short})"
} 1>&2

print_line
echo 1>&2
#--------------------------------------------------------------------

#--------------------------------------------------------------------
### 7 - Filter all sequences for those with charge >= $charge and length <= $length
#--------------------------------------------------------------------
echo "Filtering for those sequences with length <= $length and charge >= ${charge}..." 1>&2
echo "$header" >$outdir/AMPlify_results.short.charge.tsv
echo -e "COMMAND: awk -F \"\\\t\" -v l=$length -v c=$charge '{if(\$3<=l && \$6>=c) print}' <(tail -n +2 $outdir/AMPlify_results.tsv) >> $outdir/AMPlify_results.short.charge.tsv\n" 1>&2
awk -F "\t" -v l=$length -v c=$charge '{if($3<=l && $6>=c) print}' <(tail -n +2 $outdir/AMPlify_results.tsv) >>$outdir/AMPlify_results.short.charge.tsv

echo "Converting those sequences to FASTA format..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq $outdir/AMPlify_results.faa <(awk -F \"\\\t\" -v l=$length -v c=$charge '{if(\$3<=l && \$6>=c) print \$1}' <(tail -n +2 $outdir/AMPlify_results.tsv)) > ${outfile_short_charge}\n" 1>&2
$RUN_SEQTK subseq $outdir/AMPlify_results.faa <(awk -F "\t" -v l=$length -v c=$charge '{if($3<=l && $6>=c) print $1}' <(tail -n +2 $outdir/AMPlify_results.tsv)) >${outfile_short_charge}

if [[ -s $outfile_short_charge || $(grep -c '^>' $outfile_short_charge) -gt 1 ]]; then
	echo "Removing duplicate sequences..." 1>&2
	$ROOT_DIR/scripts/run-cdhit.sh -o ${outfile_short_charge_nr} -s 1.0 -t 8 ${outfile_short_charge}
	echo 1>&2

	echo "Filtering for those resulting unique sequences in the AMPlify results..." 1>&2
	echo "$header" >$outdir/AMPlify_results.short.charge.nr.tsv
	echo -e "COMMAND: grep -Fwf <(grep '^>' ${outfile_short_charge_nr} | tr -d '>') $outdir/AMPlify_results.short.charge.tsv >> $outdir/AMPlify_results.short.charge.nr.tsv\n" 1>&2
	grep -Fwf <(grep '^>' ${outfile_short_charge_nr} | tr -d '>') $outdir/AMPlify_results.short.charge.tsv >>$outdir/AMPlify_results.short.charge.nr.tsv || true
else
	cp $outfile_short_charge $outfile_short_charge_nr
fi
echo "SUMMARY" 1>&2
print_line

count_short_charge=$(grep -c '^>' ${outfile_short_charge_nr} || true)
{
	echo "Output: ${outfile_short_charge_nr}"
	echo "Number of short (length <= $length) and positive (charge >= $charge) unique AMPs: $(printf "%'d" ${count_short_charge})"
} 1>&2

print_line
echo 1>&2
#--------------------------------------------------------------------

### 8 - Filter short and confident sequences for those with AMPlify score >= $confidence and length <= $length, and charge >= $charge
#--------------------------------------------------------------------
echo "Filtering for those sequences with charge >= $charge, length <= $length and AMPlify score >= ${confidence}..." 1>&2
echo "$header" >$outdir/AMPlify_results.conf.short.charge.tsv
echo -e "COMMAND: awk -F \"\\\t\" -v l=$length -v c=$confidence -v p=$charge '{if(\$3<=l && \$4>=c && \$6>=p) print}' <(tail -n +2 $outdir/AMPlify_results.tsv) >> $outdir/AMPlify_results.conf.short.charge.tsv\n" 1>&2
awk -F "\t" -v l=$length -v c=$confidence -v p=$charge '{if($3<=l && $4>=c && $6>=p) print}' <(tail -n +2 $outdir/AMPlify_results.tsv) >>$outdir/AMPlify_results.conf.short.charge.tsv

echo "Converting those sequences to FASTA format..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq $outdir/AMPlify_results.faa <(awk -F \"\\\t\" -v l=$length -v c=$confidence -v p=$charge '{if(\$3<=l && \$4>=c && \$6>=p) print \$1}' <(tail -n +2 $outdir/AMPlify_results.tsv)) > ${outfile_conf_short_charge}\n" 1>&2
$RUN_SEQTK subseq $outdir/AMPlify_results.faa <(awk -F "\t" -v l=$length -v c=$confidence -v p=$charge '{if($3<=l && $4>=c && $6>=p) print $1}' <(tail -n +2 $outdir/AMPlify_results.tsv)) >${outfile_conf_short_charge}

if [[ -s $outfile_conf_short_charge || $(grep -c '^>' $outfile_conf_short_charge) -gt 1 ]]; then
	echo "Removing duplicate sequences..." 1>&2
	$ROOT_DIR/scripts/run-cdhit.sh -o ${outfile_conf_short_charge_nr} -s 1.0 -t 8 ${outfile_conf_short_charge}
	echo 1>&2

	echo "Filtering for those resulting unique sequences in the AMPlify results..." 1>&2
	echo "$header" >$outdir/AMPlify_results.conf.short.charge.nr.tsv
	echo -e "COMMAND: grep -Fwf <(grep '^>' ${outfile_conf_short_charge_nr} | tr -d '>') $outdir/AMPlify_results.conf.short.charge.tsv >> $outdir/AMPlify_results.conf.short.charge.nr.tsv\n" 1>&2
	grep -Fwf <(grep '^>' ${outfile_conf_short_charge_nr} | tr -d '>') $outdir/AMPlify_results.conf.short.charge.tsv >>$outdir/AMPlify_results.conf.short.charge.nr.tsv || true
else
	cp $outfile_conf_short_charge $outfile_conf_short_charge_nr
fi

echo "SUMMARY" 1>&2
print_line

count_conf_short_charge=$(grep -c '^>' ${outfile_conf_short_charge_nr} || true)
{
	echo "Output: ${outfile_conf_short_charge_nr}"
	echo "Number of positive (charge >= $charge), short (length <= $length), and high-confidence (score >= $confidence) unique AMPs: $(printf "%'d" ${count_conf_short_charge})"
} 1>&2

print_line
echo 1>&2
#--------------------------------------------------------------------

echo "FINAL SUMMARY" 1>&2
print_line

echo -e "\
	File\tDescription\n \
	----\t-----------\n \
	AMPlify_results.txt\traw AMPlify results\n \
	AMPlify_results.tsv\traw AMPlify results parsed into a TSV\n \
	AMPlify_results.faa\tsequences of raw AMPlify results with new headers\n \
	$(basename $outfile_nr)\tnon-redundant sequences in AMPlify results labelled 'AMP'\n \
	$(basename $outfile_conf_nr)\tnon-redundant sequences in AMPlify results with score >= $confidence\n \
	$(basename $outfile_short_nr)\tnon-redundant sequences labelled 'AMP' with length <= $length\n \
	$(basename $outfile_charge_nr)\tnon-redundant sequences labelled 'AMP' with charge >= $charge\n \
	$(basename $outfile_conf_charge_nr)\tnon-redundant sequences in AMPlify results with score >= $confidence and charge >= $charge\n \
	$(basename $outfile_conf_short_nr)\tnon-redundant sequences in AMPlify results with score >= $confidence and length <= $length\n \
	$(basename $outfile_short_charge_nr)\tnon-redundant sequences in AMPlify results with length <= $length and charge >= $charge\n \
	$(basename $outfile_conf_short_charge_nr)\tnon-redundant sequences in AMPlify results with charge >= $charge, score >= $confidence, and length <= $length\n \
	" | column -s $'\t' -t 1>&2
echo 1>&2
echo -e "\
	File\tAMP Count\n \
	----\t-----------\n \
	$(basename $outfile_nr)\t$count\n \
	$(basename $outfile_conf_nr)\t$count_conf\n \
	$(basename $outfile_short_nr)\t$count_short\n \
	$(basename $outfile_charge_nr)\t$count_charge\n \
	$(basename $outfile_conf_charge_nr)\t$count_conf_charge\n \
	$(basename $outfile_conf_short_nr)\t$count_conf_short\n \
	$(basename $outfile_conf_short_nr)\t$count_short_charge\n \
	$(basename $outfile_conf_short_charge_nr)\t$count_conf_short_charge\n \
	" | column -s $'\t' -t 1>&2
print_line
echo 1>&2

touch $outdir/AMPLIFY.DONE

if [[ "$email" = true ]]; then
	org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	echo "$outdir" | mail -s "Successful AMPlify run on $org" $address
	echo "Email alert sent to $address." 1>&2
fi

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
end_sec=$(date '+%s')

$ROOT_DIR/scripts/get-runtime.sh -T $start_sec $end_sec 1>&2
echo 1>&2
echo "STATUS: complete." 1>&2
