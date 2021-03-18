#!/usr/bin/env bash
set -euo pipefail
PROGRAM=$(basename $0)
function table() {
	if column -L <(echo) &>/dev/null; then
		cat | column -s $'\t' -t -L
	else
		cat | column -s $'\t' -t
		echo
	fi
}
function get_help() {
	if command -v $RUN_SIGNALP &>/dev/null; then
		{
			# DESCRIPTION
			echo "DESCRIPTION:"
			echo -e "\
			\tConfigures the environment variables needed for running SignalP. Uses 'sed' to change variables in $RUN_SIGNALP (changes can be made manually as well).\n \
			\tSee specifics below for more information.\n \
			" | table

			echo "USAGE(S):"
			echo -e "\
			\t$PROGRAM [OPTIONS]\n \
			" | table

			echo "OPTION(S):"
			echo -e "\
			\t-h\tshow this help menu\n \
			" | table

			echo "SPECIFICS:"
			echo -e "\
			\tSIGNALP=$(dirname $RUN_SIGNALP)\n \
			\tSH=/bin/bash\n \
			\tAWK=$(command -v awk)\n \
			" | table
		} 1>&2
	else
		if [[ -n $RUN_SIGNALP ]]; then
			echo "ERROR: Unable to configure SignalP, as $RUN_SIGNALP is invalid." 1>&2
		else
			echo "ERROR: RUN_SIGNALP variable not specified in scripts/config.sh, or scripts/config.sh not sourced." 1>&2
		fi
	fi
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

function print_error() {
	{
		message="$1"
		echo "ERROR: $message"
		print_line
		get_help
	} 1>&2
}

while getopts :h opt; do
	case $opt in
	h) get_help ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

if command -v $RUN_SIGNALP &>/dev/null; then
	signal_dir=$(dirname $RUN_SIGNALP)
	if [[ ! -f "$signal_dir/CONFIG.DONE" ]]; then
		sed -i "s|^SIGNALP=.*|SIGNALP=$signal_dir|" $RUN_SIGNALP
		sed -i "s|^SH=.*|SH=$SHELL|" $RUN_SIGNALP
		permissions=$(ls -ld $signal_dir/tmp | awk '{print $1}')
		owner=$(ls -ld $signal_dir/tmp | awk '{print $3}')
		if [[ "$permissions" != "drwxrw[sx]rwt" && "$owner" == "$(whoami)" ]]; then
			chmod 1777 $signal_dir/tmp
		fi
		awkbin=$(command -v awk)
		sed -i 's/^AWK=.*/AWK=awk/' $RUN_SIGNALP
		sed -i "s|AWK=/.*|AWK=$awkbin|" $RUN_SIGNALP
		gnuplot=$(command -v gnuplot 2>/dev/null || true)
		if [[ -n $gnuplot ]]; then
			sed -i "s|PLOTTER=/.*|PLOTTER=$gnuplot|" $RUN_SIGNALP
		fi
		ppmtogifbin=$(command -v ppmtogif 2>/dev/null || true)
		if [[ -n $ppmtogifbin ]]; then
			sed -i "s|PPMTOGIF=/.*|PPMTOGIF=$ppmtogifbin|" $RUN_SIGNALP
		fi
		touch $signal_dir/CONFIG.DONE
	else
		echo -e "SignalP has been previously configured.\n" 1>&2
	fi
else
	echo "ERROR: SignalP not found." 1>&2
fi
