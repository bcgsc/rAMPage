#!/usr/bin/env bash
set -euo pipefail
PROGRAM=$(basename $0)

if [[ ! -v RUN_SEQTK ]]; then
	RUN_SEQTK=seqtk
fi

if [[ ! -v RUN_EFETCH ]]; then
	RUN_EFETCH=efetch
fi

if [[ ! -v RUN_ESEARCH ]]; then
	RUN_ESEARCH=esearch
fi

apd3_url="http://aps.unmc.edu/AP/APD3_update_2020_release.fasta"
dadp_url="https://github.com/mark0428/Scraping/raw/master/DADP/DADP_mature_AMP_20181206.fa"

function table() {
	if column -L <(echo) &>/dev/null; then
		cat | column -s $'\t' -t -L
	else
		cat | column -s $'\t' -t
		echo
	fi
}

# 1 - get_help
function get_help() {
	{
		# DESCRIPTION
		echo "DESCRIPTION:"
		echo -e "\
		\tDownloads AMP sequences from NCBI protein database: antimicrobial[All Fields] AND class[Organism]\n \
		\tDownloads AMP sequences from The Antimicrobial Peptide Database (APD3): http://aps.unmc.edu/AP/main.php\n \
		\tDownloads Anuran AMP sequences from Database of Anuran Defense Peptides (DADP): http://split4.pmfst.hr/dadp/\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] -o <output directory>\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n \
		" | table
	} 1>&2
	exit 1
}
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
# 2 - print_error
function print_error() {
	{
		message="$1"
		echo "ERROR: $message"
		print_line
		get_help
	} 1>&2
}

# 3 - doesn't take arguments so no check needed

outdir=""
# 4 - get options
while getopts :ho: opt; do
	case $opt in
	h) get_help ;;
	o)
		outdir="$(realpath $OPTARG)"
		mkdir -p $outdir
		;;
	\?)
		print_error "ERROR: Invalid option: -$OPTARG"
		;;
	esac
done

shift $((OPTIND - 1))

# 5 - incorrect number
# if [[ "$#" -ne 0 ]]; then
# 	print_error "Incorrect number of arguments."
# fi

# 6 - check inputs - no inputs to check
if [[ -z $outdir ]]; then
	print_error "Required argument -o <output directory> missing."
else
	mkdir -p $outdir
fi
# 7 - do not remove status files, only want this done ONCE

# 8 - print env
echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)\n" 1>&2

echo -e "PATH=$PATH\n" 1>&2

echo
echo "Downloading sequences from APD3..." 1>&2
apd3=$(basename $apd3_url)
echo "COMMAND: wget -o $outdir/APD3.log -O $outdir/$apd3 $apd3_url" 1>&2
# apd3_start=$(date '+%s')
wget -o $outdir/APD3.log -O $outdir/$apd3 $apd3_url
# apd3_end=$(date '+%s')
# $ROOT_DIR/scripts/get-runtime.sh $apd3_start $apd3_end 1>&2
echo 1>&2

echo "Running seqtk seq on APD3 sequences..." 1>&2
echo "PROGRAM: $(command -v $RUN_SEQTK)" 1>&2
seqtk_version=$($RUN_SEQTK 2>&1 || true)
echo "VERSION: $(echo "$seqtk_version" | awk '/Version:/ {print $NF}')" 1>&2
echo -e "COMMAND: $RUN_SEQTK seq $outdir/$apd3 > $outdir/${apd3%.*}.faa\n" 1>&2
$RUN_SEQTK seq $outdir/$apd3 >$outdir/${apd3%.*}.faa

{
	echo "PROGRAM: $(command -v $RUN_ESEARCH)"
	echo -e "VERSION: $($RUN_ESEARCH --help | awk 'NR==1 {print $NF}')\n"

	echo "PROGRAM: $(command -v $RUN_EFETCH)"
	echo -e "VERSION: $($RUN_EFETCH --help | awk 'NR==1 {print $NF}')\n"
} 1>&2
today=$(date '+%Y%b%d')

# AMPHIBIA
class="Amphibia"
outfile=$outdir/amps.${class}.prot.${today}.faa
echo "Searching the NCBI protein database: antimicrobial[All Fields] and ${class}[organism]..." 1>&2
echo -e "COMMAND: $RUN_ESEARCH -db protein -query "antimicrobial[All Fields] AND ${class}[organism]" < /dev/null | $RUN_EFETCH -format fasta > $outfile\n" 1>&2
$RUN_ESEARCH -db protein -query "antimicrobial[All Fields] AND ${class}[organism]" </dev/null | $RUN_EFETCH -format fasta >$outfile

