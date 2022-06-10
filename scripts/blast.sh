#!/usr/bin/env bash
set -uo pipefail

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
		\tCharacterizes the novelty of AMPs using BLASTp.\n \
		\n \
		\tOUTPUT:\n \
		\t-------\n \
		\t  - amps.blast.summary.novel.final.tsv\n \
		\t  - amps.blast.summary.known.final.tsv\n \
		\n \
		\tEXIT CODES:\n \
		\t-----------\n \
		\t  - 0: successfully completed\n \
		\t  - 1: general errors\n \
		\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
        \t$PROGRAM [-o <outdir>] [-t <int>] -f <rAMPage AMPlify TSV> -d <preformatted BLAST nr database> <AMP FASTA file>\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
        \t-b <BLAST executable>\tPath to BLAST executable if not in PATH\n \
        \t-d <database>\tPre-fromatted BLAST nr database\t(e.g. /path/to/nr)\n \
        \t-f <TSV file>\trAMPage AMPlify TSV\t(NOTE: Must be rAMPage's AMPlify output for headers to match)\n \
		\t-h\tShow this help menu\n \
		\t-o <directory>\tOutput directory\n \
        \t-t <int>\tNumber of threads\t(default = 8)\n \
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


# 4 - default parameters
outdir=$(pwd)
num_threads=8

if ! command -v blastp &>/dev/null; then
    RUN_BLASTP=""
else
    RUN_BLASTP=$(command -v blastp)
fi

while getopts :d:f:ho:t:b: opt; do
    case $opt in 
    b) RUN_BLASTP=$(realpath $OPTARG);;
    d) database=$(realpath $OPTARG);;
    f) amplify=$(realpath $OPTARG) ;;
    h) get_help ;;
    o) outdir=$(realpath $OPTARG) ;;
    t) num_threads=$OPTARG ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
    esac
done

shift $((OPTIND-1))

# 5 - wrong arguments given
if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 - check inputs


if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) is empty."
fi

{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"
	echo "CALL: $args (wd: $(pwd))"
    echo "THREADS: $num_threads"
	echo
} 1>&2

mkdir -p $outdir

infile=$(realpath $1)

# sort the files into those <= 30 and those > 30
$RUN_BLASTP -version 2>&1 || exit 1

# blast it against NR database
seqtk comp $infile > $outdir/seqtk.comp.txt

seqtk subseq $infile <(awk '{if($2>30) print $1}' $outdir/seqtk.comp.txt) > $outdir/amps.gt30.faa
seqtk subseq $infile <(awk '{if($2<=30) print $1}' $outdir/seqtk.comp.txt) > $outdir/amps.short.faa

# blast it against NR database
echo "Running BLASTp..." 1>&2
 $RUN_BLASTP -db $database -query $outdir/amps.gt30.faa -out $outdir/amps.gt30.tsv -task blastp -outfmt '6 qaccver saccver stitle pident length mismatch gapopen qstart qend sstart send evalue bitscore qcovs' -num_threads $num_threads &> $outdir/blastp.log &
 $RUN_BLASTP -db $database -query $outdir/amps.short.faa -out $outdir/amps.short.tsv -task blastp-short -outfmt '6 qaccver saccver stitle pident length mismatch gapopen qstart qend sstart send evalue bitscore qcovs' -num_threads $num_threads &> $outdir/blastp-short.log &

wait
# add headers to combined blast

echo "Finished running BLASTP." 1>&2
echo "qaccver saccver stitle pident length mismatch gapopen qstart qend sstart send evalue bitscore qcovs" | sed 's/ /\t/g' > $outdir/amps.blast.tsv
cat $outdir/amps.gt30.tsv $outdir/amps.short.tsv >> $outdir/amps.blast.tsv

echo "Known AMPs (100% pident and 100% qcovs) written to $outdir/known.txt and $outdir/known.faa" 1>&2
awk -F "\t" '{if($4==100 && $NF==100) print $1}' $outdir/amps.blast.tsv | sort -u > $outdir/known.txt

