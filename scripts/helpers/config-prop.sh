#!/usr/bin/env bash
set -euo pipefail
PROGRAM=$(basename $0)

function get_help() {

	if command -v $RUN_PROP &>/dev/null; then
		{
			# DESCRIPTION
			echo "DESCRIPTION:"
			echo -e "\
			\tConfigures the environment variables needed for running ProP. Uses 'sed' to change variables in $RUN_PROP (changes can be made manually as well).\n \
			\tSee specifics below for more information.\n \
			" | column -s $'\t' -t -L

			echo "USAGE(S):"
			echo -e "\
			\t$PROGRAM [OPTIONS]\n \
			" | column -s $'\t' -t -L

			echo "OPTION(S):"
			echo -e "\
			\t-h\tshow this help menu\n \
			" | column -s $'\t' -t -L

			echo "SPECIFICS:"
			echo -e "\
			\tsetenv PROPHOME=$(dirname $RUN_PROP)\n \
			\tsetenv AWK=$(command -v awk) \n \
			\tsetenv ECHO=$(command -v echo) -e\n \
			\tsetenv GNUPLOT=$(command -v gnuplot)\n \
			\tsetenv PPM2GIF=$(command -v ppmtogif)\n \
			" | column -s $'\t' -t -L
		} 1>&2

	else
		if [[ -n $RUN_PROP ]]; then
			echo "ERROR: Unable to configure ProP, as $RUN_PROP is invalid." 1>&2
		else
			echo "ERROR: RUN_PROP variable not specified in scripts/config.sh, or scripts/config.sh not sourced." 1>&2
		fi
	fi

	exit 1
}

while getopts :h opt; do
	case $opt in
	h) get_help ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

if command -v $RUN_PROP &>/dev/null; then
	propdir=$(dirname $RUN_PROP)
	if [[ ! -f $propdir/CONFIG.DONE ]]; then
		permissions=$(ls -ld $propdir/tmp | awk '{print $1}')
		owner=$(ls -ld $propdir/tmp | awk '{print $3}')

		if [[ "$permissions" != "drwxrw[sx]rwt" && "$owner" == "$(whoami)" ]]; then
			chmod 1777 $propdir/tmp
		fi

		echo -e "Configuring ProP...\n" 1>&2
		sed -i "s|setenv\tPROPHOME.*|setenv\tPROPHOME\t$propdir|" $RUN_PROP

		awkbin=$(command -v awk)
		sed -i "s|setenv AWK.*|setenv AWK $awkbin|" $RUN_PROP

		echobin=$(which echo)
		sed -i "s|setenv ECHO.*|setenv ECHO \"$echobin -e\"|" $RUN_PROP

		gnuplot=$(command -v gnuplot 2>/dev/null || true)
		if [[ ! -z $gnuplot ]]; then
			sed -i "s|setenv GNUPLOT.*|setenv GNUPLOT $gnuplot|" $RUN_PROP
		fi

		ppmtogifbin=$(command -v ppmtogif 2>/dev/null || true)
		if [[ ! -z $ppmtogifbin ]]; then
			sed -i "s|setenv PPM2GIF.*|setenv PPM2GIF $ppmtogifbin|" $RUN_PROP
		fi

		if [[ ! -f $(dirname $RUN_SIGNALP)/CONFIG.DONE ]]; then
			echo "WARNING: SignalP still needs to be configured." 1>&2
		fi
		sed -i "s|setenv SIGNALP.*|setenv SIGNALP $RUN_SIGNALP|" $RUN_PROP
	fi
fi