echo "Filtering for amphibian AMPs..." 1>&2
echo -e "COMMAND: grep --no-group-separator -A1 -i amphibians $outdir/${apd3%.*}.faa > $outdir/${apd3%.*}.amphibians.faa\n" 1>&2
grep --no-group-separator -A1 -i amphibians $outdir/${apd3%.*}.faa >$outdir/${apd3%.*}.amphibians.faa

echo "Downloading additional Anuran AMPs from DADP..." 1>&2
dadp=$(basename $dadp_url)
echo -e "COMMAND: wget -o $outdir/DADP.log -O $outdir/$dadp $dadp_url\n" 1>&2
#		dadp_start=$(date '+%s')
wget -o $outdir/DADP.log -O $outdir/$dadp $dadp_url
#		dadp_end=$(date '+%s')
#		$ROOT_DIR/scripts/get-runtime.sh $dadp_start $dadp_end 1>&2
#		echo 1>&2

echo "Combining the NCBI AMPs with APD3 and DADP sequences..." 1>&2
echo -e "COMMAND: cat $outfile $outdir/$dadp $outdir/${apd3%.*}.amphibians.faa > $outdir/amps.${class}.prot.${today}.combined.faa\n" 1>&2
cat $outfile $outdir/$dadp $outdir/${apd3%.*}.amphibians.faa >$outdir/amps.${class}.prot.${today}.combined.faa
if [[ -L $outdir/amps.${class}.prot.combined.faa ]]; then
	unlink $outdir/amps.${class}.prot.combined.faa
fi

ln -s $outdir/amps.${class}.prot.${today}.combined.faa $outdir/amps.${class}.prot.combined.faa

echo "Combining the APD3 and DADP sequences (mature only)..." 1>&2
echo -e "COMMAND: cat $outdir/$dadp $outdir/${apd3%.*}.amphibians.faa > $outdir/amps.${class}.prot.combined.mature.faa\n" 1>&2
cat $outdir/$dadp $outdir/${apd3%.*}.amphibians.faa >$outdir/amps.${class}.prot.combined.mature.faa
#-----------------------------------------------------------------------------------

# INSECTS

class="Insecta"
outfile=$outdir/amps.${class}.prot.${today}.faa
echo "Searching the NCBI protein database: antimicrobial[All Fields] and ${class}[organism]..." 1>&2
echo -e "COMMAND: $RUN_ESEARCH -db protein -query "antimicrobial[All Fields] AND ${class}[organism]" < /dev/null | $RUN_EFETCH -format fasta > $outfile\n" 1>&2
$RUN_ESEARCH -db protein -query "antimicrobial[All Fields] AND ${class}[organism]" </dev/null | $RUN_EFETCH -format fasta >$outfile
echo "Filtering for insect AMPs..." 1>&2
echo -e "COMMAND: grep --no-group-separator -A1 -i insects $outdir/${apd3%.*}.faa > $outdir/${apd3%.*}.insects.faa\n" 1>&2
grep --no-group-separator -A1 -i insects $outdir/${apd3%.*}.faa >$outdir/${apd3%.*}.insects.faa

echo "Combining the NCBI AMPs with APD3 sequences..." 1>&2
echo -e "COMMAND: cat $outfile $outdir/${apd3%.*}.insects.faa > $outdir/amps.${class}.prot.${today}.combined.faa\n" 1>&2
cat $outfile $outdir/${apd3%.*}.insects.faa >$outdir/amps.${class}.prot.${today}.combined.faa

if [[ -L $outdir/amps.${class}.prot.combined.faa ]]; then
	unlink $outdir/amps.${class}.prot.combined.faa
fi

ln -s $outdir/amps.${class}.prot.${today}.combined.faa $outdir/amps.${class}.prot.combined.faa

if [[ -L $outdir/amps.${class}.prot.mature.faa ]]; then
	unlink $outdir/amps.${class}.prot.mature.faa
fi
ln -s $outdir/${apd3%.*}.insects.faa $outdir/amps.${class}.prot.mature.faa

#-------------------------------------------------------------------------------------

# Do the remaining ones if they exist
if [[ "$#" -gt 0 ]]; then
	for class in "$@"; do
		outfile=$outdir/amps.${class^}.prot.${today}.faa
		echo -e "COMMAND: $RUN_ESEARCH -db protein -query "antimicrobial[All Fields] AND ${class,,}[organism]" < /dev/null | $RUN_EFETCH -format fasta > $outfile\n" 1>&2
		$RUN_ESEARCH -db protein -query "antimicrobial[All Fields] AND ${class,,}[organism]" </dev/null | $RUN_EFETCH -format fasta >$outfile
	done
fi

echo -e "END: $(date)\n" 1>&2

# echo 1>&2

echo "STATUS: DONE." 1>&2
touch $outdir/AMP_DATABASE.DONE