echo "Novel AMPs written to $outdir/novel.txt and $outdir/novel.faa" 1>&2
grep -vwf $outdir/known.txt <(awk '{print $1}' $outdir/seqtk.comp.txt) > $outdir/novel.txt

seqtk subseq $infile $outdir/known.txt > $outdir/known.faa
seqtk subseq $infile $outdir/novel.txt > $outdir/novel.faa

echo "qaccver saccver stitle pident qcovs" | sed 's/ /\t/g' > $outdir/amps.blast.novel.tsv
grep -wf $outdir/novel.txt $outdir/amps.blast.tsv | cut -f1-4,14 -d $'\t'>> $outdir/amps.blast.novel.tsv
echo "qaccver saccver stitle pident qcovs" | sed 's/ /\t/g' > $outdir/amps.blast.known.tsv
grep -wf $outdir/known.txt $outdir/amps.blast.tsv | cut -f1-4,14 -d$'\t' >> $outdir/amps.blast.known.tsv

# take top one for each JIRA ticket summary, and AMPlify results combination
echo "qaccver saccver stitle pident qcovs" | sed 's/ /\t/g' > $outdir/amps.blast.summary.novel.tsv
while read line; do
    grep -w -m1 "$line" $outdir/amps.blast.tsv | cut -f1-4,14 -d $'\t' >> $outdir/amps.blast.summary.novel.tsv
done < $outdir/novel.txt

for i in $(grep -vwf <(awk '{print $1}' $outdir/amps.blast.novel.tsv) $outdir/novel.txt); do
    echo -e "$i\tNA\tNA\tNA\tNA" >> $outdir/amps.blast.summary.novel.tsv
done

seqtk subseq $infile <(grep -vwf <(awk '{print $1}' $outdir/amps.blast.novel.tsv) $outdir/novel.txt) > $outdir/no_hits.faa

echo "qaccver saccver stitle pident qcovs" | sed 's/ /\t/g' > $outdir/amps.blast.summary.known.tsv
while read line; do
    grep -w -m1 "$line" $outdir/amps.blast.tsv | cut -f1-4,14  -d $'\t' >> $outdir/amps.blast.summary.known.tsv
done < $outdir/known.txt

cut -f1-4,6 -d$'\t' $amplify > $outdir/temp.tsv
mlr --tsv join -f $outdir/amps.blast.summary.novel.tsv -l qaccver -r Sequence_ID -j Query $outdir/temp.tsv | mlr --tsv rename 'saacver,Hit,stitle,Description' \
    | awk -F "\t" 'BEGIN{OFS="\t"}{print $1, $6, $8, $7, $9, $2, $3, $4, $5}' > $outdir/amps.blast.summary.novel.final.tsv

mlr --tsv join -f $outdir/amps.blast.summary.known.tsv -l qaccver -r Sequence_ID -j Query $outdir/temp.tsv | mlr --tsv rename 'saacver,Hit,stitle,Description' \
    | awk -F "\t" 'BEGIN{OFS="\t"}{print $1, $6, $8, $7, $9, $2, $3, $4, $5}' > $outdir/amps.blast.summary.known.final.tsv

rm -f $outdir/temp.tsv
rm -f $outdir/seqtk.comp.txt

head -n1 $outdir/amps.blast.summary.novel.final.tsv > $outdir/amps.blast.summary.novel.final.ranked.tsv
sort -k3,3nr -t$'\t' <(tail -n +2 $outdir/amps.blast.summary.novel.final.tsv) >> $outdir/amps.blast.summary.novel.final.ranked.tsv

head -n1 $outdir/amps.blast.summary.known.final.tsv > $outdir/amps.blast.summary.known.final.ranked.tsv
sort -k3,3nr -t$'\t' <(tail -n +2 $outdir/amps.blast.summary.known.final.tsv) >> $outdir/amps.blast.summary.known.final.ranked.tsv

echo "Summary table written to $outdir/amps.blast.summary.novel.final.ranked.tsv and $outdir/amps.blast.summary.known.final.ranked.tsv" 1>&2
