#!/usr/bin/env bash
set -uo pipefail
FULL_PROGRAM=$0
PROGRAM=$(basename $FULL_PROGRAM)

if [[ "$PROGRAM" == "slurm_script" ]]; then
	FULL_PROGRAM=$(scontrol show job $SLURM_JOBID | awk '/Command=/ {print $1}' | awk -F "=" '{print $2}')
	PROGRAM=$(basename ${FULL_PROGRAM})

fi
args="$FULL_PROGRAM $*"

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
		\t$PROGRAM [-a <address>] [-h] [-t <int>] -i <input FASTA file> -f <input TSV file> -o <output directory> <database DMND file(s)>\n \
		" | table

		echo -e "OPTION(S):"
		echo -e "\
		\t-a <address>\temail address for alerts\n \
		\t-f <file>\tinput TSV file\t(required)\n \
		\t-h\tshow this help menu\n \
		\t-i <file>\tinput FASTA file\t(required)\n \
		\t-o <directory>\toutput directory\t(required)\n \
		\t-t <int>\tnumber of threads\t(default = 8)\n \
		" | table

		echo -e "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com -t 8 -o /path/to/annotation/outdir -i /path/to/amplify/amps.final.faa -f /path/to/amplify/AMPlify_results.final.tsv nr.dmnd uniprot.dmnd\n \
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
amplify_tsv=""
while getopts :a:f:hi:o:t: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	f) amplify_tsv=$(realpath -s $OPTARG) ;;
	h) get_help ;;
	i) input=$(realpath -s $OPTARG) ;;
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

if command -v mlr &>/dev/null; then
	mlr_bool=true
else
	mlr_bool=false
fi

if [[ -z $input ]]; then
	print_error "Required argument -i <input FASTA file> missing."
else
	if [[ ! -f $input ]]; then
		print_error "Given input FASTA file $input does not exist."
	elif [[ ! -s $input ]]; then
		if [[ -z $amplify_tsv ]]; then
			print_error "Required argument -f <input TSV file> missing."
		fi
		echo "Given input FASTA file $input is empty. There are no sequences to annotate." 1>&2
		echo -e "\nNumber of annotated AMPs: 0" 1>&2
		rm -f $outdir/ANNOTATION.FAIL
		touch $outdir/ANNOTATION.DONE
		mkdir -p $outdir/final_results
		touch $outdir/final_results/final_annotations.final.tsv
		touch $outdir/final_results/final_annotated.faa
		touch $outdir/amps.final.annotated.faa

		echo -e "Query Sequence\tSubject Sequence\tPercent Identical\tAlignment Length\tMismatches\tGap Openings\tQuery Start\tQuery End\tSubject Start\tSubject End\tE Value\tCoverage\tDescription\tSpecies\tTaxonomic Lineage\tOrigin Database\tContaminant\tInformative\tUniProt Database Cross Reference\tUniProt Additional Information\tUniProt KEGG Terms\tUniProt GO Biological\tUniProt GO Cellular\tUniProt GO Molecular\tEggNOG Seed Ortholog\tEggNOG Seed E-Value\tEggNOG Seed Score\tEggNOG Predicted Gene\tEggNOG Tax Scope\tEggNOG Tax Scope Max\tEggNOG Member OGs\tEggNOG Description\tEggNOG KEGG Terms\tEggNOG GO Biological\tEggNOG GO Cellular\tEggNOG GO Molecular\tEggNOG Protein Domains\tIPScan GO Biological\tIPScan GO Cellular\tIPScan GO Molecular\tIPScan Pathways\tIPScan InterPro ID\tIPScan Protein Database\tIPScan Protein Description\tIPScan E-Value" >$outdir/final_results/final_annotations.final.tsv

		# if [[ "$mlr_bool" = true ]]; then
		# join previous tsv
		# mlr --tsv join -f $amplify_tsv -l "Sequence_ID" -r "Query Sequence" -j "Sequence_ID" $outdir/final_results/final_annotations.final.tsv >$outdir/final_annotations.final.tsv
		# else
		# since these files are only one line long, no need to sort
		join -t$'\t' --header $amplify_tsv $outdir/final_results/final_annotations.final.tsv >$outdir/final_annotations.final.tsv
		# fi
		# join with AMPlify TSV instead of soft linking
		# (cd $outdir && ln -fs final_results/final_annotations.final.tsv final_annotations.final.tsv)

		if [[ "$email" = true ]]; then
			# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
			species=$(echo "$species" | sed 's/^./\u&. /')
			echo "$outdir" | mail -s "${species}: STAGE 11: ANNOTATION: SUCCESS" "$address"
			echo -e "\nEmail alert sent to $address." 1>&2
		fi
		exit 0
		# print_error "Given input FASTA file $input is empty."
	fi
