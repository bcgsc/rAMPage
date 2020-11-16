#!/bin/bash
set -euo pipefail
PROGRAM=$(basename $0)

# 1 - get_help function
function get_help() {
    {
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
        " | column -s$'\t' -t -L

        echo "USAGE(S):"
        echo -e "\
		\t$PROGRAM [OPTIONS] -o <output directory> -r <reference transcriptome> <readslist TXT file>\n \
        " | column -s$'\t' -t -L

        echo "OPTION(S):"
        echo -e "\
		\t-a <address>\temail alert\n \
		\t-c <dbl>\tTPM cut-off\t(default = 0.50)\n \
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n \
		\t-r <FASTA file>\treference transcriptome\t(required)\n \
		\t-t <int>\tnumber of threads\t(default = 2)\n \
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

# default options
email=false
threads=2
cutoff=0.50

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
        mkdir -p $outdir
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
if [[ ! -f "$ref" ]]; then
    print_error "Given reference transcriptome $ref does not exist."
elif [[ ! -s "$ref" ]]; then
    print_error "Given reference transcriptome $ref is empty."
fi

if [[ ! -f $(realpath $1) ]]; then
    print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
    print_error "input file $(realpath $1) is empty."
fi
workdir=$(dirname $outdir)
if [[ -f $workdir/STRANDED.LIB ]]; then
    stranded=true
elif [[ -f $workdir/NONSTRANDED.LIB || -f $workdir/AGNOSTIC.LIB ]]; then
    stranded=false
else
    print_error "*.LIB file not found. Please check that you specified in your TSV file whether or not the library preparation was strand-specific."
fi

if [[ -f $workdir/PAIRED.END ]]; then
    paired=true
elif [[ -f $workdir/SINGLE.END ]]; then
    paired=false
else
    print_error "*.END file not found."
fi

# 7 - remove status files
rm -f $outdir/FILTER.DONE
rm -f $outdir/FILTER.FAIL

# 8 - print env details
echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)\n" 1>&2
start_sec=$(date '+%s')

echo -e "PATH=$PATH\n" 1>&2

readslist=$(realpath $1)

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
        echo -e "COMMAND: $RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -1 $(awk '{print $3}' $readslist) -2 $(awk '{print $2}' $readslist) -o $outdir &> $outdir/quant.log\n" 1>&2
        $RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -1 $(awk '{print $3}' $readslist) -2 $(awk '{print $2}' $readslist) -o $outdir &>$outdir/quant.log
    else
        libtype=IU
        echo -e "COMMAND: $RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -1 $(awk '{print $2}' $readslist) -2 $(awk '{print $3}' $readslist) -o $outdir &> $outdir/quant.log\n" 1>&2
        $RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -1 $(awk '{print $2}' $readslist) -2 $(awk '{print $3}' $readslist) -o $outdir &>$outdir/quant.log
    fi
else
    if [[ "$stranded" = true ]]; then
        libtype=SR
    else
        libtype=U
    fi
    echo -e "COMMAND: $RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -r $(awk '{print $2}' $readslist) -o $outdir &> $outdir/quant.log\n" 1>&2
    $RUN_SALMON quant --index $outdir/index --threads $threads -l $libtype -r $(awk '{print $2}' $readslist) -o $outdir &>$outdir/quant.log
fi

echo "Filtering the transcriptome for transcripts whose TPM >= ${cutoff}..." 1>&2
echo "PROGRAM: $(command -v $RUN_SEQTK)" 1>&2
seqtk_version=$($RUN_SEQTK 2>&1 || true)
echo -e "VERSION: $(echo "$seqtk_version" | awk '/Version:/ {print $NF}')\n" 1>&2

awk -v var="$cutoff" '{if($4>=var) print}' $outdir/quant.sf >$outdir/remaining.sf
awk -v var="$cutoff" '{if($4<var) print}' $outdir/quant.sf >$outdir/discarded.sf

echo -e "COMMAND: $RUN_SEQTK subseq $ref <(awk -v var=\"$cutoff\" '{if(\$4>=var) print \$1}' $outdir/quant.sf) > $outdir/rnabloom.transcripts.filtered.fa\n" 1>&2
$RUN_SEQTK subseq $ref <(awk -v var="$cutoff" '{if($4>=var) print $1}' $outdir/quant.sf) >$outdir/rnabloom.transcripts.filtered.fa

if [[ ! -s $outdir/rnabloom.transcripts.filtered.fa ]]; then
    touch $outdir/FILTER.FAIL
    echo "STATUS: failed." 1>&2

    if [[ "$email" = true ]]; then
        org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
        echo "$outdir" | mail -s "Failed expression filtering $org" $address
        echo "Email alert sent to $address." 1>&2
    fi
    exit 2
fi

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
end_sec=$(date '+%s')

$ROOT_DIR/scripts/get-runtime.sh -T $start_sec $end_sec 1>&2
echo 1>&2

if [[ "$email" = true ]]; then
    org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
    echo "$outdir" | mail -s "Finished expression filtering for $org" $address
    echo "Email alert sent to $address." 1>&2
fi

echo "STATUS: complete." 1>&2
touch $outdir/FILTER.DONE
