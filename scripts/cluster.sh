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
		\tSelects AMPs for synthesis by "SpeciesCount", "TopInsect", and "TopAMPlifyCluster".\n \
		\n \
		\tOUTPUT:\n \
		\t-------\n \
		\t  - AMPsForSynthesis.tsv\n \
		\t  - OneEachCluster.tsv\n \
		\t  - ThreeEachCluster.tsv\n \
		\n \
		\tEXIT CODES:\n \
		\t-----------\n \
		\t  - 0: successfully completed\n \
		\t  - 1: general errors\n \
		\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-o <outdir>] [-c <int>] [-i <int>] [-C <int>] [-s <float>] [-n <int>] [-r <int>] <final annotation directory paths\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-h\tShow this help menu\n \
		\t-o <directory>\tOutput directory \n \
		\t-c <int>\tSpecies count (at least) threshold for SpeciesCount\n \
		\t-i <int>\tNumber of insect sequences to select for TopInsect\n \
		\t-C <int>\tSpecies count (at most) thresold for TopInsect\n \
		\t-s <float>\tAMPlify score threshold for TopInsect\n \
		\t-n <int>\tNumber of sequences to select for TopAMPlifyCluster\n \
		\t-r <int>\tNumber of arginines that is too hard to synthesize\n \
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
if [[ ! -v ROOT_DIR ]]; then
	print_error "ROOT_DIR is unbound. Please export ROOT_DIR=/path/to/rAMPage/GitHub/directory."
else
	outdir=$ROOT_DIR
fi

species_count=3
num_insects=30
insect_species_count=1
insect_score=0.99
num_seq_clusters=30
too_many_rs=5

while getopts :ho:c:i:C:s:n:r: opt; do
	case $opt in
		h) get_help ;;
		o) outdir=$OPTARG;;
		c) species_count=$OPTARG;;
		i) num_insects=$OPTARG;;
		C) insect_species_count=$OPTARG;;
		s) insect_score=$OPTARG;;
		n) num_seq_clusters=$OPTARG;;
		r) too_many_rs=$OPTARG;;
		\?) print_error "Invalid option: -$OPTARG";;
	esac
done

shift $((OPTIND-1))

# 5 - wrong arguments given
if [[ "$#" -eq 0 ]]; then
	print_error "Incorrect number of arguments."
fi

fastas=()
for i in "$@"; do
	if [[ -s "$(realpath $i)/annotated.nr.faa" ]]; then
		fastas+=( $(realpath $i)/annotated.nr.faa )
	else
		print_error "File $(realpath $i)/annotated.nr.faa is empty or does not exist!"
	fi
done
# fastas=$(for i in "$@"; do echo $(realpath $i)/annotated.nr.faa; done)
# fastas=$(for i in "$@"; do realpath $i; done)

# create unique clusters
cat $fastas >$outdir/annotated.faa
$ROOT_DIR/scripts/run-cdhit.sh -d -f $outdir/annotated.faa
cluster_tsv=$outdir/annotated.rmdup.nr.faa.clstr.tsv
fasta=$outdir/annotated.rmdup.nr.faa

# get annotations and filter for the unique sequences
file1=$(realpath $1)/final_annotation.tsv
if [[ ! -s $file1 ]]; then
	print_error "File $file1 is empty or does not exist!"
fi
shift

tsvs=( $file1 )
for i in "$@"; do
	if [[ ! -s "$(realpath $i)/final_annotation.tsv" ]]; then
		print_error "File $(realpath $i)/final_annotation.tsv is empty or does not exist!"
	else
		tsvs+=( $(realpath $i)/final_annotation.tsv )
	fi
done

# tsvs=$(for i in "$@"; do echo $(realpath $i)/final_annotation.tsv; done)

(cat $file1 && tail -n +2 -q $tsvs) >$outdir/final_annotation.tsv
grep -wf <(awk '/^>/ {print $1}' $outdir/annotated.rmdup.nr.faa.clstr.tsv | tr -d '>') $outdir/final_annotation.tsv >$outdir/final_annotation.rmdup.nr.tsv

# summarize using mlr

# calculate species count
awk -F "\t" 'BEGIN{OFS="\t"; print "Cluster", "Sequence ID", "Species"}{if($3=="rep") print $1, $NF}' $cluster_tsv >$outdir/cluster.seqid.tsv

