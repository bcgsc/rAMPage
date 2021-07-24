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
		\t$PROGRAM [-o <outdir>] [-c <int>] [-i <int>] [-C <int>] [-s <float>] [-n <int>] [-r <int>] <final annotation directory paths>\n \
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

species_count="--species_count_threshold=3"
num_insects="--num_insects=30"
insect_species_count="--insect_species_count_threshold=1"
insect_score="--insect_score_threshold=0.99"
num_seq_clusters="--num_cluster_seqs=30"
too_many_rs="--too_many_Rs=5"

while getopts :ho:c:i:C:s:n:r: opt; do
	case $opt in
	h) get_help ;;
	o) outdir=$OPTARG ;;
	c) species_count="--species_count_threshold=$OPTARG" ;;
	i) num_insects="--num_insects=$OPTARG" ;;
	C) insect_species_count="--insect_species_count_threshold=$OPTARG" ;;
	s) insect_score="--insect_score_threshold=$OPTARG" ;;
	n) num_seq_clusters="--num_cluster_seqs=$OPTARG" ;;
	r) too_many_rs="--too_many_Rs=$OPTARG" ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

# 5 - wrong arguments given
if [[ "$#" -eq 0 ]]; then
	print_error "Incorrect number of arguments."
fi

fastas=()
for i in "$@"; do
	if [[ -s "$(realpath $i)/annotated.nr.faa" ]]; then
		fastas+=($(realpath $i)/annotated.nr.faa)
	else
		# print_error "File $(realpath $i)/annotated.nr.faa is empty or does not exist!"
		echo "WARNING: File $(realpath $i)/annotated.nr.faa is empty or does not exist! Skipped." 1>&2
	fi
done
# fastas=$(for i in "$@"; do echo $(realpath $i)/annotated.nr.faa; done)
# fastas=$(for i in "$@"; do realpath $i; done)

# create unique clusters
cat ${fastas[*]} >$outdir/annotated.faa
$ROOT_DIR/scripts/run-cdhit.sh -d -f $outdir/annotated.faa
cluster_tsv=$outdir/annotated.rmdup.nr.faa.clstr.tsv
fasta=$outdir/annotated.rmdup.nr.faa

# get annotations and filter for the unique sequences
tsvs=()
for i in "$@"; do
	if [[ ! -s "$(realpath $i)/final_annotation.tsv" ]]; then
		# print_error "File $(realpath $i)/final_annotation.tsv is empty or does not exist!"
		echo "WARNING: File $(realpath $i)/final_annotation.tsv is empty or does not exist! Skipped." 1>&2
	else
		tsvs+=($(realpath $i)/final_annotation.tsv)
	fi
done

