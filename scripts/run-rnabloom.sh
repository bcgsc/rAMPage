#!/usr/bin/env bash

set -euo pipefail
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
	# DESCRIPTION
	{
		echo -e "PROGRAM: $PROGRAM\n"
		echo "DESCRIPTION:"
		echo -e "\
		\tUses RNA-Bloom to assembly trimmed reads into transcripts. If a reference-guided assembly is desired, please place the reference transcriptome(s) (e.g. *.fna) in the working directory. In this case, the working directory is inferred to be the parent directory of your specified output directory.\n \
		\n \
		\tOUTPUT:\n \
		\t-------\n \
		\t  - rnabloom.transcripts.all.fa \n \
		\t  - ASSEMBLY.DONE or ASSEMBLY.FAIL\n \
		\n \
		\tEXIT CODES:\n \
		\t-----------\n \
		\t  - 0: successfully completed\n \
		\t  - 1: general error\n \
		\n \
		\tFor more information: https://github.com/bcgsc/RNA-Bloom\n \
        " | table

		#  USAGE
		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-a <address>] [-d] [-h] [-m <int K/M/G>] [-s] [-t <int>] -o <output directory> <reads list TXT file>\n \
        " | table

		# OPTION
		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail address for alerts\n \
		\t-d\tdebug mode\t(skips RNA-Bloom)\n \
		\t-h\tshow help menu\n \
		\t-m <int K/M/G>\tallotted memory for Java (e.g. 500G)\n \
		\t-n\tno redundancy removal\n \
		\t-o <directory>\toutput directory\t(required)\n \
		\t-s\tstrand-specific library construction\t(default = false)\n \
		\t-t <int>\tnumber of threads\t(default = 8)\n \
        " | table

		# reads list
		echo "EXAMPLE READS LIST (NONSTRANDED):"
		echo -e "\
		\ttissue1 /path/to/readA_1.fastq.gz /path/to/readA_2.fastq.gz\n \
		\ttissue2 /path/to/readB_1.fastq.gz /path/to/readB_2.fastq.gz\n \
		\t...     ...                       ...\n \
		\t...     ...                       ...\n \
		\t...     ...                       ...\n \
        " | table

		echo "EXAMPLE READS LIST (STRANDED):"
		echo -e "\
		\ttissue1 /path/to/readA_2.fastq.gz /path/to/readB_1.fastq.gz\n \
		\ttissue2 /path/to/readB_2.fastq.gz /path/to/readB_1.fastq.gz\n \
		\t...     ...                       ...\n \
		\t...     ...                       ...\n \
		\t...     ...                       ...\n \
        " | table

		# EXAMPLE
		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com -m 500G -s -t 8 -o /path/to/assembly/outdir /path/to/trimmed_reads/readslist.txt\n \
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
debug=false
threads=8
custom_threads=false
memory_bool=false
email=false
outdir=""
stranded=false
rr=true 

# 4 - read options
while getopts :a:dhm:no:st: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	d) debug=true ;;
	h) get_help ;;
	m)
		memory_bool=true
		memory="-Xmx${OPTARG}"
		;;
	n) rr=false ;;
	o)
		outdir="$(realpath $OPTARG)"
		;;
	s) stranded=true ;;
	t)
		threads="$OPTARG"
		custom_threads=true
		;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done
shift $((OPTIND - 1))

# 5 - wrong number arguments given
if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 - check input files
if [[ -z $outdir ]]; then
	print_error "Required argument -o <output directory> missing."
else
	mkdir -p $outdir
fi

if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) is empty."
fi

# 7 - remove status files
rm -f $outdir/ASSEMBLY.DONE
rm -f $outdir/ASSEMBLY.FAIL

# 8 - print env details
# check minimap2 and ntCard
minimap2_dir=$MINIMAP_DIR
ntcard_dir=$NTCARD_DIR
export PATH=${minimap2_dir}:${ntcard_dir}:${PATH}

{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo "CALL: $args (wd: $(pwd))"
	echo -e "THREADS: $threads\n"
} 1>&2

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

echo "Checking minimap2..." 1>&2
if command -v minimap2 &>/dev/null; then
	echo "PROGRAM: $(command -v minimap2)" 1>&2
	echo -e "VERSION: $(minimap2 --version)\n" 1>&2
else
	print_error "Cannot find 'minimap2' in PATH."
fi

echo "Checking ntCard..." 1>&2
if command -v ntcard &>/dev/null; then
	echo "PROGRAM: $(command -v ntcard)" 1>&2
	echo -e "VERSION: $(ntcard --version 2>&1 | awk '/ntCard/ {print $NF}')\n" 1>&2
