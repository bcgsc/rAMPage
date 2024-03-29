#!/usr/bin/env bash
set -euo pipefail
FULL_PROGRAM=$0
PROGRAM=$(basename $FULL_PROGRAM)
args="$FULL_PROGRAM $*"
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

	# DESCRIPTION
	{
		echo "DESCRIPTION:"
		echo -e "\
		\tExpands SRA accessions that are written with ranges (using hyphens), as individual accessions.\n \
		" | table

		# USAGEs
		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM <SRA accessions>\n \
		" | table

		# OPTIONS
		echo "OPTION(S):"
		echo -e "\
		\t-h\tshow this help menu\n \
		\t-s <separator>\toutput separator character\t(default = space)\n \
		" | table

		# EXAMPLE
		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM SRX12345-48 SRR12350\n \
		" | table
	} 1>&2
	exit 1
}
# 1.5 - print_line
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

# 3 - no arguments given
if [[ "$#" -eq 0 ]]; then
	get_help
fi
sep=' '

# 4 - get options
while getopts :hs: opt; do
	case $opt in
	h) get_help ;;
	s) sep=$OPTARG ;;
	\?)
		print_error "Invalid option: -$OPTARG"
		;;
	esac
done

shift $((OPTIND - 1))

# 5 - incorrect arguments given
if [[ "$#" -eq 0 ]]; then
	get_help
fi

# 6 - check inputs - no checks, are accessions not files

# 7 - no status files

# 8 - no env needed
{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo "CALL: $args (wd: $(pwd))"
} 1>&2

for i in $@; do
	# if the thing after the hyphen starts with a letter or not
	i=${i//,/}
	if [[ "$(echo "$i" | grep "\-" -c)" -gt 0 ]]; then
		first=$(echo "$i" | awk -F "-" '{print $1}')
		#		echo "first is $first"
		second=$(echo "$i" | awk -F "-" '{print $2}')
		#		echo "second is $second"
		if [[ "$second" == [0-9]* ]]; then
			prefix=${first:0:3}
			#			echo "prefix is $prefix"
			begin=${first:3} #12345
			#			echo "begin is $begin"
			len_begin=$(echo -n "$begin" | wc -m) #5
			#			echo "len_begin is $len_begin"
			len_second=$(echo -n "$second" | wc -m) #2
			#			echo "len_second is $len_second"
			diff=$((len_begin - len_second))
			#			echo "diff is $diff"
			begin_last_digits=$(echo "$begin" | cut -c $((diff + 1))-)
			#			echo "begin_last_digits is $begin_last_digits"
			end="${first:3:diff}$second"
			#			echo "end is $end"
			if [[ "$second" -le "$begin_last_digits" ]]; then
				#				echo "second is less than last digits"
				x="1$(printf '%0.s0' $(seq 1 $len_second))"
				end=$((end + x))
			fi

			seq $begin $end | sed "s/^/$prefix/"

		else
			prefix=${first:0:3}
			begin=${first:3}
			end=${second:3}
			seq $begin $end | sed "s/^/$prefix/"
		fi
	else
		echo "$i"
	fi
done | sed ":a;N;\$!ba;s/\n/${sep}/g" | sed "s/${sep}$/\n/"
# done | paste -s -d ' '