fi

if [[ -z $amplify_tsv ]]; then
	print_error "Required argument -i <input FASTA file> missing."
fi

if [[ "$#" -eq 0 ]]; then
	dbcustom=false
else
	dbcustom=true
fi

if [[ "$dbcustom" = true ]]; then
	# ignore eggnog protein db as separate entity
	if [[ "$class" == "amphibia" ]]; then
		databases=$(realpath $* | grep -vi 'eggnog_proteins.dmnd' | grep -vi 'invertebrate' | tr '\n' ' ' | sed 's/ $//')
	elif [[ "$class" == "insecta" ]]; then
		databases=$(realpath $* | grep -vi 'eggnog_proteins.dmnd' | grep -vi 'vertebrate' | tr '\n' ' ' | sed 's/ $//')
		databases="$databases $(realpath $* | grep -vi 'eggnog_proteins.dmnd' | grep -i 'invertebrate')"
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
	echo -e "System does not have email setup.\n" 1>&2
fi
# 7 remove status files
rm -f $outdir/ANNOTATION.DONE
rm -f $outdir/ANNOTATION.FAIL

if ! command -v $JAVA_EXEC &>/dev/null; then
	print_error "JAVA_EXEC has not been set in scripts/config.sh."
fi

export PATH=$(dirname $JAVA_EXEC):$PATH
# 8 - print env details
{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo "CALL: $args (wd: $(pwd))"
	if [[ -L $input ]]; then
		echo "INPUT:"
		echo -e "\t$(ls -l $input | awk '{print $(NF-2), $(NF-1), $NF}' || exit 1)"
	fi
	if [[ -L $amplify_tsv ]]; then
		echo -e "\t$(ls -l $amplify_tsv | awk '{print $(NF-2), $(NF-1), $NF}' || exit 1)\n"
	fi
	echo -e "THREADS: $threads\n"
} 1>&2

echo "Checking EnTAP..." 1>&2
if [[ ! -v RUN_ENTAP ]]; then
	# look in PATH
	if command -v EnTAP &>/dev/null; then
		RUN_ENTAP=$(command -v EnTAP)
	else
		print_error "RUN_ENTAP is unbound and no 'EnTAP' found in PATH. Please export RUN_ENTAP=/path/to/EnTAP/executable." 1>&2
	fi
elif ! command -v $RUN_ENTAP &>/dev/null; then
	print_error "Unable to execute $RUN_ENTAP." 1>&2
fi

echo "PROGRAM: $(command -v $RUN_ENTAP)" 1>&2
echo -e "VERSION: $($RUN_ENTAP --version | awk '/version:/ {print $3}' || exit 1)\n" 1>&2

echo "Checking Java..." 1>&2

if [[ ! -v JAVA_EXEC ]]; then
	# look in PATH
	if command -v JAVA_EXEC &>/dev/null; then
		JAVA_EXEC=$(command -v java)
	else
		print_error "JAVA_EXEC is unbound and no 'java' found in PATH. Please export JAVA_EXEC=/path/to/java/executable." 1>&2
	fi
elif ! command -v $JAVA_EXEC &>/dev/null; then
	print_error "Unable to execute $JAVA_EXEC." 1>&2
fi

java_version=$($JAVA_EXEC -version 2>&1 | awk '/version/{print $3}' | sed 's/"//g' || exit 1)

if [[ "$java_version" != 1.8* ]]; then
	echo "ERROR: The InterProScan option in EnTAP requires Java Runtime Environment (JRE) 8." 1>&2
	echo "Java version detected: $java_version" 1>&2
	printf '%.0s=' $(seq 1 $(tput cols)) 1>&2
	echo 1>&2
	get_help
#	echo "The InterProScan option in EnTAP requires Java Runtime Environment (JRE) 8." 1>&2
fi
echo "PROGRAM: $(command -v $JAVA_EXEC || exit 1)" 1>&2
echo -e "VERSION: $java_version\n" 1>&2

echo "Checking InterProScan..." 1>&2

if [[ ! -v RUN_INTERPROSCAN ]]; then
	if command -v interproscan.sh &>/dev/null; then
		RUN_INTERPROSCAN=$(command -v interproscan.sh)
	else
		print_error "RUN_INTERPROSCAN is unbound and no 'interproscan.sh' found in PATH. Please export RUN_INTERPROSCAN=/path/to/interproscan.sh."
	fi
