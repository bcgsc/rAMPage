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
		\tQuantifies the expression of each transcript using Salmon and filters out lowly expressed transcripts specified by the given TPM cut-off.\n \
		\n \
		\tOUTPUT:\n \
		\t-------\n \
		\t  - rnabloom.transcripts.filtered.fa\n \
		\t  - FILTERING.DONE or FILTERING.FAIL\n \
		\n \
		\tEXIT CODES:\n \
		\t-----------\n \
		\t  - 0: successfully completed\n \
		\t  - 1: general error\n \
		\t  - 2: filtering failed\n \
		\n \
		\tFor more information: https://combine-lab.github.io/salmon/\n \
        " | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-a <address>] [-c <dbl>] [-h] [-t <int>] -o <output directory> -r <reference transcriptome (assembly)> <readslist TXT file>\n \
        " | table

		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail alert\n \
		\t-c <dbl>\tTPM cut-off\t(default = 1.0)\n \
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n \
		\t-r <FASTA file>\treference transcriptome (assembly)\t(required)\n \
		\t-t <int>\tnumber of threads\t(default = 2)\n \
        " | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com -c 1.0 -s -t 8 -o /path/to/filtering -r /path/to/assembly/rnabloom.transcripts.all.fa /path/to/trimmed_reads/readslist.txt\n \
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

# default options
email=false
threads=2
cutoff=1
# cutoff=0.50
outdir=""
ref=""

# 4 - read options
while getopts :a:c:ho:r:t: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	c) cutoff="$OPTARG" ;;
	h) get_help ;;
	o)
		outdir="$(realpath $OPTARG)"
		;;
	r) ref="$OPTARG" ;;
	t) threads="$OPTARG" ;;
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

if [[ -z $ref ]]; then
	print_error "Required argument -r <reference transcriptome> missing."
fi

if [[ ! -f "$ref" ]]; then
	print_error "Given reference transcriptome $ref does not exist."
elif [[ ! -s "$ref" ]]; then
	print_error "Given reference transcriptome $ref is empty."
fi

if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) is empty."
fi

# workdir=$(dirname $outdir)
# if [[ -f $workdir/STRANDED.LIB ]]; then
# 	stranded=true
# elif [[ -f $workdir/NONSTRANDED.LIB || -f $workdir/AGNOSTIC.LIB ]]; then
# 	stranded=false
# else
# 	print_error "*.LIB file not found. Please check that you specified in your TSV file whether or not the library preparation was strand-specific."
# fi

# if [[ -f $workdir/PAIRED.END ]]; then
# 	paired=true
# elif [[ -f $workdir/SINGLE.END ]]; then
# 	paired=false
# else
# 	print_error "*.END file not found."
# fi

# 7 - remove status files
rm -f $outdir/FILTERING.DONE
rm -f $outdir/FILTERING.FAIL

# 8 - print env details
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

readslist=$(realpath $1)

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

echo "PROGRAM: $(command -v $RUN_SALMON)" 1>&2
echo -e "VERSION: $($RUN_SALMON --version 2>&1 | awk '{print $NF}')\n" 1>&2

# index the reference transcriptome
echo "Creating an index from the reference transcriptome..." 1>&2
echo -e "COMMAND: $RUN_SALMON index --transcripts $ref --index $outdir/index --threads $threads &> $outdir/index.log\n" 1>&2
$RUN_SALMON index --transcripts $ref --index $outdir/index --threads $threads &>$outdir/index.log

echo "Quantifying expression..." 1>&2

# quantify
if [[ "$paired" = true ]]; then
	if [[ "$stranded" = true ]]; then
		libtype=ISR
		echo -e "COMMAND: $RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -1 $(awk '{print $3}' $readslist | tr '\n' ' ' | sed 's/ $//') -2 $(awk '{print $2}' $readslist | tr '\n' ' ' | sed 's/ $//') -o $outdir &> $outdir/quant.log\n" 1>&2
		$RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -1 $(awk '{print $3}' $readslist | tr '\n' ' ' | sed 's/ $//') -2 $(awk '{print $2}' $readslist | tr '\n' ' ' | sed 's/ $//') -o $outdir &>$outdir/quant.log
	else
		libtype=IU
		echo -e "COMMAND: $RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -1 $(awk '{print $2}' $readslist | tr '\n' ' ' | sed 's/ $//') -2 $(awk '{print $3}' $readslist | tr '\n' ' ' | sed 's/ $//') -o $outdir &> $outdir/quant.log\n" 1>&2
		$RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -1 $(awk '{print $2}' $readslist | tr '\n' ' ' | sed 's/ $//') -2 $(awk '{print $3}' $readslist | tr '\n' ' ' | sed 's/ $//') -o $outdir &>$outdir/quant.log
	fi