else
	print_error "Cannot find 'ntcard' in PATH."
fi

echo "Checking Java SE Runtime Environment (JRE)..." 1>&2

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
	print_error "RNA-Bloom requires Java SE Runtime Environment (JRE) 8. Version detected: $java_version"
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

readslist=$(realpath $1)

if [[ ! -v PAIRED ]]; then
	# infer paired from the readslist
	num_cols=$(awk '{print NF}' $readslist | sort -u)
	if [[ "$num_cols" -eq 2 ]]; then
		paired=false
		#		touch SINGLE.END
	elif [[ "$num_cols" -eq 3 ]]; then
		paired=true
		#		touch PAIRED.END
	else
		print_error "There are too many columns in the input TXT file."
	fi
else
	paired=$PAIRED
fi

if [[ ! -v STRANDED ]]; then
	if [[ "$paired" = true ]]; then
		# check column 2 to see if it's _2 or _1
		if awk '{print $2}' $readslist | grep "_1.fastq.gz" &>/dev/null; then
			stranded=false
		elif awk '{print $2}' $readslist | grep "_2.fastq.gz" &>/dev/null; then
			stranded=true
			# if inferral doesn't work, falls on -s option
			#		else
			#			print_error "Strandedness of the library could not be inferred from the reads list." 1>&2
		fi
	else
		stranded=false
	fi
else
	stranded=$STRANDED
fi
# if [[ -f $workdir/PAIRED.END ]]; then
# 	paired=true
# 	echo "Paired-end reads detected!" 1>&2
# 	if [[ -f $workdir/STRANDED.LIB ]]; then
# 		stranded=true
# 	elif [[ -f $workdir/NONSTRANDED.LIB ]]; then
# 		stranded=false
# 	elif [[ -f $workdir/AGNOSTIC.LIB ]]; then
# 		stranded=false
# 	else
# 		print_error "*.LIB file not found. Please check that you specified in your TSV file whether or not the library preparation was strand-specific."
# 	fi
# elif [[ -f $workdir/SINGLE.END ]]; then
# 	paired=false
# 	echo "Single-end reads detected!" 1>&2
# 	if [[ -f $workdir/STRANDED.LIB ]]; then
# 		stranded=true
# 	elif [[ -f $workdir/NONSTRANDED.LIB ]]; then
# 		stranded=false
# 	else
# 		print_error "*.LIB file not found. Please check that you specified in your TSV file whether or not the library preparation was strand-specific."
# 	fi
# else
# 	print_error "*.END file not found. Please check that the reads have been downloaded correctly."
# fi

if [[ "$memory_bool" == true ]]; then
	rnabloom_jar="$JAVA_EXEC ${memory} -jar $RUN_RNABLOOM"
else
	rnabloom_jar="$JAVA_EXEC -jar $RUN_RNABLOOM"
fi

if [[ "$stranded" == true ]]; then
	stranded_opt="-stranded"
	echo "The library construction for this dataset is stranded." 1>&2
else
	stranded_opt=""
	echo -e "The library construction for this dataset is nonstranded or agnostic.\n" 1>&2
fi

if command -v pigz &>/dev/null; then
	if [[ "$custom_threads" = true ]]; then
		compress="pigz -p $threads"
	else
		compress=pigz
	fi
else
	compress=gzip
fi

references=()
basename_refs=()

