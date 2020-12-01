#!/usr/bin/env bash

set -euo pipefail
PROGRAM=$(basename $0)

# 1 - get_help function
function get_help() {
	# DESCRIPTION
	{
		echo -e "PROGRAM: $PROGRAM\n"
		echo "DESCRIPTION:"
		echo -e "\
		\tUses RNA-Bloom to assembly trimmed reads into transcripts. Strandedness of the library is determined by the *.LIB file in the working directory. If a reference-guided assembly is desired, please place the reference transcriptome(s) (e.g. *.fna) in the working directory. In this case, the working directory is inferred to be the parent directory of your specified output directory.\n \
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
        " | column -s$'\t' -t -L

		#  USAGE
		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] -o <output directory> <reads list>\n \
        " | column -s$'\t' -t -L

		# OPTION
		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail alert\n \
		\t-h\tshow help menu\n \
		\t-m <int K/M/G>\tallotted memory for Java (e.g. 500G)\n \
		\t-o <directory>\toutput directory\t(required)\n \
		\t-t <int>\tnumber of threads\t(default = 8)\n \
        " | column -s$'\t' -t -L

		# reads list
		echo "EXAMPLE READS LIST (NONSTRANDED):"
		echo -e "\
		\ttissue1 path/to/read1.fastq.gz path/to/read2.fastq.gz\n \
		\ttissue2 path/to/read1.fastq.gz path/to/read2.fastq.gz\n \
		\t...     ...                    ...\n \
		\t...     ...                    ...\n \
		\t...     ...                    ...\n \
        " | column -s$'\t' -t -L

		echo "EXAMPLE READS LIST (STRANDED):"
		echo -e "\
		\ttissue1 path/to/read2.fastq.gz path/to/read1.fastq.gz\n \
		\ttissue2 path/to/read2.fastq.gz path/to/read1.fastq.gz\n \
		\t...     ...                    ...\n \
		\t...     ...                    ...\n \
		\t...     ...                    ...\n \
        " | column -s$'\t' -t -L

		# EXAMPLE
		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -o /path/to/assembly /path/to/trimmed_reads/reads.txt\n \
        " | column -s$'\t' -t -L
	} 1>&2
	exit 1
}

# 2 - print_error function
function print_error() {
	{
		message="$1"
		echo "ERROR: $message"
		printf '%.0s=' $(seq 1 $(tput cols))
		echo
		get_help
	} 1>&2
}

# 3 - no arguments given
if [[ "$#" -eq 0 ]]; then
	get_help
fi

# default parameters
threads=8
custom_threads=false
memory_bool=false
email=false
outdir=""

# 4 - read options
while getopts :a:hm:o:t: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	h) get_help ;;
	m)
		memory_bool=true
		memory="-Xmx${OPTARG}"
		;;
	o)
		outdir="$(realpath $OPTARG)"
		;;
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
	print_error "input file $(realpath $1) is empty."
fi

# 7 - remove status files
rm -f $outdir/ASSEMBLY.DONE
rm -f $outdir/ASSEMBLY.FAIL

# 8 - print env details
echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)\n" 1>&2
# start_sec=$(date '+%s')

minimap2_dir=$MINIMAP_DIR
ntcard_dir=$NTCARD_DIR
export PATH=${minimap2_dir}:${ntcard_dir}:${PATH}

# check minimap2 and ntCard

echo -e "PATH=$PATH\n"
if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

echo "Checking minimap2..." 1>&2
bin=$(command -v minimap2 || true)
if [[ -n $bin ]]; then
	echo "PROGRAM: $bin" 1>&2
	echo -e "VERSION: $(minimap2 --version)\n" 1>&2
else
	print_error "Cannot find minimap2 in your PATH."
fi

echo "Checking ntCard..." 1>&2
bin=$(command -v ntcard || true)
if [[ -n $bin ]]; then
	echo "PROGRAM: $bin" 1>&2
	echo -e "VERSION: $(ntcard --version 2>&1 | awk '/ntCard/ {print $NF}')\n" 1>&2
else
	print_error "Cannot find ntCard in your PATH."
fi

echo "Checking Java SE Runtime Environment (JRE)..." 1>&2
bin=$(command -v $JAVA_EXEC || true)
if [[ -n $bin ]]; then
	echo "PROGRAM: $bin" 1>&2
	java_version=$($JAVA_EXEC -version 2>&1 | head -n1 | awk '{print $3}' | sed 's/"//g')
	echo -e "VERSION: $java_version\n" 1>&2
else
	print_error "Cannot find JRE 8 in your PATH."
fi

if [[ "$java_version" != 1.8* ]]; then
	print_error "RNA-Bloom requires Java SE Runtime Environment (JRE) 8. Version detected: $java_version"
fi

