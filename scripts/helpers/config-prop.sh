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

	if [[ ! -v RUN_PROP ]]; then
		if command -v prop &>/dev/null; then
			RUN_PROP=$(command -v prop)
		else
			{
				# DESCRIPTION
				echo "DESCRIPTION:"
				echo -e "\
				\tConfigures the environment variables needed for running ProP. Uses 'sed' to change variables in RUN_PROP (changes can be made manually as well).\n \
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
				\tsetenv PROPHOME=\$(dirname RUN_PROP)\n \
				\tsetenv AWK=$(command -v awk) \n \
				\tsetenv ECHO=\"$(command -v echo) -e\"\n \
				\tsetenv GNUPLOT=$(command -v gnuplot)\n \
				\tsetenv PPM2GIF=$(command -v ppmtogif)\n \
				" | table
			} 1>&2
			echo "ERROR: RUN_PROP is unbound and no 'prop' found in PATH. Please export RUN_PROP=/path/to/prop/executable." 1>&2
			exit 1
		fi
	elif ! command -v $RUN_PROP &>/dev/null; then
		{
			# DESCRIPTION
			echo "DESCRIPTION:"
			echo -e "\
			\tConfigures the environment variables needed for running ProP. Uses 'sed' to change variables in $RUN_PROP (changes can be made manually as well).\n \
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
			\tsetenv PROPHOME=$(dirname $RUN_PROP)\n \
			\tsetenv AWK=$(command -v awk) \n \
			\tsetenv ECHO=\"$(command -v echo) -e\"\n \
			\tsetenv GNUPLOT=$(command -v gnuplot)\n \
			\tsetenv PPM2GIF=$(command -v ppmtogif)\n \
			" | table
		} 1>&2
		echo "ERROR: Unable to execute $RUN_PROP." 1>&2
		exit 1
	fi
	{
		# DESCRIPTION
		echo "DESCRIPTION:"
		echo -e "\
		\tConfigures the environment variables needed for running ProP. Uses 'sed' to change variables in $RUN_PROP (changes can be made manually as well).\n \
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
		\tsetenv PROPHOME=$(dirname $RUN_PROP)\n \
		\tsetenv AWK=$(command -v awk) \n \
		\tsetenv ECHO=\"$(command -v echo) -e\"\n \
		\tsetenv GNUPLOT=$(command -v gnuplot)\n \
		\tsetenv PPM2GIF=$(command -v ppmtogif)\n \
		" | table
	} 1>&2

	exit 1
}

while getopts :h opt; do
	case $opt in
	h) get_help ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

if [[ ! -v RUN_PROP ]]; then
	if command -v prop &>/dev/null; then
		RUN_PROP=$(command -v prop)
	else
		get_help
		# print_error "RUN_PROP is unbound and no 'prop' found in PATH. Please export RUN_PROP=/path/to/prop/executable."
	fi
elif ! command -v $RUN_PROP &>/dev/null; then
	get_help
	# print_error "Unable to execute $RUN_PROP."
fi

if [[ ! -v RUN_SIGNALP ]]; then
	if command -v signalp &>/dev/null; then
		RUN_SIGNALP=$(command -v signalp)
	else
		print_error "RUN_SIGNALP is unbound and no 'signalp' found in PATH. Please export RUN_SIGNALP=/path/to/signalp/executable."
	fi
elif ! command -v $RUN_SIGNALP &>/dev/null; then
	print_error "Unable to execute $RUN_SIGNALP."
fi

if [[ ! -v ROOT_DIR ]]; then
	print_error "ROOT_DIR is unbound. Please export ROOT_DIR=/rAMPage/GitHub/directory."
fi
propdir=$(dirname $RUN_PROP)
if [[ ! -f $propdir/CONFIG.DONE ]]; then
	permissions=$(ls -ld $propdir/tmp | awk '{print $1}')
	owner=$(ls -ld $propdir/tmp | awk '{print $3}')

	if [[ "$permissions" != "drwxrw[sx]rwt" && "$owner" == "$(whoami)" ]]; then
		chmod 1777 $propdir/tmp
	fi

	echo "Configuring ProP..." 1>&2
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
		$ROOT_DIR/scripts/helpers/config-signalp.sh
		# echo "WARNING: SignalP still needs to be configured." 1>&2
	else
		echo "SignalP has been previously configured." 1>&2
	fi
	sed -i "s|setenv SIGNALP.*|setenv SIGNALP $RUN_SIGNALP|" $RUN_PROP
	echo -e "\t\t\t\t\t...DONE." 1>&2
	touch $propdir/CONFIG.DONE
else
	echo "ProP has been previously configured." 1>&2
fi
