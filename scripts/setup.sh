#!/bin/bash
set -euo pipefail

PROGRAM=$(basename $0)
function get_help() {
	# DESCRIPTION
	echo "DESCRIPTION:" 1>&2
	echo -e "\
		\tSets up directory structure for the pipeline.\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	# USAGE
	echo "USAGE(S):" 1>&2
	echo -e "\
		\t$PROGRAM [OPTIONS] <TSV file>\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	# OPTIONS
	echo "OPTION(S):" 1>&2
	echo -e "\
		\t-h\tshow this help menu\n \
		" | column -s$'\t' -t 1>&2
	echo 1>&2

	# TSV FORMAT
	echo "TSV FORMAT:" 1>&2
	echo -e "\tORDER/SPECIES/TISSUE\tSRA ACCESSION(S)\tSTRANDEDNESS" 1>&2
	echo 1>&2
	echo "TSV EXAMPLE: (no header)" 1>&2
	echo -e "\
		\tanura/xlaevis/liver\tSRX847156 SRX847157\tnonstranded\n \
		\thymenoptera/nvitripennis/venom_ovary\tSRP067692\tstranded\n \
		" | column -s$'\t' -t 1>&2
	exit 1
}

while getopts :h opt
do
	case $opt in 
		h) get_help;;
		\?) echo "ERROR: Invalid option: -$OPTARG" 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2; get_help;;
	esac
done

shift $((OPTIND-1))

if [[ "$#" -eq 0 ]]
then
	get_help
fi

if [[ "$#" -ne 1 ]]
then
	echo "ERROR: Incorrect number of arguments." 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2
    get_help
fi
if [[ -f $ROOT_DIR/SETUP.DONE ]]
then
	rm $ROOT_DIR/SETUP.DONE
fi

# check the master tsv
num_invalid=$(grep -icwvf <(echo -e "stranded\nnonstranded\nagnostic") <(cut -f3 -d$'\t' $1 | sort -u ))

if [[ "$num_invalid" -ne 0 ]]
then
	echo "ERROR: The third column must be 'stranded', 'nonstranded', or 'agnostic'." 1>&2; printf "%.0s=" $(seq 1 $(tput cols)) 1>&2; echo 1>&2
	get_help
fi
mkdir -p $ROOT_DIR/logs
while IFS=$'\t' read path accessions strand
do
	# make the directory
	mkdir -p $ROOT_DIR/${path}/logs

	# make the accessions file to read later
	$ROOT_DIR/scripts/expand-accessions.sh $accessions | tr ' ' '\n' > $ROOT_DIR/${path}/accessions.txt

	# make the stranded files
	if [[ "$strand" == [Ss][Tt][Rr][Aa][Nn][Dd][Ee][Dd] ]]
	then
		touch $ROOT_DIR/${path}/STRANDED.LIB
	elif [[ "$strand" == [Nn][Oo][Nn][Ss][Tt][Rr][Aa][Nn][Dd][Ee][Dd] ]]
	then
		touch $ROOT_DIR/${path}/NONSTRANDED.LIB
	elif [[ "$strand" == [Aa][Gg][Nn][Oo][Ss][Tt][Ii][Cc] ]]
	then
		touch $ROOT_DIR/${path}/AGNOSTIC.LIB
	fi

	order=$(echo "$path" | cut -f1 -d/)
	class=$($ROOT_DIR/scripts/get-class.sh $order 2> /dev/null)
#	while [[ "$?" -ne 0 ]]
#	do
	class=$($ROOT_DIR/scripts/get-class.sh $order 2> /dev/null)
#	done
	
	if [[ "$class" == [Aa]mphibia ]]
	then
		touch $ROOT_DIR/${path}/AMPHIBIA.CLASS
	elif [[ "$class" == [Ii]nsecta ]]
	then
		touch $ROOT_DIR/${path}/INSECTA.CLASS
	fi

done < $1

# check 
num_libs=$(ls $ROOT_DIR/*/*/*/*.LIB | wc -l)
num_class=$(ls $ROOT_DIR/*/*/*/*.CLASS | wc -l)
num_lines=$(wc -l $1 | awk '{print $1}')

if [[ "$num_lines" -ne "$num_libs" ]]
then
	echo "ERROR: Not every single directory has a .LIB file." 1>&2; printf "%.0s=" $(seq 1 $(tput cols)) 1>&2; echo 1>&2
	get_help
fi

if [[ "$num_lines" -ne "$num_class" ]]
then
	echo "ERROR: Not every single directory has a .CLASS file." 1>&2; printf "%.0s=" $(seq 1 $(tput cols)) 1>&2; echo 1>&2
	get_help
fi

mkdir -p $ROOT_DIR/amp_seqs
mkdir -p $ROOT_DIR/summary

touch $ROOT_DIR/SETUP.DONE
