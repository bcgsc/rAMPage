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
		\tRuns the EnTAP annotation pipeline.\n \
		\tFor more information: https://entap.readthedocs.io/en/latest/introduction.html\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-a <address>] [-t <int>] -i <input FASTA file> -o <output directory> <database FASTA file(s)>\n \
		" | table

		echo -e "OPTION(S):"
		echo -e "\
		\t-a <address>\temail address for alerts\n \
		\t-h\tshow this help menu\n \
		\t-i <FASTA>\tinput FASTA file (required)\n \
		\t-o <directory>\toutput directory\t(required)\n \
		\t-t <int>\tnumber of threads\t(default = 8)\n \
		" | table

		echo -e "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com -t 8 -i /path/to/input.faa -o /path/to/output/directory nr.fasta uniprot.fasta\n \
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

# default parameters

# 4 - read options
email=false
outdir=""
threads=8
input=""
while getopts :a:hi:o:t: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	h) get_help ;;
	i) input=$(realpath $OPTARG) ;;
	o) outdir=$(realpath $OPTARG) ;;
	t) threads="$OPTARG" ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

# 5 - incorrect number of arguments
# if [[ "$#" -ne 1 ]]; then
# 	print_error "Incorrect number of arguments."
# fi

# 6 - check input files/options
if [[ -z $outdir ]]; then
	print_error "Required argument -o <output directory> missing."
else
	mkdir -p $outdir
fi

if [[ -z $input ]]; then
	print_error "Required argument -i <input FASTA file> missing."
else
	if [[ ! -f $input ]]; then
		print_error "Given input FASTA file $input does not exist."
	elif [[ ! -s $input ]]; then
		print_error "Given input FASTA file $input is empty."
	fi
fi

if [[ ! -v WORKDIR ]]; then
	workdir=$(dirname $outdir)
else
	workdir=$(realpath $WORKDIR)
fi

if [[ ! -v SPECIES ]]; then
	# get species from workdir
	species=$(echo "$workdir" | awk -F "/" '{print $(NF-1)}')
else
	species=$SPECIES
fi

if [[ ! -v CLASS ]]; then
	class=$(echo "$workdir" | awk -F "/" '{print $(NF-2)}')
else
	class=$CLASS
fi

if [[ "$#" -eq 0 ]]; then
	dbcustom=false
else
	dbcustom=true
fi

if [[ "$dbcustom" = true ]]; then
	# ignore eggnog protein db as separate entity
	if [[ "$class" == "amphibia" ]]; then
		databases=$(realpath $* | grep -vi 'eggnog_proteins.dmnd' | grep -wvi 'invertebrate' | tr '\n' ' ' | sed 's/ $//')
	elif [[ "$class" == "insecta" ]]; then
		databases=$(realpath $* | grep -vi 'eggnog_proteins.dmnd' | grep -wvi 'vertebrate' | tr '\n' ' ' | sed 's/ $//')
	else
		databases=$(realpath $* | grep -vi 'eggnog_proteins.dmnd' | tr '\n' ' ' | sed 's/ $//')
	fi

	for i in $databases; do
		if [[ ! -f $i ]]; then
			print_error "Given database $i does not exist."
		elif [[ ! -s $i ]]; then
			print_error "Given database $i is empty."
		fi
	done
fi

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi
# 7 remove status files
rm -f $outdir/ANNOTATION.DONE

# 8 - print env details
{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo -e "CALL: $args (wd: $(pwd))\n"
} 1>&2

echo "Checking EnTAP..." 1>&2
echo "PROGRAM: $(command -v $RUN_ENTAP)" 1>&2
echo "VERSION: $($RUN_ENTAP --version | awk '/version:/ {print $3}')" 1>&2

echo "Checking Java..." 1>&2
java_version=$($JAVA_EXEC -version 2>&1 | awk '/version/{print $3}' | sed 's/"//g')

if [[ "$java_version" != 1.8* ]]; then
	echo "ERROR: The InterProScan option in EnTAP requires Java Runtime Environment (JRE) 8." 1>&2
	echo "Java version detected: $java_version" 1>&2
	printf '%.0s=' $(seq 1 $(tput cols)) 1>&2
	echo 1>&2
	get_help
#	echo "The InterProScan option in EnTAP requires Java Runtime Environment (JRE) 8." 1>&2
fi

echo "Checking InterProScan..." 1>&2
echo "PROGRAM: $(command -v $RUN_INTERPROSCAN)" 1>&2
echo "VERSION: $($RUN_INTERPROSCAN --version | head -n1 | awk '{print $NF}')"
# CONFIG THE FILE
entap_dir=$(dirname $RUN_ENTAP)
config_custom=$outdir/entap_config.ini
# echo -e "Making a copy of entap_config.ini...\n" 1>&2
cp $entap_dir/entap_config.ini $config_custom

echo "Copying $entap_dir/entap_config.ini to $outdir..." 1>&2
echo "Specific changes made to $config_custom:" 1>&2
print_line
echo "taxon=$class" 1>&2
print_line

# set taxon
sed -i "s|^taxon=.*$|taxon=$class|" $config_custom

# CONFIGURE THE NECESSARY DATABASES
echo "PROGRAM: $(command -v $JAVA_EXEC)" 1>&2
echo -e "VERSION: $java_version\n" 1>&2
if [[ "$dbcustom" = true ]]; then
	db=$(echo "$databases" | sed 's/ / -d /g' | sed 's/^/-d /')
else
	db=""
fi

echo -e "COMMAND: $RUN_ENTAP --runP -i $input -t $threads --ini $config_custom  --out-dir $outdir $db\n" 1>&2
$RUN_ENTAP --runP -i $input -t $threads --ini $config_custom --out-dir $outdir $db

debugfile=$(ls -t debug_*.txt | head -n1)
logfile=$(ls -t log_file_*.txt | head -n1)

{
	echo "Log file: $logfile"
	echo -e "Debug file: $debugfile\n"
} 1>&2

default_name="$(realpath -s $(dirname $outdir)/annotation)"
if [[ "$default_name" != "$outdir" ]]; then
	if [[ -d "$default_name" ]]; then
		count=1
		if [[ ! -L "$default_name" ]]; then
			temp="${default_name}-${count}"
			while [[ -d "$temp" ]]; do
				count=$((count + 1))
				temp="${default_name}-${count}"
			done
			echo -e "Since $default_name already exists, $default_name is renamed to $temp as to not overwrite old trimmed reads.\n" 1>&2
			mv $default_name $temp
		else
			unlink $default_name
		fi
	fi
	if [[ "$default_name" != "$outdir" ]]; then
		echo -e "\n$outdir softlinked to $default_name\n" 1>&2
		(cd $(dirname $outdir) && ln -fs $(basename $outdir) $(basename $default_name))
	fi
fi
echo -e "END: $(date)\n" 1>&2
# echo 1>&2

echo -e "STATUS: DONE.\n" 1>&2
touch $outdir/ANNOTATION.DONE

echo "Output: $outdir/final_results/final_annotations_no_contam_lvl0.tsv" 1>&2

if [[ "$email" = true ]]; then
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	species=$(echo "$species" | sed 's/^./\u&. /')
	echo "$outdir" | mail -s "${species}: STAGE 11: ANNOTATION: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