workdir=$(dirname $outdir)
readslist=$(realpath $1)

if [[ -f $workdir/PAIRED.END ]]; then
	single=false
	echo "Paired-end reads detected!" 1>&2
	if [[ -f $workdir/STRANDED.LIB ]]; then
		stranded=true
	elif [[ -f $workdir/NONSTRANDED.LIB ]]; then
		stranded=false
	elif [[ -f $workdir/AGNOSTIC.LIB ]]; then
		stranded=false
	else
		print_error "*.LIB file not found. Please check that you specified in your TSV file whether or not the library preparation was strand-specific."
	fi
elif [[ -f $workdir/SINGLE.END ]]; then
	single=true
	echo "Single-end reads detected!" 1>&2
	if [[ -f $workdir/STRANDED.LIB ]]; then
		stranded=true
	elif [[ -f $workdir/NONSTRANDED.LIB ]]; then
		stranded=false
	else
		print_error "*.LIB file not found. Please check that you specified in your TSV file whether or not the library preparation was strand-specific."
	fi
else
	print_error "*.END file not found. Please check that the reads have been downloaded correctly."
fi

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

if [[ "$single" = true ]]; then
	reads_opt="-left $(awk '{print $2}' $readslist)"
	revcomp_opt=""
	mergepool_opt=""
	pool=false
elif [[ "$(awk '{print $1}' $readslist | sort -u | wc -l)" -eq 1 ]]; then
	reads_opt="-left $(awk '{print $2}' $readslist) -right $(awk '{print $3}' $readslist)"
	revcomp_opt="-revcomp-right"
	mergepool_opt=""
	pool=false
else
	reads_opt="-pool ${readslist}"
	revcomp_opt="-revcomp-right"
	mergepool_opt="-mergepool"
	pool=true
fi

logfile=$outdir/rnabloom.out

if [[ -z "$ref_opt" ]]; then
	echo "Conducting a de-novo transcriptome assembly." 1>&2
else
	echo "Conducting a reference-guided transcriptome assembly." 1>&2
fi
echo "Running RNA-Bloom..." 1>&2

echo -e "COMMAND: ${rnabloom_jar} -f -k 25-75:5 -ntcard -fpr 0.005 -extend -t $threads ${reads_opt} ${mergepool_opt} ${revcomp_opt} -outdir ${outdir} ${stranded_opt} ${ref_opt}\n" | tee $logfile 1>&2

${rnabloom_jar} -f -k 25-75:5 -ntcard -fpr 0.005 -extend -t $threads ${reads_opt} ${mergepool_opt} ${revcomp_opt} -outdir ${outdir} ${stranded_opt} ${ref_opt} &>>$logfile

if [[ "${#references[@]}" -ne 0 ]]; then
	${compress} ${references[*]} 2>/dev/null
fi

if [[ ! -f $outdir/TRANSCRIPTS_NR.DONE ]]; then
	touch $outdir/ASSEMBLY.FAIL
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	if [[ "$email" = true ]]; then
		# echo "$outdir" | mail -s "Failed assembling $org" "$address"
		org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
		echo "$outdir" | mail -s "${org^}: STAGE 05: ASSEMBLY: FAILED" "$address"
		echo "Email alert sent to $address." 1>&2
	fi
fi
if [[ $pool = false ]]; then
	echo -e "Combining rnabloom.transcripts.nr.fa and rnabloom.transcripts.nr.short.fa...\n" 1>&2
	cat $outdir/rnabloom.transcripts.nr.fa $outdir/rnabloom.transcripts.nr.short.fa >$outdir/rnabloom.transcripts.all.fa
else
	echo -e "Combining rnabloom.transcripts.fa and rnabloom.transcripts.short.fa...\n" 1>&2
	cat $outdir/rnabloom.transcripts.fa $outdir/rnabloom.transcripts.short.fa >$outdir/rnabloom.transcripts.all.fa
fi

tx_total=$(tac $logfile | grep -m 1 "after:" | awk '{print $NF}')
echo -e "Total number of assembled non-redundant transcripts: $tx_total\n" 1>&2

# rename to reflect current directory
label=$(echo "$workdir" | awk -F "/" 'BEGIN{OFS="_"}{gsub(/_/, "-", $NF); print $(NF-1), $NF}')
sed -i "s/^>/>${label}_/g" $outdir/rnabloom.transcripts.all.fa

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
# end_sec=$(date '+%s')

# $ROOT_DIR/scripts/get-runtime.sh -T $start_sec $end_sec 1>&2
# echo 1>&2

touch $outdir/ASSEMBLY.DONE
echo "STATUS: DONE." 1>&2

if [[ "$email" = true ]]; then
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
	echo "$outdir" | mail -s "${org^}: STAGE 05: ASSEMBLY: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
