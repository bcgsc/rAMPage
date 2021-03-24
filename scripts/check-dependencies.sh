#!/usr/bin/env bash
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
		cat | column -s $'\t' -t -L 1>&2
	else
		{
			cat | column -s $'\t' -t
			echo
		} 1>&2
	fi
}

# 1 - get_help function
function get_help() {
	{
		echo -e "PROGRAM: $PROGRAM\n"
		# DESCRIPTION
		echo "DESCRIPTION:"
		echo -e "\
		\tChecks that all the dependencies required are have been configured.\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-a <address>] [-h]\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail address for alerts\n \
		\t-h\tshow help menu\n \
		" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com\n \
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
email=false
while getopts :ha: opt; do
	case $opt in
	h) get_help ;;
	a)
		address="$OPTARG"
		email=true
		;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

function check() {
	path=$1
	name=$2
	if ! command -v $path &>/dev/null; then
		printf "\t%2d/%d:\t%s\t%s\t%s\n" $count $total $name "..." "MISSING"
		exit 1
	else
		printf "\t%2d/%d:\t%s\t%s\t%s\n" $count $total $name "..." "CHECK"
	fi
	((count++))
}

function check_dir() {
	dir=$1
	name=$2
	if [[ ! -d $dir ]]; then
		printf "\t%2d/%d:\t%s\t%s\t%s\n" $count $total $name "..." "MISSING"
		exit 1
	else
		printf "\t%2d/%d:\t%s\t%s\t%s\n" $count $total $name "..." "CHECK"
	fi
	((count++))
}

function check_jar() {
	jar=$1
	name=$2
	if [[ ! -e $jar ]]; then
		printf "\t%2d/%d:\t%s\t%s\t%s\n" $count $total $name "..." "MISSING"
		exit 1
	else
		printf "\t%2d/%d:\t%s\t%s\t%s\n" $count $total $name "..." "CHECK"
	fi
	((count++))
}

function check_file() {
	file=$1
	name=$2
	if [[ ! -s ${file}.00.pni ]]; then
		printf "\t%2d/%d:\t%s\t%s\t%s\n" $count $total $name "..." "MISSING"
		exit 1
	else
		printf "\t%2d/%d:\t%s\t%s\t%s\n" $count $total $name "..." "CHECK"
	fi
	((count++))
}
count=1

if [[ ! -v TARGET ]]; then
	# set it to default of exonerate
	target="exonerate"
fi

if [[ ! -v ROOT_DIR || ! -f $ROOT_DIR/CONFIG.DONE ]]; then
	echo "The script scripts/config.sh still needs to be sourced." 1>&2
	exit 1
fi

if [[ "$target" != "sable" && "$target" != "all" ]]; then
	total=$(($(grep -c '^export' $ROOT_DIR/scripts/config.sh) - 1 - 3))
else
	total=$(($(grep -c '^export' $ROOT_DIR/scripts/config.sh) - 1))
fi

{
	# for fetching reads and homology db fetching...
	# check $RUN_ESEARCH "esearch" $count || exit 1
	# check $RUN_EFETCH "efetch" $count || exit 1
	# check $FASTERQ_DUMP "fasterq-dump" $count || exit 1

	# for trimming
	check $RUN_FASTP "fastp" $count || exit 1

	# for assembly
	check_jar $RUN_RNABLOOM "RNA-Bloom" $count || exit 1
	check_dir $NTCARD_DIR "ntCard" $count || exit 1
	check_dir $MINIMAP_DIR "minimap2" $count || exit 1
	check $JAVA_EXEC "Java" $count || exit 1

	# for redundancy removal
	check $RUN_CDHIT "CD-HIT" $count || exit 1
	check $RUN_SEQTK "seqtk" $count || exit 1

	# for filtering expression
	check $RUN_SALMON "salmon" $count || exit 1

	# for translation
	check $TRANSDECODER_LONGORFS "TransDecoder.LongOrfs" $count || exit 1
	check $TRANSDECODER_PREDICT "TransDecoder.Predict" $count || exit 1

	# for homolgoy
	check $RUN_JACKHMMER "jackhmmer" $count || exit 1

	# for signal prediction and cleavage
	check $RUN_SIGNALP "SignalP" $count || exit 1
	check $RUN_PROP "ProP" $count || exit 1

	# for AMPlify
	check $RUN_AMPLIFY "AMPlify" $count || exit 1

	# for annotation
	check $RUN_ENTAP "EnTAP" $count || exit 1
	check $RUN_DIAMOND "diamond" $count || exit 1
	check $RUN_INTERPROSCAN "InterProScan" $count || exit 1

	# for exonerate
	check $RUN_EXONERATE "Exonerate" $count || exit 1

	# for SABLE
	if [[ "$target" == "sable" || "$target" == "all" ]]; then
		check $RUN_SABLE "SABLE" $count || exit 1
		check_dir $BLAST_DIR "BLAST+" $count || exit 1
		check_file $NR_DBNAME_FORMATTED "NR" $count || exit 1
	fi

} | column -s$'\t' -t