# tsvs=$(for i in "$@"; do echo $(realpath $i)/final_annotation.tsv; done)
if [[ ${#tsvs[@]} -gt 1 ]]; then
	(cat ${tsvs[0]} && tail -n +2 -q "${tsvs[@]:1}") >$outdir/final_annotation.tsv
elif [[ ${#tsvs[@]} -eq 1 ]]; then
	# cp ${tsvs[0]} $outdir/final_annotation.tsv
	cd $outdir && ln -fs ${tsvs[0]} final_annotation.tsv
else
	print_error "ERROR: All files were skipped."
fi

if [[ "$(grep -c '^>' $outdir/annotated.faa)" -eq "$(grep -c '^>' $outdir/annotated.rmdup.nr.faa)" ]]; then
	# cp $outdir/annotated.rmdup.nr.faa $outdir/final_annotation.rmdup.nr.tsv
	cd $outdir && ln -fs final_annotation.tsv final_annotation.rmdup.nr.tsv
else
	grep -wf <(awk '/^>/ {print $1}' $outdir/annotated.rmdup.nr.faa | tr -d '>') $outdir/final_annotation.tsv >$outdir/final_annotation.rmdup.nr.tsv
fi

# summarize using mlr

# calculate species count
awk -F "\t" 'BEGIN{OFS="\t"; print "Cluster", "Sequence ID"}{if($3=="rep") print $1, $NF}' $cluster_tsv >$outdir/cluster.seqid.tsv

awk -F "\t" 'BEGIN{OFS="\t"; print "Cluster", "Species"}{split($NF,arr,"-"); print $1, arr[1]}' <(tail -n +2 $cluster_tsv) | tail -n +2 | sort -k1,1g | uniq | mlr --tsv --implicit-csv-header label Cluster,Species | mlr --tsv stats1 -g Cluster -a count -f Species | mlr --tsv rename "Species_count,Species Count" >$outdir/count.species.tsv

# count clusters
mlr --tsv stats1 -g Cluster -a count -f "Sequence ID" $cluster_tsv | mlr --tsv rename "Sequence ID_count,n" >$outdir/count.clusters.tsv

# add species information for the seqids remaining after clustering???
#> $ROOT_DIR/seqid.species.tsv

# join with annotation
mlr --tsv join -f $outdir/count.clusters.tsv -j "Cluster" $outdir/count.species.tsv | mlr --tsv join -f $outdir/cluster.seqid.tsv -j "Cluster" | mlr --tsv join -f $outdir/final_annotation.rmdup.nr.tsv -l "Sequence_ID" -r "Sequence ID" -j "Sequence_ID" | mlr --tsv reorder -f 'n,Species Count,Cluster,Class,Sequence_ID,Sequence,Score,Length,Charge,Top Precursor,Top Mature' | mlr --tsv sort -nr "n,Species Count" >$outdir/summarized_annotation.rmdup.nr.tsv

# summarized_annotation.rmdup.nr.tsv with only necessary columns will be OneFromEachCluster for Species Count
if [[ -L $outdir/OneEachCluster.tsv ]]; then
	unlink $outdir/OneEachCluster.tsv
fi
(cd $outdir && ln -fs summarized_annotation.rmdup.nr.tsv OneEachCluster.tsv)

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
		CLUSTALO=$(command -v clustalo)
	else
		print_error "CLUSTALO is unbound and no 'clustalo' found in PATH. Please export RUN_CLUSTALO=/path/to/clustalo/executable."
	fi
elif ! command -v $CLUSTALO &>/dev/null; then
	print_error "Unable to execute $CLUSTALO."
fi

# CLUSTALO
echo "PROGRAM: $(command -v $CLUSTALO)" 1>&2
clustalo_version=$($CLUSTALO --version)
echo -e "VERSION: $clustalo_version\n" 1>&2

for i in $(cut -f1 -d$'\t' $cluster95_tsv | tail -n +2 | sort -gu); do
	seqtk subseq $fasta <(awk -v var="$i" -F "\t" '{if($1==var) print $NF}' $cluster95_tsv) >$sub_outdir/cluster${i}_${percent}p.faa

	if [[ "$(grep -c '^>' $sub_outdir/cluster${i}_${percent}p.faa)" -ge 4 ]]; then

		$CLUSTALO -i $sub_outdir/cluster${i}_${percent}p.faa --full --log=$sub_outdir/msa/logs/cluster${i}_${percent}p.clustalo.log -o $sub_outdir/msa/cluster${i}_${percent}p.clustalo.faa --outfmt=fasta --output-order=tree-order --seqtype=Protein --infmt=fasta --iter=5 --full-iter --wrap=200 --force

		{
			head -n4 $sub_outdir/msa/cluster${i}_${percent}p.clustalo.faa && tail -n2 $sub_outdir/msa/cluster${i}_${percent}p.clustalo.faa
		} | sed "/^>/ s/$/ cluster_id=${i}/" >>$outdir/ThreeEachCluster.faa
	else
		cat $sub_outdir/cluster${i}_${percent}p.faa >>$outdir/ThreeEachCluster.faa
	fi
done

sed -i '/^>/! s/-//g' $outdir/ThreeEachCluster.faa
head -n1 $outdir/OneEachCluster.tsv >$outdir/ThreeEachCluster.tsv
grep -Fwf <(awk '/^>/ {print $1}' $outdir/ThreeEachCluster.faa | tr -d '>') $outdir/OneEachCluster.tsv >>$outdir/ThreeEachCluster.tsv

if [[ ! -v RSCRIPT ]]; then
	if command -v Rscript &>/dev/null; then
		RSCRIPT=$(command -v Rscript)
	else
		print_error "RSCRIPT is unbound and no 'Rscript' found in PATH. Please export RSCRIPT=/path/to/Rscript/executable."
	fi
elif ! command -v $RSCRIPT &>/dev/null; then
	print_error "Unable to execute $RSCRIPT."
fi

echo "PROGRAM: $(command -v $RSCRIPT)" 1>&2
R_version=$($RSCRIPT --version 2>&1 | awk '{print $(NF-1), $NF}')
echo -e "VERSION: $R_version\n" 1>&2

echo "COMMAND: Rscript $ROOT_DIR/scripts/SelectForSynthesis.R --one_each_cluster=$outdir/OneEachCluster.tsv --three_each_cluster=$outdir/ThreeEachCluster.tsv --output_dir=$outdir" $species_count $num_insects $insect_species_count $insect_score $num_seq_clusters $too_many_rs 1>&2
Rscript $ROOT_DIR/scripts/SelectForSynthesis.R --one_each_cluster=$outdir/OneEachCluster.tsv --three_each_cluster=$outdir/ThreeEachCluster.tsv --output_dir=$outdir