else
	if [[ "$stranded" = true ]]; then
		libtype=SR
	else
		libtype=U
	fi
	echo -e "COMMAND: $RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -r $(awk '{print $2}' $readslist | tr '\n' ' ' | sed 's/ $//') -o $outdir &> $outdir/quant.log\n" 1>&2
	$RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -r $(awk '{print $2}' $readslist | tr '\n' ' ' | sed 's/ $//') -o $outdir &>$outdir/quant.log
fi
if [[ "$cutoff" -ne 0 ]]; then
	echo "Filtering the transcriptome for transcripts whose TPM >= ${cutoff}..." 1>&2
fi
echo "PROGRAM: $(command -v $RUN_SEQTK)" 1>&2
seqtk_version=$($RUN_SEQTK 2>&1 || true)
echo -e "VERSION: $(echo "$seqtk_version" | awk '/Version:/ {print $NF}')\n" 1>&2

if [[ "$cutoff" -eq 0 ]]; then
	awk -v var="$cutoff" '{if($4>=var) print}' $outdir/quant.sf >$outdir/kept.sf
	awk -v var="$cutoff" '{if($4<var) print}' $outdir/quant.sf >$outdir/discarded.sf

	echo -e "COMMAND: $RUN_SEQTK subseq $ref <(awk -v var=\"$cutoff\" '{if(\$4>=var) print \$1}' $outdir/quant.sf) > $outdir/rnabloom.transcripts.filtered.fa\n" 1>&2
	$RUN_SEQTK subseq $ref <(awk -v var="$cutoff" '{if($4>=var) print $1}' $outdir/quant.sf) >$outdir/rnabloom.transcripts.filtered.fa
else
	echo -e "COMMAND: $RUN_SEQTK subseq $ref <(awk -v '{print \$1}' $outdir/quant.sf) > $outdir/rnabloom.transcripts.filtered.fa\n" 1>&2
	$RUN_SEQTK subseq $ref <(awk '{print $1}' $outdir/quant.sf) >$outdir/rnabloom.transcripts.filtered.fa
fi

if [[ ! -s $outdir/rnabloom.transcripts.filtered.fa ]]; then
	touch $outdir/FILTERING.FAIL
	echo "ERROR: Salmon output file $outdir/rnabloom.transcripts.filtered.fa does not exist or is empty." 1>&2

	if [[ "$email" = true ]]; then
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
		echo "$outdir" | mail -s "${species^}: STAGE 06: EXPRESSION FILTERING: FAILED" $address
		# echo "$outdir" | mail -s "Failed expression filtering $org" $address
		echo "Email alert sent to $address." 1>&2
	fi
	exit 2
fi

if [[ "$cutoff" -ne 0 ]]; then
	before=$(grep -c '^>' $ref)
	after=$(grep -c '^>' $outdir/rnabloom.transcripts.filtered.fa)

	echo -e "\
		Kept: kept.sf\n \
		Discarded: discarded.sf\n \
	" | column -t 1>&2
	echo 1>&2

	echo -e "\
		Before filtering: $(printf "%'d" $before)\n \
		After filtering: $(printf "%'d" $after)\n \
	" | column -t 1>&2

	echo 1>&2
fi
default_name="$(realpath -s $(dirname $outdir)/filtering)"
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

echo -e "STATUS: DONE.\n" 1>&2
touch $outdir/FILTERING.DONE

echo "Output: $outdir/rnabloom.transcripts.filtered.fa" 1>&2

if [[ "$email" = true ]]; then
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	# org=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}' | sed 's/^./&. /')
	species=$(echo "$species" | sed 's/^./\u&. /')
	# echo "$outdir" | mail -s "${species^}: STAGE 06: EXPRESSION FILTERING: SUCCESS" $address
	echo "$outdir" | mail -s "${species}: STAGE 06: EXPRESSION FILTERING: SUCCESS" $address
	# echo "$outdir" | mail -s "Finished expression filtering for $org" $address
	echo -e "\nEmail alert sent to $address." 1>&2
fi