if [[ ! -v STRANDED || ! -v PAIRED || ! -v CLASS || ! -v SPECIES || ! -v WORKDIR ]]; then
	# echo "Variable \$STRANDED not exported from scripts/rAMPage.sh."
	echo -e "\nPlease indicate whether your dataset has stranded or nonstranded library construction:" 1>&2
	echo -e "\te.g. export STRANDED=true\n" 1>&2
	echo "Please indicate whether your dataset has paired or single-end reads:" 1>&2
	echo -e "\te.g. export PAIRED=true\n" 1>&2
	echo "Please indicate the taxonomic class of your dataset:" 1>&2
	echo -e "\te.g. export CLASS=insecta\n" 1>&2
	echo "Please indicate the taxonomic species of your dataset:" 1>&2
	echo -e "\te.g. for M. gulosa:" 1>&2
	echo -e "\t\texport SPECIES=mgulosa\n" 1>&2
	echo "Please indicate the working directory for your dataset:" 1>&2
	echo -e "\te.g. for M. gulosa:" 1>&2
	echo -e "\t\texport WORKDIR=$ROOT_DIR/insecta/mgulosa/venom\n" 1>&2
	exit 1
fi

# if [[ ! -v PAIRED ]]; then
# 	#	echo "Variable \$PAIRED not exported from scripts/rAMPage.sh."
# 	echo "Please indicate whether your dataset has paired or single-end reads:" 1>&2
# 	echo -e "\te.g. export PAIRED=true" 1>&2
# 	exit 1
# fi
#
# if [[ ! -v CLASS ]]; then
# 	#	echo "Variable \$CLASS not exported from scripts/rAMPage.sh."
# 	echo "Please indicate the taxonomic class of your dataset:" 1>&2
# 	echo -e "\te.g. export CLASS=insecta" 1>&2
# 	exit 1
# fi
#
# if [[ ! -v SPECIES ]]; then
# 	#	echo "Variable \$SPECIES not exported from scripts/rAMPage.sh."
# 	echo "Please indicate the taxonomic species of your dataset:" 1>&2
# 	echo -e "\te.g. for M. gulosa:" 1>&2
# 	echo -e "\t\texport SPECIES=mgulosa" 1>&2
# 	exit 1
# fi
#
# if [[ ! -v WORKDIR ]]; then
# 	echo "Please indicate the working directory for your dataset:" 1>&2
# 	echo -e "\te.g. for M. gulosa:" 1>&2
# 	echo -e "\t\texport WORKDIR=$ROOT_DIR/insecta/mgulosa/venom" 1>&2
# 	#	echo "Variable \$WORKDIR not exported from scripts/rAMPage.sh."
# 	exit 1
# fi

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

printenv >env.txt
touch $(realpath $WORKDIR)/DEPENDENCIES.CHECK

echo "STATUS: DONE" 1>&2
species=$(echo "$SPECIES" | sed 's/.\+/\L&/') # make it all lowercase
# species=${SPECIES,,}
if [[ "$email" = true ]]; then
	species=$(echo "$species" | sed 's/^./\u&. /') # add a space and period, and capitalize the first letter
	# pwd | mail -s "${species^}: STAGE 01: CHECK DEPENDENCIES: SUCCESS" "$address"
	pwd | mail -s "${species}: STAGE 01: CHECK DEPENDENCIES: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