if ls $workdir/*.fna* 1>/dev/null 2>&1; then
	# if the reference exists, then use it
	reference=$(ls $workdir/*.fna*)
	${compress} -d $reference 2>/dev/null || true

	for i in $workdir/*.fna*; do
		references+=($i)
		basename_refs+=($(basename $i))
	done
fi

if ls $workdir/*.fsa_nt* 1>/dev/null 2>&1; then
	# if the reference exists, then use it
	reference=$(ls $workdir/*.fsa_nt*)
	echo -e "Decompressing reference transcriptome(s)...\n" 1>&2
	${compress} -d $reference 2>/dev/null || true

	for i in $workdir/*.fsa_nt*; do
		references+=($i)
		basename_refs+=($(basename $i))
	done
fi

if [[ "${#references[@]}" -eq 0 ]]; then
	ref_opt=""
	echo -e "No reference transcriptome(s) detected.\n" 1>&2
else
	ref_opt="-ref ${references[*]}"
	echo -e "Reference transcriptome(s) detected: ${basename_refs[*]}\n" 1>&2
fi

if [[ "$paired" = false ]]; then
	reads_opt="-left $(awk '{print $2}' $readslist | tr '\n' ' ' | sed 's/ $//')"
	revcomp_opt=""
	mergepool_opt=""
	mergepool=false
elif [[ "$(awk '{print $1}' $readslist | sort -u | wc -l)" -eq 1 ]]; then
	reads_opt="-left $(awk '{print $2}' $readslist | tr '\n' ' ' | sed 's/ $//') -right $(awk '{print $3}' $readslist | tr '\n' ' ' | sed 's/ $//')"
	revcomp_opt="-revcomp-right"
	mergepool_opt=""
	mergepool=false
else
	reads_opt="-pool ${readslist}"
	revcomp_opt="-revcomp-right"
	if [[ "$rr" = true ]]; then
		mergepool_opt="-mergepool"
		mergepool=true
	else
		mergepool_opt=""
		mergepool=false
	fi
fi

if [[ "$rr" = true ]]; then
	rr_opt=""
else
	rr_opt="-norr"
fi

logfile=$outdir/rnabloom.out

label=$(echo "$workdir" | awk -F "/" 'BEGIN{OFS="-"}{gsub(/-/, "_", $(NF-1)); gsub(/-/, "_", $NF); print $(NF-1), $NF}')

if [[ -z "$ref_opt" ]]; then
	echo "Conducting a de-novo transcriptome assembly." 1>&2
else
	echo "Conducting a reference-guided transcriptome assembly." 1>&2
fi
if [[ "$debug" = false ]]; then
	echo "Running RNA-Bloom..." 1>&2

	echo -e "COMMAND: ${rnabloom_jar} -f -k 25-75:5 -ntcard -fpr 0.005 -extend -t $threads ${reads_opt} ${mergepool_opt} ${revcomp_opt} -outdir ${outdir} ${stranded_opt} ${ref_opt} -prefix ${label}- ${rr_opt} &>> $logfile\n" | tee $logfile 1>&2

	${rnabloom_jar} -f -k 25-75:5 -ntcard -fpr 0.005 -extend -t $threads ${reads_opt} ${mergepool_opt} ${revcomp_opt} -outdir ${outdir} ${stranded_opt} ${ref_opt} -prefix ${label}- ${rr_opt} &>>$logfile
else
	echo -e "DEBUG MODE: Skipping RNA-Bloom..." 1>&2
	echo -e "COMMAND: ${rnabloom_jar} -f -k 25-75:5 -ntcard -fpr 0.005 -extend -t $threads ${reads_opt} ${mergepool_opt} ${revcomp_opt} -outdir ${outdir} ${stranded_opt} ${ref_opt} -prefix ${label}- ${rr_opt} &>> $logfile\n" | tee $logfile 1>&2
fi

if [[ "${#references[@]}" -ne 0 ]]; then
	echo "Re-compressing reference transcriptome(s)..." 1>&2
	${compress} ${references[*]} 2>/dev/null || true
fi

if [[ "$rr" = true ]]; then
	if [[ ! -f $outdir/TRANSCRIPTS_NR.DONE ]]; then
		touch $outdir/ASSEMBLY.FAIL
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		if [[ "$email" = true ]]; then
			# echo "$outdir" | mail -s "Failed assembling $org" "$address"
			# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
			echo "$outdir" | mail -s "${species^}: STAGE 05: ASSEMBLY: FAILED" "$address"
			echo "Email alert sent to $address." 1>&2
		fi
	fi
else
	if [[ ! -f $outdir/TRANSCRIPTS.DONE ]]; then
		touch $outdir/ASSEMBLY.FAIL
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		if [[ "$email" = true ]]; then
			# echo "$outdir" | mail -s "Failed assembling $org" "$address"
			# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
			echo "$outdir" | mail -s "${species^}: STAGE 05: ASSEMBLY: FAILED" "$address"
			echo "Email alert sent to $address." 1>&2
		fi
	fi
fi

label=$(echo "$workdir" | awk -F "/" 'BEGIN{OFS="-"}{gsub(/-/, "_", $NF); print $(NF-1), $NF}')

# if mergepool = false && rr = false, then there are .fa (not nr) in individual pooled folders - cat them together (no CDHIT) and then use seqtk rename to get consistent numbering like the others
# if mergepool = true then there is .fa in the assembly dir
# if mergepool = false && rr = true, then there are .nr.fa 

if [[ "$mergepool" = true ]]; then
	# merged into main assembly directory
	echo "Renaming transcripts in rnabloom.transcripts.fa..." 1>&2
	sed -i "s/^>/>${label}-/" $outdir/rnabloom.transcripts.fa
	echo "Renaming transcripts in rnabloom.transcripts.short.fa..." 1>&2
	sed -i "s/^>/>${label}-/" $outdir/rnabloom.transcripts.short.fa

	echo -e "Combining rnabloom.transcripts.fa and rnabloom.transcripts.short.fa...\n" 1>&2
	cat $outdir/rnabloom.transcripts.fa $outdir/rnabloom.transcripts.short.fa >$outdir/rnabloom.transcripts.all.fa
elif [[ "$rr" = true ]]; then
	# if mergepool is false and rr is true, then this is a one line readslist.txt
	# prefix is already applied
	# echo "Renaming transcripts in rnabloom.transcripts.nr.fa..." 1>&2
	# sed -i "s/^>/>${label}-/g" $outdir/rnabloom.transcripts.nr.fa
	# echo "Renaming transcripts in rnabloom.transcripts.nr.short.fa..." 1>&2
	# sed -i "s/^>/>${label}-/g" $outdir/rnabloom.transcripts.nr.short.fa

	echo -e "Combining rnabloom.transcripts.nr.fa and rnabloom.transcripts.nr.short.fa...\n" 1>&2
	cat $outdir/rnabloom.transcripts.nr.fa $outdir/rnabloom.transcripts.nr.short.fa >$outdir/rnabloom.transcripts.all.fa
else
	# if mergepool is false and rr is false, then memory usage is too high
	# combine all without redundancy removal

	echo "Renaming transcripts in rnabloom.transcripts.fa..." 1>&2
	for i in $outdir/*/*.transcripts.fa; do 
		tissue=$(echo "$i" | awk -F "/" '{print $(NF-1)}')
		sed "s/^>${label}-/\0${tissue}-/" $i >> $outdir/rnabloom.transcripts.fa
	done

	echo "Renaming transcripts in rnabloom.transcripts.short.fa..." 1>&2
	for i in $outdir/*/*.transcripts.short.fa; do 
		tissue=$(echo "$i" | awk -F "/" '{print $(NF-1)}')
		sed "s/^>${label}-/\0${tissue}-/" $i >> $outdir/rnabloom.transcripts.short.fa
	done

	echo -e "Combining rnabloom.transcripts.fa and rnabloom.transcripts.short.fa...\n" 1>&2
	cat $outdir/rnabloom.transcripts.fa $outdir/rnabloom.transcripts.short.fa >$outdir/rnabloom.transcripts.all.fa
fi

echo "Fetching total number of transcripts..." 1>&2
# echo "COMMAND: tac $logfile | grep -m 1 "after:" | awk '{print $NF}'" 1>&2
# tx_total=$(tac $logfile | grep -m 1 "after:" | awk '{print $NF}')
# echo "COMMAND: grep \"after:\" $logfile | tail -n1 | awk '{print \$NF}')" 1>&2
if [[ "$rr" = true ]]; then
	tx_total=$(grep "after:" $logfile | tail -n1 | awk '{print $NF}')
	echo -e "Total number of assembled non-redundant transcripts: $tx_total\n" 1>&2
else
	tx_total=$(grep -c '^>' $outdir/rnabloom.transcripts.all.fa || true)
	echo -e "Total number of assembled transcripts: $tx_total\n" 1>&2
fi

echo -e "Assembly: $outdir/rnabloom.transcripts.all.fa\n" 1>&2
default_name="$(realpath -s ${workdir}/assembly)"
if [[ "$default_name" != "$outdir" ]]; then
	count=1
	if [[ -d "$default_name" ]]; then
		if [[ ! -L "$default_name" ]]; then
			# if 'default' assembly directory already exists, then rename it.
			# rename it to name +1 so the assembly doesn't overwrite
			temp="${default_name}-${count}"
			while [[ -d "$temp" ]]; do
				count=$((count + 1))
				temp="${default_name}-${count}"
			done
			echo -e "Since $default_name already exists, $default_name is renamed to $temp as to not overwrite old assemblies.\n" 1>&2
			mv $default_name $temp
		else
			unlink $default_name
		fi
	fi
	if [[ "$default_name" != "$outdir" ]]; then
		echo -e "$outdir softlinked to $default_name\n" 1>&2
		(cd $(dirname $outdir) && ln -fs $(basename $outdir) $(basename $default_name))
	fi
fi

echo -e "END: $(date)\n" 1>&2

# echo 1>&2

touch $outdir/ASSEMBLY.DONE
echo -e "STATUS: DONE.\n" 1>&2

echo "Output: $outdir/rnabloom.transcripts.all.fa" 1>&2

if [[ "$email" = true ]]; then
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
	species=$(echo "$species" | sed 's/^./\u&. /')
	# echo "$outdir" | mail -s "${species}: STAGE 05: ASSEMBLY: SUCCESS" "$address"
	echo "$outdir" | mail -s "${species}: STAGE 05: ASSEMBLY: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
