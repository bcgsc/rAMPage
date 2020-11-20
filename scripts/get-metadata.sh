#!/usr/bin/env bash
set -euo pipefail
PROGRAM=$(basename $0)

# 1 - get_help
function get_help() {
	# DESCRIPTION
	{
		echo "DESCRIPTION:"
		echo -e "\
		\tGets the sample attributes given the accession(s).\n \
		" | column -s$'\t' -t -L

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] -o <output directory> <SRA accession(s)>\n \
		" | column -s $'\t' -t -L

		echo "OPTION(S):"
		echo -e "\
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n \
		" | column -s $'\t' -t -L
	} 1>&2
	exit 1
}
# 2 - print_error
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

# 4 - get options
while getopts :ho: opt; do
	case $opt in
	h) get_help ;;
	o) outdir="$(realpath $OPTARG)" ;;
	\?)
		print_line "Invalid option: -$OPTARG"
		;;
	esac
done

shift $((OPTIND - 1))

# 5 - wrong arguments given
if [[ "$#" -lt 1 ]]; then
	print_line "Incorrect number of arguments."
fi

# 6 - check input files - no filesa

# 7 - check status files
if [[ -f $outdir/METADATA.DONE ]]; then
	rm $outdir/METADATA.DONE
fi

# 8 - no env print

file=$outdir/metadata.xml
accessions=$(echo "$*" | sed 's/ /\" OR \"/g' | sed 's/^/\"/' | sed 's/$/\"/')
url="http://trace.ncbi.nlm.nih.gov/Traces/sra/sra.cgi?save=efetch&db=sra&rettype=metadata&term="

# Make ACCESSIONS INTO URL and WGET
echo "Fetching metadata XML file..." 1>&2
while [[ ! -s $file ]]; do
	wget --tries=inf -O $file "$url$accessions" || true
done

# SPLIT THE XML FILES SEPARATELY FOR EACH RUN
echo "Splitting the metadata XML file by RUN accession..." 1>&2
sed -i 's|</EXPERIMENT_PACKAGE>|&\n|g' $file
awk -v var="$outdir" 'BEGIN{x="/dev/null"}/<EXPERIMENT_PACKAGE>/{x=var"/F"++i".xml";}{print > x;}' $file
# GRAB RUN ID and SAMPLE ATTRIBUTES
echo "Filtering for relevant metadata..." 1>&2
for i in $outdir/F*.xml; do
	run_id="$(awk -F "<RUN_SET>" '{print $2}' $i | awk -F "accession=\"" '{print $2}' | awk -F "\"" '{print $1}' | sed '/^$/d')"
	sample_attributes=$(awk -v FS="(<SAMPLE_ATTRIBUTES>|</SAMPLE_ATTRIBUTES>)" '{print $2}' $i | sed 's|</SAMPLE_ATTRIBUTE>|&\n|g' | sed '/^$/d' | sed 's|<SAMPLE_ATTRIBUTE><TAG>||g' | sed 's|</TAG><VALUE>|\t|' | sed 's|</VALUE></SAMPLE_ATTRIBUTE>||g')
	header=$(echo "$sample_attributes" | awk -F "\t" '{print $1}' | tr '\n' '\t')
	body=$(echo "$sample_attributes" | awk -F "\t" '{print $2}' | tr '\n' '\t')
	echo -e "SRA Accession\t$run_id\n$sample_attributes" >$outdir/$(basename $i ".xml").tsv
	sort -t$'\t' -k1,1 -o $outdir/$(basename $i ".xml").tsv $outdir/$(basename $i ".xml").tsv
done

echo "Re-joining the metadata into one file..." 1>&2
num_files=$(ls $outdir/F*.tsv | wc -l)
if [[ $num_files -eq 1 ]]; then
	cp $outdir/F1.tsv $outdir/temp.tsv
elif [[ $num_files -eq 2 ]]; then
	join --nocheck-order -t$'\t' $outdir/F1.tsv $outdir/F2.tsv >$outdir/temp.tsv
elif [[ $num_files -le 0 ]]; then
	exit 1
else
	cmd="join --nocheck-order -t $'\t' $outdir/F1.tsv $outdir/F2.tsv"
	for i in $(seq 3 $num_files); do
		addon=" | join --nocheck-order -t $'\t' - $outdir/F${i}.tsv"
		cmd="${cmd}${addon}"
	done
	eval $cmd >$outdir/temp.tsv
fi

sed -i '/^$/d' $outdir/temp.tsv
# Remove irrelevant fields
sed -i '/\<INSDC\>/d' $outdir/temp.tsv
sed -i '/\<ENA\>/d' $outdir/temp.tsv
sed -i '/specimen_voucher/d' $outdir/temp.tsv
sed -i '/\<individual\>/d' $outdir/temp.tsv
sed -i '/_\?date_\?/d' $outdir/temp.tsv
sed -i '/[Rr]eplicate \?[0-9]*/d' $outdir/temp.tsv
sed -i '/days_/d' $outdir/temp.tsv
sed -i '/_days/d' $outdir/temp.tsv
sed -i '/SRA accession/d' $outdir/temp.tsv
sed -i '/\<Alias\>/d' $outdir/temp.tsv

final=$outdir/metadata.tsv
if [[ -f "$final" ]]; then
	rm "$final"
fi

# if the outdir/temp.tsv only has 1 row, then there are NO columns in common
if [[ "$(wc -l $outdir/temp.tsv | awk '{print $1}')" -eq 1 ]]; then
	echo -e "\nThere are no common columns of metadata within this dataset.\n" 1>&2
fi

echo "Creating the header..." 1>&2
cat <(grep "SRA Accession" $outdir/temp.tsv) <(grep -v "SRA Accession" $outdir/temp.tsv) >$outdir/reordered.tsv
num_cols=$((num_files + 1))

echo "Making the TSV file..." 1>&2
for i in $(seq 1 $num_cols); do
	cut -f $i -d$'\t' $outdir/reordered.tsv | tr '\n' '\t' | sed 's/\t$/\n/' >>$final

done
rm $outdir/F*.xml $outdir/F*.tsv $outdir/metadata.xml $outdir/temp.tsv $outdir/reordered.tsv
echo -e "\nDone: $final\n" 1>&2
touch $outdir/METADATA.DONE