awk -F "\t" 'BEGIN{OFS="\t"; print "Cluster", "Species"}{split($NF,arr,"-"); print $1, arr[1]}' <(tail -n +2 $cluster_tsv) | tail -n +2 | sort -k1,1g | uniq | mlr --tsv --implicit-csv-header label Cluster,Species > | mlr --tsv stats1 -g Cluster -a count -f Species | mlr --tsv rename "Species_count,Species Count" >$outdir/count.species.tsv

# count clusters
mlr --tsv stats1 -g Cluster -a count -f "Sequence ID" $cluster_tsv | mlr --tsv rename "Sequence ID_count,n" >$outdir/count.clusters.tsv

# add species information for the seqids remaining after clustering???
#> $ROOT_DIR/seqid.species.tsv

# join with annotation
mlr --tsv join -f $outdir/count.clusters.tsv -j "Cluster" count.species.tsv | mlr --tsv join -f $outdir/cluster.seqid.tsv -j "Cluster" | mlr --tsv join -f $outdir/final_annotation.rmdup.nr.tsv -l "Sequence_ID" -r "Sequence ID" -j "Sequence_ID" | mlr --tsv reorder -f 'n,Species Count,Cluster,Class,Sequence_ID,Sequence,Score,Length,Charge,Top Precursor,Top Mature' | mlr --tsv sort -nr "n,Species Count" >$outdir/summarized_annotation.rmdup.nr.tsv

# summarized_annotation.rmdup.nr.tsv with only necessary columns will be OneFromEachCluster for Species Count
(cd $outdir && ln -s summarized_annotation.rmdup.nr.tsv OneEachCluster.tsv)

# create 95p clusters
percent=95
$ROOT_DIR/scripts/run-cdhit.sh -f -s 0.${percent} $fasta

cluster95_fasta=$outdir/annotated.rmdup.${percent}.nr.faa
cluster95_tsv=$outdir/annotated.rmdup.${percent}.nr.faa.clstr.tsv

sub_outdir=$outdir/clusters
mkdir -p $sub_outdir/msa/logs
rm -f $outdir/ThreeEachCluster.faa

if [[ ! -v CLUSTALO ]]; then
	if command -v clustalo &>/dev/null; then
		RUN_EFETCH=$(command -v clustalo)
	else
		print_error "CLUSTALO is unbound and no 'clustalo' found in PATH. Please export RUN_EFETCH=/path/to/clustalo/executable."
	fi
elif ! command -v $CLUSTALO &>/dev/null; then
	print_error "Unable to execute $CLUSTALO."
fi

for i in $(cut -f3 -d$'\t' $cluster95_tsv | tail -n +2 | sort -gu); do
	seqtk subseq $fasta <(awk -v var="$i" -F "\t" '{if($1==var) print $NF}' $cluster95_tsv | sort -k2,2g | cut -d' ' -f1) >$sub_outdir/cluster${i}_${percent}p.faa

	if [[ "$(grep -c '^>' $sub_outdir/cluster${i}.${percent}p.faa)" -ge 4 ]]; then

		$CLUSTALO -i $sub_outdir/cluster${i}.${percent}p.faa --full --log=$sub_outdir/msa/logs/cluster${i}.${percent}p.clustalo.log -o $sub_outdir/msa/cluster${i}.${percent}p.clustalo.faa --outfmt=fasta --output-order=tree-order --seqtype=Protein --infmt=fasta --iter=5 --full-iter --wrap=200 --force

		{
			head -n4 $sub_outdir/msa/cluster${i}.${percent}p.clustalo.faa && tail -n2 $sub_outdir/msa/cluster${i}.${percent}p.clustalo.faa
		} | sed "/^>/ s/$/ cluster_id=${i}/" >>$outdir/ThreeEachCluster.faa
	else
		cat $sub_outdir/cluster${i}.${percent}p.faa >> $outdir/ThreeEachCluster.faa
	fi
done

sed -i '/^>/! s/-//g' $outdir/ThreeEachCluster.faa
grep -Fwf <(awk '/^>/ {print $1}' $outdir/ThreeEachCluster.faa | tr -d '>') $outdir/OneEachCluster.tsv > $outdir/ThreeEachCluster.tsv

Rscript $ROOT_DIR/scripts/SelectForSynthesis.R --one_each_cluster=$outdir/OneEachCluster.tsv --three_each_cluster=$outdir/ThreeEachCluster.tsv --output_dir=$outdir