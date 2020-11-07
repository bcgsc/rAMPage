#!/bin/bash

#$@ = SRX12345-48 SRR12350
PROGRAM=$(basename $0)
function get_help() {

	# DESCRIPTION
	echo "DESCRIPTION:" 1>&2
	echo -e "\
		\tExpands SRA accessions that are written with ranges (using hyphens), as individual accessions.\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2
	# USAGEs

	echo "USAGE(S):" 1>&2
	echo -e "\
		\t$PROGRAM <SRA accessions>\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	# OPTIONS
	echo "OPTION(S):" 1>&2
	echo -e "\
		\t-h\tshow this help menu\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	# EXAMPLE
	echo "EXAMPLE(S):" 1>&2
	echo -e "\
		\t$PROGRAM SRX12345-48 SRR12350\n \
		" | column -s $'\t' -t 1>&2
	exit 1
}
while getopts :h opt
do
	case $opt in
		h) get_help;;
		\?) echo "ERROR: Invalid option: -$OPTARG" 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2 ;echo 1>&2;get_help;;
	esac
done

shift $((OPTIND-1))

if [[ "$#" -eq 0 ]]
then
	get_help
fi

for i in $@
do
	# if the thing after the hyphen starts with a letter or not
	if [[ "$(echo "$i" | grep "\-" -c)" -gt 0 ]]
	then
		first=$(echo "$i" | awk -F "-" '{print $1}')
#		echo "first is $first"
		second=$(echo "$i" | awk -F "-" '{print $2}')
#		echo "second is $second"
		if [[ "$second" == [0-9]* ]]
		then
			prefix=${first:0:3}
#			echo "prefix is $prefix"
			begin=${first:3} #12345
#			echo "begin is $begin"
			len_begin=$(echo -n "$begin" | wc -m) #5
#			echo "len_begin is $len_begin"
			len_second=$(echo -n "$second" | wc -m) #2
#			echo "len_second is $len_second"
			diff=$(( len_begin - len_second ))
#			echo "diff is $diff"
			begin_last_digits=$(echo "$begin" | cut -c $((diff+1))-)
#			echo "begin_last_digits is $begin_last_digits"
			end="${first:3:diff}$second"
#			echo "end is $end"
			if [[ "$second" -le "$begin_last_digits" ]]
			then
#				echo "second is less than last digits"
				x="1$(printf '%0.s0' $(seq 1 $len_second))"
				end=$((end + x ))
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
done | tr '\n' ' ' | sed 's/ $//'
# done | paste -s -d ' '
