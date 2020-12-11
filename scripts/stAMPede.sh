#!/usr/bin/env bash
set -euo pipefail
PROGRAM=$(basename $0)
args="$PROGRAM $*"

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
		echo -e "PROGRAM: $PROGRAM\n"
		echo "DESCRIPTION:"
		echo -e "\
		\tA wrapper around rAMPage.sh to allow running of multiple assemblies.\n \
		" | table

		echo "USAGE(S)":
		echo -e "\
		\t$PROGRAM [-a <address>] [-p] [-s] [-v] <accessions TXT file>\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail alert\n \
		\t-h\tshow help menu\n \
		\t-p\tallow parallel processes for each dataset\n \
		\t-s\tsimultaenously run rAMPAge on all datasets\n \
		\t-v\tverbose (uses /usr/bin/time to time each rAMPage run)\n \
		" | table

		echo "ACCESSIONS TXT FORMAT:"
		echo -e "\
		\tCLASS/SPECIES/TISSUE_OR_CONDITION/input.txt strandedness\n \
		\tamphibia/ptoftae/skin-liver/input.txt nonstranded\n \
		\tinsecta/mgulosa/venom/input.txt stranded\n \
		" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com -p -s -v accessions.txt\n \
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

# 3 - no arguments given
if [[ "$#" -eq 0 ]]; then
	get_help
fi

email=false
parallel=false
verbose=false
multi=false
# 4 - get options
while getopts :ha:psv opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	h) get_help ;;
	p) parallel=true ;;
	s) multi=true ;;
	v) verbose=true ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

# 5 - wrong number arguments given
if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 check input files
if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "input file $(realpath $1) is empty."
fi

# 7 - remove status files
if [[ ! -v ROOT_DIR && ! -f "$ROOT_DIR/CONFIG.DONE" ]]; then
	echo "Environment variables have not been successfuly configured yet." 1>&2
	exit 1
fi
rm -f $ROOT_DIR/STAMPEDE.DONE

# 8 - print environemnt details

{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo -e "CALL: $args (wd: $(pwd))\n"
} 1>&2

input=$(realpath $1)

num_cols=$(awk '{print NF}' $input | sort -u)

if [[ "$num_cols" -ne 2 ]]; then
	print_error "Input file $input requires 2 columns."
fi

if [[ "$parallel" = true ]]; then
	parallel_opt="-p"
else
	parallel_opt=""
fi

if [[ "$verbose" = true ]]; then
	verbose_opt="-v"
else
	verbose_opt=""
fi

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi
if [[ "$multi" = false ]]; then
	while read path strandedness; do
		if [[ "$strandedness" != *[Ss][Tt][Rr][Aa][Nn][Dd][Ee][Dd] ]]; then
			print_error "Column 2 of $input must be 'stranded' or 'nonstranded'."
		fi

		if [[ "$strandedness" == [Ss][Tt][Rr][Aa][Nn][Dd][Ee][Dd] ]]; then
			strand_opt="-s"
		else
			strand_opt=""
		fi
		if [[ "$email" = true ]]; then
			email_opt="-a $address"
		else
			email_opt=""
		fi
		input_path=$(realpath $path)
		outdir=$(dirname $input_path)
		results+=($outdir)
		class=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}')
		species=$(echo "$outdir" | awk -F "/" '{print $(NF-1)}')
		echo "Running rAMPage on $(echo "$species" | sed 's/.\+/\L&/' | sed 's/^./\u&. /')..." 1>&2
		$ROOT_DIR/scripts/rAMPage.sh $email_opt $verbose_opt -o $outdir -c $class -n $species $strand_opt $parallel_opt $input_path 1>&2
		print_line
	done <$input
else
	while read path strandedness; do
		if [[ "$strandedness" != *[Ss][Tt][Rr][Aa][Nn][Dd][Ee][Dd] ]]; then
			print_error "Column 2 of $input must be 'stranded' or 'nonstranded'."
		fi

		if [[ "$strandedness" == [Ss][Tt][Rr][Aa][Nn][Dd][Ee][Dd] ]]; then
			strand_opt="-s"
		else
			strand_opt=""
		fi
		if [[ "$email" = true ]]; then
			email_opt="-a $address"
		else
			email_opt=""
		fi
		input_path=$(realpath $path)
		outdir=$(dirname $input_path)
		results+=($outdir)
		class=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}')
		species=$(echo "$outdir" | awk -F "/" '{print $(NF-1)}')
		mkdir -p $outdir/logs
		echo "Running rAMPage on $(echo "$species" | sed 's/.\+/\L&/' | sed 's/^./\u&. /')..." 1>&2
		echo -e "See $outdir/logs/00-rAMPage.log for details.\n" 1>&2
		$ROOT_DIR/scripts/rAMPage.sh $email_opt $verbose_opt -o $outdir -c $class -n $species $strand_opt $parallel_opt $input_path &>/dev/null &
	done <$input
	wait
fi
echo -e "END: $(date)\n" 1>&2
echo -e "STATUS: DONE\n" 1>&2

if [[ "${#results[@]}" -ne 0 ]]; then
	echo "Output:" 1>&2
	for i in ${results[@]}; do
		echo -e "\t - $i/amplify/amps.conf.short.charge.nr.faa"
	done | table 1>&2
fi
touch $ROOT_DIR/STAMPEDE.DONE

if [[ "$email" = true ]]; then
	# 	species=$(echo "$species" | sed 's/.\+/\L&/' | sed 's/^./\u&. /')
	# echo "$outdir" | mail -s "${species^}: rAMPage: SUCCESS" "$address"
	pwd | mail -s "stAMPede: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