elif ! command -v $RUN_INTERPROSCAN &>/dev/null; then
	print_error "Unable to execute $RUN_INTERPROSCAN."
fi

echo "PROGRAM: $(command -v $RUN_INTERPROSCAN || exit 1)" 1>&2
echo "VERSION: $($RUN_INTERPROSCAN --version | head -n1 | awk '{print $NF}' || exit 1)"
# CONFIG THE FILE
entap_dir=$(dirname $RUN_ENTAP)
config_custom=$outdir/entap_config.ini
# echo -e "Making a copy of entap_config.ini...\n" 1>&2
cp $entap_dir/entap_config.ini $config_custom

echo -e "Copying $entap_dir/entap_config.ini to $outdir...\n" 1>&2
echo "Specific changes made to $config_custom:" 1>&2
print_line
echo "taxon=$class" 1>&2
print_line
echo 1>&2
# set taxon
sed -i "s|^taxon=.*$|taxon=$class|" $config_custom

## CONFIGURE THE NECESSARY DATABASES
if [[ "$dbcustom" = true ]]; then
	db=$(echo "$databases" | sed 's/ / -d /g' | sed 's/^/-d /')
else
	db=""
fi
echo -e "COMMAND: $RUN_ENTAP --runP -i $input -t $threads --ini $config_custom  --out-dir $outdir $db &> $outdir/entap.log\n" 1>&2
$RUN_ENTAP --overwrite --runP -i $input -t $threads --ini $config_custom --out-dir $outdir $db &>$outdir/entap.log

code="$?"

if [[ "$code" -eq 140 ]]; then
	echo -e "WARNING: No alignments found using DIAMOND.\n" 1>&2
	mkdir -p $outdir/ontology/InterProScan
	## Do InterProScan individually here
	echo "Running InterProScan separately from EnTAP..." 1>&2
	echo -e "COMMAND: $RUN_INTERPROSCAN -i $input -b $outdir/ontology/InterProScan/interpro_results --seqtype p --tempdir $outdir/ontology/InterProScan/temp/ --goterms --iprlookup --pathways &>$outdir/ontology/InterProScan.log\n" 1>&2
	$RUN_INTERPROSCAN -i $input -b $outdir/ontology/InterProScan/interpro_results --seqtype p --tempdir $outdir/ontology/InterProScan/temp/ --goterms --iprlookup --pathways &>$outdir/ontology/InterProScan.log
elif [[ "$code" -eq 0 ]]; then
	: # do nothing, continue with script
else
	# FAILED DUE TO SOME OTHER REASON

	echo -e "\nEND: $(date)\n" 1>&2
	# echo 1>&2

	echo -e "STATUS: FAILED.\n" 1>&2
	touch $outdir/ANNOTATION.FAIL

	if [[ "$email" = true ]]; then
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		species=$(echo "$species" | sed 's/^./\u&. /')
		echo "$outdir" | mail -s "${species}: STAGE 11: ANNOTATION: FAILED" "$address"
		echo -e "\nEmail alert sent to $address." 1>&2
	fi
	exit $code
fi

debugfile=$(ls -t $outdir/debug_*.txt | head -n1 || exit 1)
logfile=$(ls -t $outdir/log_file_*.txt | head -n1 || exit 1)
interproscan_logfile=$(ls -t $outdir/ontology/InterProScan.log | head -n1 || exit 1)
{
	echo "Log file: $logfile"
	echo -e "Debug file: $debugfile\n"
} 1>&2

if [[ "$code" -eq 140 ]]; then
	echo -e "InterProScan logfile: $interproscan_logfile\n" 1>&2
fi
# choose the tsv that is not empty to symlink

