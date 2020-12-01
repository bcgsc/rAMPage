#!/usr/bin/env bash

# 1 - get_help function
function get_help() {
	{
		# DESCRIPTION
		echo "DESCRIPTION:"
		echo -e "\
		\tChecks that all the dependencies required are have been configured.\n
		" | column -s $'\t' -t -L

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS]\n \
		" | column -s $'\t' -t -L

		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail alert\n \
		\t-h\tshow help menu\n \
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
		printf "%2d/%d:\t%s\t%s\t%s\n" $count $total $name "..." "MISSING"
		exit 1
	else
		printf "%2d/%d:\t%s\t%s\t%s\n" $count $total $name "..." "CHECK"
	fi
	((count++))
}

function check_dir() {
	dir=$1
	name=$2
	if [[ ! -d $dir ]]; then
		printf "%2d/%d:\t%s\t%s\t%s\n" $count $total $name "..." "MISSING"
		exit 1
	else
		printf "%2d/%d:\t%s\t%s\t%s\n" $count $total $name "..." "CHECK"
	fi
	((count++))
}

function check_jar() {
	jar=$1
	name=$2
	if [[ ! -e $jar ]]; then
		printf "%2d/%d:\t%s\t%s\t%s\n" $count $total $name "..." "MISSING"
		exit 1
	else
		printf "%2d/%d:\t%s\t%s\t%s\n" $count $total $name "..." "CHECK"
	fi
	((count++))
}

count=1

total=$(($(grep -c 'export' $ROOT_DIR/scripts/config.sh) - 1))

if [[ -z $ROOT_DIR || ! -f $ROOT_DIR/CONFIG.DONE ]]; then
	echo "The script scripts/config.sh still needs to be sourced." 1>&2
	exit 1
fi

{
	check $RUN_ESEARCH "esearch" $count
	check $RUN_EFETCH "efetch" $count
	check $FASTERQ_DUMP "fasterq-dump" $count
	check $RUN_FASTP "fastp" $count
	check_jar $RUN_RNABLOOM "RNA-Bloom" $count
	check_dir $NTCARD_DIR "ntCard" $count
	check_dir $MINIMAP_DIR "minimap2" $count
	check $JAVA_EXEC "Java" $count
	check $RUN_CDHIT "CD-HIT" $count
	check $RUN_SEQTK "seqtk" $count
	check $RUN_SALMON "salmon" $count
	check $TRANSDECODER_LONGORFS "TransDecoder.LongOrfs" $count
	check $TRANSDECODER_PREDICT "TransDecoder.Predict" $count
	check $RUN_JACKHMMER "jackhmmer" $count
	check $RUN_SIGNALP "SignalP" $count
	check $RUN_PROP "ProP" $count
	check $RUN_AMPLIFY "AMPlify" $count
	check $RUN_SABLE "SABLE" $count
	check_dir $BLAST_DIR "BLAST+" $count
} | column -s$'\t' -t 1>&2

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

if [[ "$email" = true ]]; then
	org=$(pwd | awk -F "/" '{print $(NF-1)}' | sed 's/^./&. /')
	pwd | mail -s "${org^}: STAGE 01: CHECK DEPENDENCIES: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
