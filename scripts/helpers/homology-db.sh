#!/usr/bin/env bash
set -euo pipefail
PROGRAM=$(basename $0)

# apd3_url="http://aps.unmc.edu/AP/APD3_update_2020_release.fasta"
if [[ ! -v APD3_URL ]]; then
	# apd3_url="https://wangapd3.com/APD_sequence_release_09142020.fasta"
	apd3_url="https://aps.unmc.edu/assets/sequences/APD_sequence_release_09142020.fasta"
else
	apd3_url=$APD3_URL

fi

if [[ ! -v DADP_URL ]]; then
	dadp_url="https://github.com/mark0428/Scraping/raw/master/DADP/DADP_mature_AMP_20181206.fa"
else
	dadp_url=$DADP_URL
fi

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
		\tDownloads AMP sequences from The Antimicrobial Peptide Database (APD3): https://wangapd3.com/main.php\n \
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
		\t-p\tplot distributions (requires AMPlify)\n \
		\t-s\tskip certificate check\n \
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
skip_opt=""
outdir=""
plot=false
# 4 - get options
while getopts :ho:sp opt; do
	case $opt in
	h) get_help ;;
	o)
		outdir="$(realpath $OPTARG)"
		mkdir -p $outdir
		;;
	p) plot=true ;;
	s) skip_opt="--insecure" ;;
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

if [[ ! -v RUN_SEQTK ]]; then
	if command -v seqtk &>/dev/null; then
		RUN_SEQTK=$(command -v seqtk)
	else
		print_error "RUN_SEQTK is unbound and not 'seqtk' found in PATH. Please export RUN_SEQTK=/path/to/seqtk/executable."
	fi
elif ! command -v $RUN_SEQTK &>/dev/null; then
	print_error "Unable to execute $RUN_SEQTK."
fi

if [[ ! -v RUN_ESEARCH ]]; then
	if command -v esearch &>/dev/null; then
		RUN_ESEARCH=$(command -v esearch)
	else
		print_error "RUN_ESEARCH is unbound and no 'esearch' found in PATH. Please export RUN_ESEARCH=/path/to/esearch/executable."
	fi
elif ! command -v $RUN_ESEARCH &>/dev/null; then
	print_error "Unable to execute $RUN_ESEARCH."
fi

if [[ ! -v RUN_EFETCH ]]; then
	if command -v efetch &>/dev/null; then
		RUN_EFETCH=$(command -v efetch)
	else
		print_error "RUN_EFETCH is unbound and no 'efetch' found in PATH. Please export RUN_EFETCH=/path/to/efetch/executable."
	fi
elif ! command -v $RUN_EFETCH &>/dev/null; then
	print_error "Unable to execute $RUN_EFETCH."
fi

echo 1>&2

echo "Checking APD3 URL..." 1>&2
if ! curl --head $skip_opt --silent --fail --connect-timeout 10 "$apd3_url" &>/dev/null; then
	print_error "The APD3 URL $apd3_url does not exist. Please bind the updated URL to the exported variable APD3_URL, e.g. export APD3_URL=\"https://newURL.com/APD3.fasta\""
fi

echo "Downloading sequences from APD3..." 1>&2
apd3=$(basename $apd3_url)
echo "COMMAND: curl -L $skip_opt -o $outdir/$apd3 \"$apd3_url\" &> $outdir/APD3.log" 1>&2
curl -L $skip_opt -o $outdir/$apd3 "$apd3_url" &>$outdir/APD3.log
# echo "COMMAND: wget -o $outdir/APD3.log -O $outdir/$apd3 $apd3_url" 1>&2
# wget -o $outdir/APD3.log -O $outdir/$apd3 $apd3_url
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
echo -e "COMMAND: $RUN_ESEARCH -db protein -query \"antimicrobial[All Fields] AND ${class}[organism]\" < /dev/null | $RUN_EFETCH -format fasta > $outfile\n" 1>&2
$RUN_ESEARCH -db protein -query "antimicrobial[All Fields] AND ${class}[organism]" </dev/null | $RUN_EFETCH -format fasta >$outfile

(cd $outdir && ln -fs $(basename $outfile) amps.${class}.prot.precursor.faa)
echo "Filtering for amphibian AMPs..." 1>&2
echo -e "COMMAND: grep --no-group-separator -A1 -i amphibians $outdir/${apd3%.*}.faa > $outdir/${apd3%.*}.amphibians.faa\n" 1>&2
grep --no-group-separator -A1 -i amphibians $outdir/${apd3%.*}.faa >$outdir/${apd3%.*}.amphibians.faa

