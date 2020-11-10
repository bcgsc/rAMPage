#!/bin/bash
set -euo pipefail
PROGRAM=$(basename $0)

function get_help() {
	echo "DESCRIPTION:" 1>&2
	echo -e "\
		\tRuns CD-HIT to reduce redundancy between protein sequences.\n
	" | column -s $'\t' -t 1>&2
	echo 1>&2

	echo "USAGE(S):" 1>&2
	echo -e "\
		\t$PROGRAM [OPTIONS] <input protein FASTA file>\n \
		" | column -s $'\t' -t 1>&2
	echo 1>&2

	echo "OPTION(S):" 1>&2
	echo -e "\
		\t-h\tshow help menu\n \
		\t-o <FILE>\toutput FASTA file\t(default = *.nr.faa)\n \
		\t-s <0 to 1>\tCD-HIT global sequence similarity cut-off\t(default = 0.90)\n\
		\t-t <INT>\tnumber of threads\t(default = 2)\n\
		\t-v\tverbose logging\t(i.e. print PATH, HOSTNAME, etc.)\n \
		" | column -s $'\t' -t 1>&2
	echo 1>&2

	exit 1
}

threads=2
similarity=0.90
output=""
verbose=false
while getopts :ho:s:t:v opt
do
	case $opt in
		h) get_help;;
		o) output="$(realpath $OPTARG)";;
		s) similarity="$OPTARG";;
		t) threads="$OPTARG";;
		v) verbose=true;;
		\?) echo "ERROR: Invalid option: -$OPTARG" 1>&2; printf '%.0s=' $(seq $(tput cols)) 1>&2; echo 1>&2; get_help;;
	esac
done

shift $((OPTIND-1))

if [[ "$#" -eq 0 ]]
then
	get_help
fi

if [[ "$#" -ne 1 ]]
then
	echo "ERROR: Incorrect number of arguments." 1>&2; printf '%.0s=' $(seq $(tput cols)) 1>&2; echo 1>&2; get_help;
fi

input=$(realpath $1)

if [[ -z "$output" ]]
then
	output=${input/.faa/.nr.faa}
fi
outdir=$(dirname $output)
if [[ "$verbose" = true ]]
then
	echo -e "PATH=$PATH\n" 1>&2

	echo "HOSTNAME: $(hostname)" 1>&2
	echo -e "START: $(date)\n" 1>&2
	start_sec=$(date '+%s')
fi 

echo "PROGRAM: $(command -v $RUN_CDHIT)" 1>&2
cdhit_version=$( { $RUN_CDHIT -h 2>&1 | head -n1 | awk -F "version " '{print $2}' | tr -d '=' ; } || true ) 
echo -e "VERSION: $cdhit_version\n" 1>&2

log=$outdir/cdhit.log

echo "Conducting redundancy removal at $(echo "$similarity * 100" | bc )% global sequence similarity..." 1>&2
echo -e "COMMAND: $RUN_CDHIT -i $input -o $output -c $similarity -T $threads &>> $log\n" 1>&2
$RUN_CDHIT -i $input -o $output -c $similarity -T $threads &>> $log

if [[ "$verbose" = true ]]
then
	echo -e "END: $(date)\n" 1>&2
	end_sec=$(date '+%s')

	if [[ "$start_sec" != "$end_sec" ]]
	then
		$ROOT_DIR/scripts/get-runtime.sh -T $start_sec $end_sec 1>&2
		echo 1>&2
	fi

	echo "STATUS: complete." 1>&2
fi
