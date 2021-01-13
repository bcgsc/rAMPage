#!/usr/bin/env bash
PROGRAM=$(basename $0)
args="$PROGRAM $*"

# input: logfiles
# output: tsv

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
		# DESCRIPTION
		echo "DESCRIPTION:"
		echo -e "\
		\tSummarizes wall clock time, CPU, and memory from /usr/bin/time -pv.\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-a <address>] [-f <rows|columns>] <logs directory>\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail address for alerts\n \
		\t-f <long|wide>\tformat TSV into long or wide format\t(default = long)\n \
		\t-h\tshow help menu\n \
		" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com /path/to/logs/dir\n \
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

# 3 - no arguments
if [[ "$#" -eq 0 ]]; then
	get_help
fi

email=false
format="long"
while getopts :ha:f: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	h) get_help ;;
	f) format="${OPTARG,,}" ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

if [[ ! -d $(realpath $1) ]]; then

	if [[ ! -e $(realpath $1) ]]; then
		print_error "Input directory $(realpath $1) does not exist."
	else
		print_error "Given input directory is not a directory."
	fi
fi

if [[ "$format" != "long" && "$format" != "wide" ]]; then
	print_error "Invalid -f <long|wide> option."
fi
{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo -e "CALL: $args (wd: $(pwd))\n"
} 1>&2

indir=$(realpath $1)
outfile=$indir/00-stats.tsv

# if workdir is unbound then
if [[ ! -v WORKDIR ]]; then
	# get workdir from input
	workdir=$(dirname $indir)
else
	workdir=$(realpath $WORKDIR)
fi

if [[ ! -v SPECIES ]]; then
	# get species from workdir
	species=$(echo "$workdir" | awk -F "/" '{print $(NF-1)}')
else
	species=$SPECIES
fi

header=()
values=()
for i in $(printf '%02d\n' $(seq 1 $(ls $indir | tail -n1 | cut -f1 -d-))); do
	if [[ "$i" != "04" ]]; then
		file=$(find $indir -maxdepth 1 -name "$i-*")
		step=$(basename "$file" ".log" | cut -f2 -d-)
		case $step in
		trimmed_reads)
			header+=("Number of Reads After Trimming")
			num=$(awk '/Reads passed filter:/ {print $NF}' $file)
			values+=($num)
			;;
		assembly)
			header+=("Number of Assembled Transcripts")
			num=$(awk '/Total number of assembled non-redundant transcripts:/ {print $NF}' $file)
			values+=($num)
			;;
		filtering)
			header+=("Number of Transcripts After Filtering")
			num=$(awk '/After   filtering:/ {print $NF}' $file)
			values+=($num)
			;;
		translation)
			header+=("Number of Valid ORFs")
			num=$(awk '/Number of valid ORFs:/ {print $NF}' $file)
			values+=($num)
			;;
		homology)
			header+=("Number of Non-redundant AMPs Found (HMMs)")
			num=$(awk '/Number of AMPS found \(non-redundant\):/ {print $NF}' $file)
			values+=($num)
			;;
		cleavage)
			header+=("Number of AMPs After Cleavage")
			num=$(awk '/Number of sequences remaining:/ {print $NF}' $file)
			values+=($num)
			;;
		amplify)
			header+=("Number of Non-redundant AMPs (AMPlify)")
			num=$(awk '/Number of positive \(charge >= 2\), short \(length <= 50\), and high-confidence \(score >= 0.99\) unique AMPs:/ {print $NF}' $file)
			values+=($num)
			;;
		annotation)
			header+=("Number of annotated AMPs")
			num=$(awk '/Number of annotated AMPs:/ {print $NF}' $file)
			values+=($num)
			;;
		exonerate)
			header+=("Number of novel AMPs")
			num=$(awk '/Number of Novel AMPs:/ {print $NF}' $file)
			values+=($num)
			;;
		sable) ;;
		esac
	fi
done

if [[ "$format" == "wide" ]]; then
	echo "Species ${header[@]// /_}" | tr ' ' '\t' | tr '_' ' ' >$outfile
	echo "$species ${values[*]}" | tr ' ' '\t' >>$outfile
else
	echo -e "Species\t$species" >$outfile
	for i in "${!header[@]}"; do
		echo -e "${header[i]}\t${values[i]}" >>$outfile
	done
fi

column -s $'\t' -t $outfile
echo -e "\nOutput: $outfile" 1>&2
echo -e "\nEND: $(date)" 1>&2
echo -e "\nSTATUS: DONE.\n" 1>&2

if [[ "$email" = true ]]; then
	species=$(echo "$species" | sed 's/^./\u&. /')
	echo "$indir" | mail -s "${species}: SUMMARY" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
