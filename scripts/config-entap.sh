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

function get_help() {
	{
		echo -e "PROGRAM: $PROGRAM\n"
		echo "DESCRIPTION:"
		echo -e "\
		\tConfigures databases for EnTAP.\n
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-a <address>] [-h] [-t <int>] <FASTA database files>\n
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail address for alerts\n \
		\t-h\tshow this help menu\n \
		\t-t <int>\tnumber of threads\t(default = 8)\n \
		" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com -t 12 nr.fasta sprot_uniprot.fasta\n \
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
threads=8

if command -v $RUN_ENTAP &>/dev/null; then
	outdir=$(dirname $RUN_ENTAP)
else
	echo "ERROR: EnTAP program not found."
	exit 2
fi
custom_threads=false
while getopts :ha:t: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	h) get_help ;;
	t)
		threads="$OPTARG"
		custom_threads=true
		;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

# 6 incorrect arguments

# if [[ "$#" -eq 0 ]]; then
# print_error "Incorrect number of arguments."
# fi

if command -v pigz &>/dev/null; then
	if [[ "$custom_threads" = true ]]; then
		compress="pigz -p $threads"
	else
		compress=pigz
	fi
else
	compress=gzip
fi
if [[ "$#" -eq 0 ]]; then
	dbcustom=false
else
	dbcustom=true
fi

if [[ "$dbcustom" = true ]]; then
	# ignore eggnog protein db as separate entity
	databases=$(realpath $* | grep -vi 'eggnog_proteins.dmnd' | tr '\n' ' ' | sed 's/ $//')

	for i in $databases; do
		if [[ ! -f $i ]]; then
			print_error "Given database $i does not exist."
		elif [[ ! -s $i ]]; then
			print_error "Given database $i is empty."
		fi

		# if all exists, check that they are decompressed
		if [[ "$i" == *.gz ]]; then
			${compress} -d $i
		fi
	done

	databases=${databases//.gz/}

	# rename the databases
	for i in $databases; do
		dir=$(dirname $i)
		base=$(basename $i)
		filename=${base%.*}   # long file name, no extension
		extension=${base##*.} # short extension

		filename=${filename/./_}
		newfullname=${dir}/${filename}.${extension}
		if [[ "$i" != "$newfullname" ]]; then
			mv $i ${newfullname}
			databases=${databases/$i/$newfullname}
		fi
	done

	# if [[ "$(for i in $databases; do basename $i | cut -f1 -d.; done | sort | uniq -d | wc -l)" -ne 0 ]]; then
	# 	echo "ERROR: When configuring EnTAP databases, the databases will be named based on the string before the first period. There are FASTA files given that will yield identical file names after configuration. Please rename one of them and configure again." 1>&2
	# 	exit 2
	# fi
fi

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

# 7 remove status files
rm -f $outdir/CONFIG.DONE

# 8 - print env details
{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo "CALL: $args (wd: $(pwd))"
	echo -e "THREADS: $threads\n"
} 1>&2

echo "Checking EnTAP..." 1>&2
echo "PROGRAM: $(command -v $RUN_ENTAP)" 1>&2
echo -e "VERSION: $($RUN_ENTAP --version | awk '/version:/ {print $3}')\n" 1>&2

entap_dir=$(dirname $RUN_ENTAP)
if [[ "$dbcustom" = true ]]; then
	db=$(echo "$databases" | sed 's/ / -d /g' | sed 's/^/-d /')
else
	db=""
fi

# set diamond
# echo "Setting diamond-exe=$RUN_DIAMOND..." 1>&2
sed -i "s|diamond-exe=.*|diamond-exe=$RUN_DIAMOND|" $outdir/entap_config.ini

# set graphing
# echo "Setting entap-graph=$entap_dir/src/entap_graphing.py..." 1>&2
sed -i "s|^entap-graph=.*$|entap-graph=$entap_dir/src/entap_graphing.py|" $outdir/entap_config.ini

# set interproscan
# echo "Setting interproscan-exe=$RUN_INTERPROSCAN..." 1>&2
sed -i "s|^interproscan-exe=.*$|interproscan-exe=$RUN_INTERPROSCAN|" $outdir/entap_config.ini

# set the contams
# echo "Setting contam=bacteria,fungi..." 1>&2
sed -i 's/^contam=.*$/contam=bacteria,fungi/' $outdir/entap_config.ini

# set ontology
# echo "Setting ontology=0,1..." 1>&2
sed -i 's/^ontology=.*/ontology=0,1/' $outdir/entap_config.ini

# set the ontology databases
# echo "Setting protein=pfam..." 1>&2
sed -i 's/^protein=.*$/protein=pfam/' $outdir/entap_config.ini

# echo -e "Setting level=0...\n" 1>&2
sed -i 's/^level=.*/level=0/' $outdir/entap_config.ini
# set complete proteins
# echo "Setting complete=true..." 1>&2
# sed -i 's/^complete=.*$/complete=true/'$outdir/entap_config.ini

sed -i 's/^output-format=.*/output-format=1,3/' $outdir/entap_config.ini
echo "Changes made to the config file $outdir/entap_config.ini:" 1>&2
print_line
echo -e "\
diamond-exe=$RUN_DIAMOND\n \
entap-graph=$entap_dir/src/entap_graphing.py\n \
interproscan-exe=$RUN_INTERPROSCAN\n \
contam=bacteria,fungi\n \
ontology=0,1\n \
protein=pfam\n \
level=0 \n \
output-format=1,3 \
" 1>&2
print_line

echo -e "COMMAND: $RUN_ENTAP --config $db -t $threads --ini $outdir/entap_config.ini --out-dir $outdir" | tee $outdir/config-entap.log 1>&2

$RUN_ENTAP --config $db -t $threads --ini $outdir/entap_config.ini --out-dir $outdir &>>$outdir/config-entap.log

# maybe grep the log file for this?
logfile=$(ls -t $outdir/log_file_*.txt | head -n1)
debugfile=$(ls -t $outdir/debug_*.txt | head -n1)

entap_db=$(awk '/Database written to:/ {print $NF}' $logfile)
# echo "Setting entap-db-bin=$entap_db..." 1>&2
sed -i "s|^entap-db-bin=.*|entap-db-bin=$entap_db|" $outdir/entap_config.ini
eggnog_db=$(awk '/DIAMOND EggNOG database written to:/ {print $NF}' $logfile)
# echo "Setting eggnog-dmnd=$eggnog_db..." 1>&2
sed -i "s|^eggnog-dmnd=.*|eggnog-dmnd=$eggnog_db|" $outdir/entap_config.ini
eggnog_sql=$(awk '/EggNOG SQL database written to:/ {print $NF}' $logfile)
# echo -e "Setting eggnog-sql=$eggnog_sql...\n" 1>&2
sed -i "s|^eggnog-sql=.*|eggnog-dmnd=$eggnog_sql|" $outdir/entap_config.ini

echo "Updating the config file $entap_dir/entap_config.ini:" 1>&2
print_line
echo -e "\
entap-db-bin=$entap_db\n \
eggnog-dmnd=$eggnog_db\n \
eggnog-sql=$eggnog_db \
" 1>&2
print_line

{
	echo "Log file: $logfile"
	echo -e "Debug file: $debugfile\n"
} 1>&2

echo -e "END: $(date)\n" 1>&2

echo -e "STATUS: DONE.\n" 1>&2
touch $outdir/CONFIG.DONE

if [[ "$email" = true ]]; then
	echo "$outdir" | mail -s "ENTAP CONFIGURATION: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