echo "Checking DADP URL..." 1>&2
if ! curl --head $skip_opt --silent --fail --connect-timeout 10 "$dadp_url" &>/dev/null; then
	print_error "The APD3 URL $dadp_url does not exist. Please bind the updated URL to the exported variable DADP_URL, e.g. export DADP_URL=\"https://newURL.com/DADP.fasta\""
fi
echo "Downloading additional Anuran AMPs from DADP..." 1>&2
dadp=$(basename $dadp_url)
echo -e "COMMAND: curl -L $skip_opt -o $outdir/$dadp \"$dadp_url\" &> $outdir/DADP.log\n" 1>&2
curl -L $skip_opt -o $outdir/$dadp "$dadp_url" &>$outdir/DADP.log
# echo -e "COMMAND: wget -o $outdir/DADP.log -O $outdir/$dadp $dadp_url\n" 1>&2
# wget -o $outdir/DADP.log -O $outdir/$dadp $dadp_url

echo "Combining the APD3 and DADP sequences..." 1>&2
echo -e "COMMAND: cat $outdir/$dadp $outdir/${apd3%.*}.amphibians.faa > $outdir/amps.${class}.prot.mature.faa"
cat $outdir/$dadp $outdir/${apd3%.*}.amphibians.faa >$outdir/amps.${class}.prot.mature.faa

echo "Combining the NCBI AMPs with APD3 and DADP sequences..." 1>&2
echo -e "COMMAND: cat $outfile $outdir/amps.${class}.prot.mature.faa > $outdir/amps.${class}.prot.${today}.combined.faa\n" 1>&2

cat $outfile $outdir/amps.${class}.prot.mature.faa | $RUN_SEQTK seq >$outdir/amps.${class}.prot.${today}.combined.faa

$ROOT_DIR/scripts/run-cdhit.sh -d $outdir/amps.${class}.prot.${today}.combined.faa
echo 1>&2

sed '/^>/N; s/\n/\t/' $outdir/amps.${class}.prot.${today}.combined.rmdup.nr.faa | grep -v $'\t''.*[BJOUZX]' | tr '\t' '\n' >$outdir/amps.${class}.prot.${today}.combined.unambiguous.rmdup.nr.faa

if [[ -L $outdir/amps.${class}.prot.combined.rmdup.nr.faa ]]; then
	unlink $outdir/amps.${class}.prot.combined.rmdup.nr.faa
fi
if [[ -L $outdir/amps.${class}.prot.combined.unambiguous.rmdup.nr.faa ]]; then
	unlink $outdir/amps.${class}.prot.combined.unambiguous.rmdup.nr.faa
fi

(cd $outdir && ln -fs amps.${class}.prot.${today}.combined.rmdup.nr.faa amps.${class}.prot.combined.rmdup.nr.faa && ln -fs amps.${class}.prot.${today}.combined.unambiguous.rmdup.nr.faa amps.${class}.prot.combined.unambiguous.rmdup.nr.faa)

# ln -s $outdir/amps.${class}.prot.${today}.combined.faa $outdir/amps.${class}.prot.combined.faa

# echo "Combining the APD3 and DADP sequences (mature only)..." 1>&2
# echo -e "COMMAND: cat $outdir/$dadp $outdir/${apd3%.*}.amphibians.faa > $outdir/amps.${class}.prot.combined.mature.faa\n" 1>&2
# cat $outdir/$dadp $outdir/${apd3%.*}.amphibians.faa >$outdir/amps.${class}.prot.combined.mature.faa
#-----------------------------------------------------------------------------------

# INSECTS

class="Insecta"
outfile=$outdir/amps.${class}.prot.${today}.faa
echo "Searching the NCBI protein database: antimicrobial[All Fields] and ${class}[organism]..." 1>&2
echo -e "COMMAND: $RUN_ESEARCH -db protein -query \"antimicrobial[All Fields] AND ${class}[organism]\" < /dev/null | $RUN_EFETCH -format fasta > $outfile\n" 1>&2
$RUN_ESEARCH -db protein -query "antimicrobial[All Fields] AND ${class}[organism]" </dev/null | $RUN_EFETCH -format fasta >$outfile
(cd $outdir && ln -fs $(basename $outfile) amps.${class}.prot.precursor.faa)
echo "Filtering for insect AMPs..." 1>&2
echo -e "COMMAND: grep --no-group-separator -A1 -i insects $outdir/${apd3%.*}.faa > $outdir/${apd3%.*}.insects.faa\n" 1>&2
grep --no-group-separator -A1 -i insects $outdir/${apd3%.*}.faa >$outdir/${apd3%.*}.insects.faa