# use no contaminant for level 0 for no contaminants if found
final_tsv=$outdir/final_annotations.final.tsv
if [[ "$code" -eq 0 ]]; then
	if [[ -s "$outdir/final_results/final_annotations_no_contam_lvl0.tsv" && "$(wc -l $outdir/final_results/final_annotations_no_contam_lvl0.tsv | awk '{print $1}')" -gt 1 ]]; then
		(cd $outdir/final_results && ln -fs final_annotations_no_contam_lvl0.tsv final_annotations.final.tsv)
	# use no contaminant for level 1 for no contaminants if level 1 wasn't found
	elif [[ -s "$outdir/final_results/final_annotations_no_contam_lvl1.tsv" && "$(wc -l $outdir/final_results/final_annotations_no_contam_lvl1.tsv | awk '{print $1}')" -gt 1 ]]; then
		(cd $outdir/final_results && ln -fs final_annotations_no_contam_lvl1.tsv final_annotations.final.tsv)
	# use with contaminant for level 0 if available
	elif [[ -s "$outdir/final_results/final_annotations_lvl0.tsv" && "$(wc -l $outdir/final_results/final_annotations_lvl0.tsv | awk '{print $1}')" -gt 1 ]]; then
		(cd $outdir/final_results && ln -fs final_annotations_lvl0.tsv final_annotations.final.tsv)
	# use with contaminants for level 1 if available
	elif [[ -s "$outdir/final_results/final_anntations_lvl1.tsv" && "$(wc -l $outdir/final_results/final_annotations_lvl1.tsv | awk '{print $1}')" -gt 1 ]]; then
		(cd $outdir/final_results && ln -fs final_annotations_lvl1.tsv final_annotations.final.tsv)
	fi

	if [[ "$mlr_bool" = true ]]; then
		mlr --tsv join -f $amplify_tsv -l "Sequence_ID" -r "Query Sequence" -j "Sequence_ID" $outdir/final_results/final_annotations.final.tsv >$outdir/final_annotations.final.tsv
	else
		# manual join
		join --header -t $'\t' <(LC_COLLATE=C sort -t$'\t' -k1,1 $amplify_tsv) <(LC_COLLATE=C sort -t$'\t' -k1,1 $outdir/final_results/final_annotations.final.tsv) >$outdir/final_annotations.final.tsv
	fi
	# join with AMPlify TSV instead of soft linking
	# (cd $outdir && ln -fs final_results/final_annotations.final.tsv final_annotations.final.tsv)

	processed=$outdir/$(basename $input | sed 's/.faa$/.annotated.faa/')
	cp $input $processed
	for seq in $(awk -F ">" '/^>/ {print $2}' $outdir/final_results/final_annotated.faa); do
		# sed -i "/${seq} / s/ length=/-annotated&/" $processed
		subject=$(awk -F "\t" -v var=$seq '{if($1==var) print $2}' $final_tsv)
		if [[ -n $subject ]]; then
			sed -i "/>${seq} / s/$/ diamond=$subject/" $processed
		fi
		taxonomy=$(awk -F "\t" -v var=$seq '{if($1==var) print $14}' $final_tsv | tr ' ' '_')
		if [[ -n $taxonomy ]]; then
			sed -i "/>${seq} / s/$/ taxonomy=$taxonomy/" $processed
		fi
		ipscan=$(awk -F "\t" -v var=$seq '{if ($1==var) print $44}' $final_tsv | cut -d \( -f1)
		if [[ -n $ipscan ]]; then
			ipscan=$(echo "$ipscan" | sed '/^>/ s/,*NA,*//g')
			sed -i "/>${seq} / s/$/ InterProScan=$ipscan/" $processed
		fi
		# sed -i "s/${seq}\t/${seq}-annotated\t/" $final_tsv
	done
else
	processed=$outdir/$(basename $input | sed 's/.faa$/.annotated.faa/')
	cp $input $processed # identical
	entap_tsv=$outdir/final_results/final_annotations.final.tsv
	# final_tsv=$outdir/final_annotations.final.tsv
	echo -e "Query Sequence\tSubject Sequence\tPercent Identical\tAlignment Length\tMismatches\tGap Openings\tQuery Start\tQuery End\tSubject Start\tSubject End\tE Value\tCoverage\tDescription\tSpecies\tTaxonomic Lineage\tOrigin Database\tContaminant\tInformative\tUniProt Database Cross Reference\tUniProt Additional Information\tUniProt KEGG Terms\tUniProt GO Biological\tUniProt GO Cellular\tUniProt GO Molecular\tEggNOG Seed Ortholog\tEggNOG Seed E-Value\tEggNOG Seed Score\tEggNOG Predicted Gene\tEggNOG Tax Scope\tEggNOG Tax Scope Max\tEggNOG Member OGs\tEggNOG Description\tEggNOG KEGG Terms\tEggNOG GO Biological\tEggNOG GO Cellular\tEggNOG GO Molecular\tEggNOG Protein Domains\tIPScan GO Biological\tIPScan GO Cellular\tIPScan GO Molecular\tIPScan Pathways\tIPScan InterPro ID\tIPScan Protein Database\tIPScan Protein Description\tIPScan E-Value" >$entap_tsv
	# >$final_tsv

	# read custom IPscan
	if [[ "$code" -eq 140 ]]; then
		# read the InterProScan tsv file
		for i in $(awk '/^>/ {print $1}' $processed | tr -d '>'); do
			interproscan_results=$outdir/ontology/InterProScan/interpro_results.tsv
			line=$(grep -w "$i" $interproscan_results)

			if [[ $(echo "$line" | wc -l) -gt 1 ]]; then
				ipscan_go1=$(echo "$line" | awk -F "\t" '{print $14}' | awk -F "|" '{print $1}' | sed 's/^ *,/NA,/g')
				if [[ -n "$ipscan_go1" ]]; then
					ipscan_go1=$(echo "$ipscan_go1" | tr "\n" "," | sed 's/,\+$//g' | sed 's/^ *,/NA,/g')
				fi
				ipscan_go2=$(echo "$line" | awk -F "\t" '{print $14}' | awk -F "|" '{print $2}' | sed 's/^ *,/NA,/g')
				if [[ -n "$ipscan_go2" ]]; then
					ipscan_go2=$(echo "$ipscan_go2" | tr "\n" "," | sed 's/,\+$//g' | sed 's/^ *,/NA,/g')
				fi
				ipscan_go3=$(echo "$line" | awk -F "\t" '{print $14}' | awk -F "|" '{print $3}' | sed 's/^ *,/NA,/g')
				if [[ -n "$ipscan_go3" ]]; then
					ipscan_go3=$(echo "$ipscan_go3" | tr "\n" "," | sed 's/,\+$//g' | sed 's/^ *,/NA,/g')
				fi
				ipscan_pathways=$(echo "$line" | awk -F "\t" '{print $15}')
				if [[ -n "$ipscan_pathways" ]]; then
					ipscan_pathways=$(echo "$ipscan_pathways" | tr "\n" "," | sed 's/,\+$//g' | sed 's/^ *,/NA,/g')
				fi
				ipscan_id=$(echo "$line" | awk -F "\t" '{print $12 "(" $13 ")"}' | sed 's/()//' | sed 's/^ *,/NA,/g')
				if [[ -n "$ipscan_id" ]]; then
					ipscan_id=$(echo "$ipscan_id" | tr "\n" "," | sed 's/,\+$//g' | sed 's/^ *,/NA,/g')
				fi
				ipscan_db=$(echo "$line" | awk -F "\t" '{print $4}' | sed 's/^ *,/NA,/g')
				if [[ -n "$ipscan_db" ]]; then
					ipscan_db=$(echo "$ipscan_db" | tr "\n" "," | sed 's/,\+$//g' | sed 's/^ *,/NA,/g')
				fi
				ipscan_pfam=$(echo "$line" | awk -F "\t" '{print $5 "(" $6 ")"}' | sed 's/()//' | sed 's/^ *,/NA,/g')
				if [[ -n "$ipscan_pfam" ]]; then
					ipscan_pfam=$(echo "$ipscan_pfam" | tr "\n" "," | sed 's/,\+$//g' | sed 's/^ *,/NA,/g')
				fi
				ipscan_eval=$(echo "$line" | awk -F "\t" '{print $9}' | sed 's/^ *,/NA,/g')
				if [[ -n "$ipscan_eval" ]]; then
					ipscan_eval=$(echo "$ipscan_eval" | tr "\n" "," | sed 's/,\+$//g' | sed 's/,-/,NA/g' | sed 's/-,/NA,/g' | sed 's/^-$/NA/g' | sed 's/^ *,/NA,/g')
				fi
			else
				ipscan_go1=$(echo "$line" | awk -F "\t" '{print $14}' | awk -F "|" '{print $1}')
				ipscan_go2=$(echo "$line" | awk -F "\t" '{print $14}' | awk -F "|" '{print $2}')
				ipscan_go3=$(echo "$line" | awk -F "\t" '{print $14}' | awk -F "|" '{print $3}')
				ipscan_pathways=$(echo "$line" | awk -F "\t" '{print $15}')
				ipscan_id=$(echo "$line" | awk -F "\t" '{print $12 "(" $13 ")"}' | sed 's/()//')
				ipscan_db=$(echo "$line" | awk -F "\t" '{print $4}')
				ipscan_pfam=$(echo "$line" | awk -F "\t" '{print $5 "(" $6 ")"}' | sed 's/()//')
				ipscan_eval=$(echo "$line" | awk -F "\t" '{print $9}')
				if [[ "$ipscan_eval" = "-" ]]; then
					ipscan_eval="NA"
				fi
			fi
			# echo "ipscan_go1: $ipscan_go1"
			# echo "ipscan_go2: $ipscan_go2"
			# echo "ipscan_go3: $ipscan_go3"
			# echo "ipscan_pathways: $ipscan_pathways"
			# echo "ipscan_id: $ipscan_id"
			# echo "ipscan_db: $ipscan_db"
			# echo "ipscan_pfam: $ipscan_pfam"
			# echo "ipscan_eval: $ipscan_eval"
			echo -e "${i}\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t$ipscan_go1\t$ipscan_go2\t$ipscan_go3\t$ipscan_pathways\t$ipscan_id\t$ipscan_db\t$ipscan_pfam\t$ipscan_eval" >>$entap_tsv # >>$final_tsv
			ipscan=$(echo "$ipscan_id" | awk -F "(" '{print $1}' | tr $'\n' ',' | sed 's/,\+$//g' | sed 's/^,\+//g')
			# echo "$ipscan"
			if [[ -n $ipscan ]]; then
				# echo "$ipscan"
				ipscan=$(echo "$ipscan" | sed '/^>/ s/,*NA,*//g')
				sed -i "/>${i} / s/$/ InterProScan=$ipscan/" $processed
			fi
		done
	else
		for i in $(awk '/^>/ {print $1}' $processed | tr -d '>'); do

			echo -e "${i}\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t\t" >>$entap_tsv # >>$final_tsv
		done
	fi
	# join here
	if [[ "$mlr_bool" = true ]]; then
		mlr --tsv join -f $amplify_tsv -l "Sequence_ID" -r "Query Sequence" -j "Sequence_ID" $entap_tsv >$final_tsv
	else
		# manual join
		join --header -t $'\t' <(LC_COLLATE=C sort -t$'\t' -k1,1 $amplify_tsv) <(LC_COLLATE=C sort -t$'\t' -k1,1 $entap_tsv) >$final_tsv
	fi
fi

if [[ -f $outdir/final_results/final_annotated.faa ]]; then
	num_annotated=$(grep -c '^>' $outdir/final_results/final_annotated.faa)
else
	num_annotated=$(cut -f1 -d$'\t' $outdir/ontology/InterProScan/interpro_results.tsv | sort -u | wc -l)
fi

num_total=$(grep -c '^>' $processed)

echo -e "Number of annotated AMPs: $(printf "%'d" $num_annotated)/$(printf "%'d" $num_total)\n" 1>&2

echo -e "Output(s): $final_tsv\n $processed\n \
	" | column -s ' ' -t 1>&2

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
echo -e "\nEND: $(date)\n" 1>&2
# echo 1>&2

echo -e "STATUS: DONE.\n" 1>&2
touch $outdir/ANNOTATION.DONE

if [[ "$email" = true ]]; then
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	species=$(echo "$species" | sed 's/^./\u&. /')
	echo "$outdir" | mail -s "${species}: STAGE 11: ANNOTATION: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi

# 1 Query Sequence
# 2 Subject Sequence
# 3 Percent Identical
# 4 Alignment Length
# 5 Mismatches
# 6 Gap Openings
# 7 Query Start
# 8 Query End
# 9 Subject Start
# 10 Subject End
# 11 E Value
# 12 Coverage
# 13 Description
# 14 Species
# 15 Taxonomic Lineage
# 16 Origin Database
# 17 Contaminant
# 18 Informative
# 19 UniProt Database Cross Reference
# 20 UniProt Additional Information
# 21 UniProt KEGG Terms
# 22 UniProt GO Biological
# 23 UniProt GO Cellular
# 24 UniProt GO Molecular
# 25 EggNOG Seed Ortholog
# 26 EggNOG Seed E-Value
# 27 EggNOG Seed Score
# 28 EggNOG Predicted Gene
# 29 EggNOG Tax Scope
# 30 EggNOG Tax Scope Max
# 31 EggNOG Member OGs
# 32 EggNOG Description
# 33 EggNOG KEGG Terms
# 34 EggNOG GO Biological
# 35 EggNOG GO Cellular
# 36 EggNOG GO Molecular
# 37 EggNOG Protein Domains
# 38 IPScan GO Biological
# 39 IPScan GO Cellular
# 40 IPScan GO Molecular
# 41 IPScan Pathways
# 42 IPScan InterPro ID
# 43 IPScan Protein Database
# 44 IPScan Protein Description
# 45 IPScan E-Value