echo "Combining the NCBI AMPs with APD3 sequences..." 1>&2
echo -e "COMMAND: cat $outfile $outdir/${apd3%.*}.insects.faa > $outdir/amps.${class}.prot.${today}.combined.faa\n" 1>&2
cat $outfile $outdir/${apd3%.*}.insects.faa | $RUN_SEQTK seq >$outdir/amps.${class}.prot.${today}.combined.faa

$ROOT_DIR/scripts/run-cdhit.sh -d $outdir/amps.${class}.prot.${today}.combined.faa
echo 1>&2

sed '/^>/N; s/\n/\t/' $outdir/amps.${class}.prot.${today}.combined.rmdup.nr.faa | grep -v $'\t''.*[BJOUZX]' | tr '\t' '\n' >$outdir/amps.${class}.prot.${today}.combined.unambiguous.rmdup.nr.faa

if [[ -L $outdir/amps.${class}.prot.combined.rmdup.nr.faa ]]; then
	unlink $outdir/amps.${class}.prot.combined.rmdup.nr.faa
fi

if [[ -L $outdir/amps.${class}.prot.combined.unambiguous.rmdup.nr.faa ]]; then
	unlink $outdir/amps.${class}.prot.combined.unambiguous.rmdup.nr.faa
fi

(cd $outdir && ln -fs amps.${class}.prot.${today}.combined.rmdup.nr.faa amps.${class}.prot.combined.rmdup.nr.faa && ln -fs amps.${class}.prot.${today}.combined.unambiguous.rmdup.nr.faa amps.${class}.prot.combined.unambiguous.rmdup.nr.faa)
# ln -s $outdir/amps.${class}.prot.${today}.combined.faa $outdir/amps.${class}.prot.combined.faa

if [[ -L $outdir/amps.${class}.prot.mature.faa ]]; then
	unlink $outdir/amps.${class}.prot.mature.faa
fi
(cd $outdir && ln -fs ${apd3%.*}.insects.faa amps.${class}.prot.mature.faa)
# ln -s $outdir/${apd3%.*}.insects.faa $outdir/amps.${class}.prot.mature.faa

#-------------------------------------------------------------------------------------
# cat $outdir/amps.Amphibia.prot.combined.faa $outdir/amps.Insecta.prot.combined.faa >$outdir/ref.amps.combined.faa

# $ROOT_DIR/scripts/run-cdhit.sh -d $outdir/ref.amps.combined.faa

# RUNS AMPLIFY and gets the TSV
if [[ "$plot" = true ]]; then
	$ROOT_DIR/scripts/plot-dist.sh -a $outdir/amps.Amphibia.prot.combined.unambiguous.rmdup.nr.faa -i $outdir/amps.Insecta.prot.combined.unambiguous.rmdup.nr.faa -o $outdir -r
fi

# export CLASS=Amphibia && mkdir -p $outdir/amphibia && $ROOT_DIR/scripts/run-amplify.sh -o $outdir/amphibia -T $outdir/amps.Amphibia.prot.combined.unambiguous.rmdup.nr.faa
# export CLASS=Insecta && mkdir -p $outdir/insecta && $ROOT_DIR/scripts/run-amplify.sh -o $outdir/insecta -T $outdir/amps.Insecta.prot.combined.unambiguous.rmdup.nr.faa

# Do the remaining ones if they exist
# if [[ "$#" -gt 0 ]]; then
# 	for class in "$@"; do
# 		outfile=$outdir/amps.${class^}.prot.${today}.faa
# 		echo -e "COMMAND: $RUN_ESEARCH -db protein -query "antimicrobial[All Fields] AND ${class,,}[organism]" < /dev/null | $RUN_EFETCH -format fasta > $outfile\n" 1>&2
# 		$RUN_ESEARCH -db protein -query "antimicrobial[All Fields] AND ${class,,}[organism]" </dev/null | $RUN_EFETCH -format fasta >$outfile
# 	done
# fi

echo -e "END: $(date)\n" 1>&2

# echo 1>&2

echo "STATUS: DONE." 1>&2
touch $outdir/AMP_DATABASE.DONE
