#!/usr/bin/env bash
set -euo pipefail
PROGRAM=$(basename $0)

# 1 - get_help function
function get_help() {
	{
		echo "DESCRIPTION:"
		echo -e "\
		\tUses ProP (and SignalP, if available) to predict prepropeptide cleavage sites, and obtain the mature peptide sequence.\n \
		\n \
		\tOUTPUT:\n \
		\t-------\n \ 
		\t  - cleaved.mature.len.faa\n \
		\t  - CLEAVE.DONE or CLEAVE.FAIL\n \
		\t  - CLEAVE_LEN.DONE or CLEAVE_LEN.FAIL\n \
		\n \
		\tEXIT CODES:\n \
		\t-----------\n \ 
		\t  - 0: successfully completed\n \
		\t  - 1: general error\n \
		\t  - 2: SignalP not found\n \
		\t  - 3: cleavage failed\n \
		\t  - 4: length filtering failed\n \
		\n \ 
		\tFor more information on ProP: https://services.healthtech.dtu.dk/service.php?ProP-1.0\n \
		" | column -s $'\t' -t -L

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM -o <output directory> <input FASTA file>\n \
		" | column -s $'\t' -t -L

		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail alert\n \
		\t-c\tallow consecutive (i.e. adjacent) segments to be recombined\n \
		\t-h\tshow this help menu\n \
		\t-o <directory>\toutput directory\t(required)\n \
		" | column -s $'\t' -t -L

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -o /path/to/output/directory /path/to/input/fasta\n \
		" | column -s $'\t' -t -L
	} 1>&2
	exit 1

	#		\tFor more information on CD-HIT: http://weizhongli-lab.org/cd-hit/\n \
	#		\t-s <0 to 1>\tCD-HIT global sequence similarity cut-off\t(default = 0.90)\n \
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
email=false
# similarity=0.90
consecutive=false
# 4 - read options
while getopts :a:cho: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	c)
		consecutive=true
		;;
	h) get_help ;;
	o)
		outdir="$(realpath $OPTARG)"
		mkdir -p $outdir
		;;
		#		s) similarity="$OPTARG";;
	\?)
		print_error "Invalid option: -$OPTARG" 1>&2
		;;
	esac
done

shift $((OPTIND - 1))

# 5 - wrong number arguments given
if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 - check input files
if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "input file $(realpath $1) is empty."
fi

# 7 - remove existing status files
rm -f $outdir/CLEAVE.DONE
rm -f $outdir/CLEAVE.FAIL
rm -f $outdir/CLEAVE_LEN.DONE
rm -f $outdir/CLEAVE_LEN.FAIL

# 8 - print env details
echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)\n" 1>&2
# start_sec=$(date '+%s')

echo -e "PATH=$PATH\n" 1>&2

if command -v mail &>/dev/null; then
	email=true
else
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

infile=$(realpath $1)
tempfile=$outdir/prop.out

echo "PROGRAM: $(command -v $RUN_PROP)" 1>&2
echo -e "VERSION: 1.0c\n" 1>&2
prop_dir=$(dirname $RUN_PROP)

if [[ -f "$prop_dir/CONFIG.DONE" ]]; then
	config=false
	echo -e "ProP and SignalP have been pre-configured. Skipping configuration. If this is not the case, please delete the $prop_dir/CONFIG.DONE file to trigger a reconfiguration of ProP and SignalP.\n" 1>&2
else
	config=true
fi

if [[ "$config" == true ]]; then
	permissions=$(ls -ld $prop_dir/tmp | awk '{print $1}')
	owner=$(ls -ld $prop_dir/tmp | awk '{print $3}')
	if [[ "$permissions" != "drwxrw[sx]rwt" && "$owner" == "$(whoami)" ]]; then
		chmod 1777 $prop_dir/tmp
	fi
fi
# echo -e "VERSION: $(echo $RUN_PROP | grep -o prop\-[0-9]\.[0-9]. | cut -f2 -d-)\n" 1>&2

if command -v $RUN_SIGNALP &>/dev/null; then
	signalp=true
	signalp_opt="-s"
	echo -e "SignalP program detected. Proceeding with SignalP.\n" 1>&2
	if [[ "$config" = true ]]; then
		signal_dir=$(dirname $RUN_SIGNALP)
		if [[ ! -f "$signal_dir/CONFIG.DONE" ]]; then
			sed -i "s|^SIGNALP=.*|SIGNALP=$signal_dir|" $RUN_SIGNALP
			sed -i "s|^SH=.*|SH=$SHELL|" $RUN_SIGNALP
			permissions=$(ls -ld $signal_dir/tmp | awk '{print $1}')
			owner=$(ls -ld $signal_dir/tmp | awk '{print $3}')
			if [[ "$permissions" != "drwxrw[sx]rwt" && "$owner" == "$(whoami)" ]]; then
				chmod 1777 $signal_dir/tmp
			fi
			touch $signal_dir/CONFIG.DONE
		else
			echo -e "SignalP has been previously configured.\n" 1>&2
		fi

	fi
else
	signalp=false
	signalp_opt=""
	echo "ERROR: SignalP program not found. Please download SignalP into $ROOT_DIR/src, and source $ROOT_DIR/scripts/config.sh from the $ROOT_DIR, so that the RUN_SIGNALP environment variable is re-exported." 1>&2
	exit 2
#	echo -e "SignalP program not found. Proceeding without SignalP.\n" 1>&2
fi
if [[ "$signalp" = true ]]; then
	echo "PROGRAM: $(command -v $RUN_SIGNALP)" 1>&2
	echo -e "VERSION: $($RUN_SIGNALP -v)\n" 1>&2
fi

if [[ "$config" = true ]]; then
	propdir=$(dirname $RUN_PROP)
	if [[ ! -f $propdir/CONFIG.DONE ]]; then
		echo -e "Configuring ProP...\n" 1>&2
		sed -i "s|setenv\tPROPHOME.*|setenv\tPROPHOME\t$propdir|" $RUN_PROP

		awkbin=$(command -v awk)
		sed -i "s|setenv AWK.*|setenv AWK $awkbin|" $RUN_PROP
		sed -i 's/^AWK=.*/AWK=awk/' $RUN_SIGNALP
		sed -i "s|AWK=/.*|AWK=$awkbin|" $RUN_SIGNALP

		echobin=$(which echo)
		sed -i "s|setenv ECHO.*|setenv ECHO \"$echobin -e\"|" $RUN_PROP

		gnuplot=$(command -v gnuplot 2>/dev/null || true)
		if [[ ! -z $gnuplot ]]; then
			sed -i "s|setenv GNUPLOT.*|setenv GNUPLOT $gnuplot|" $RUN_PROP
			sed -i "s|PLOTTER=/.*|PLOTTER=$gnuplot|" $RUN_SIGNALP
		fi

		ppmtogifbin=$(command -v ppmtogif 2>/dev/null || true)
		if [[ ! -z $ppmtogifbin ]]; then
			sed -i "s|setenv PPM2GIF.*|setenv PPM2GIF $ppmtogifbin|" $RUN_PROP
			sed -i "s|PPMTOGIF=/.*|PPMTOGIF=$ppmtogifbin|" $RUN_SIGNALP
		fi

		if [[ "$signalp" = true ]]; then
			sed -i "s|setenv SIGNALP.*|setenv SIGNALP $RUN_SIGNALP|" $RUN_PROP
		fi
	else
		echo -e "ProP has been previously configured.\n" 1>&2
	fi
fi

if [[ "$(grep -c "|" $infile)" -gt 0 ]]; then
	echo -e "NOTE: Pipes detected in sequence headers will be converted to underscores for ProP.\n" 1>&2
	sed -i 's/|/_/g' $infile
fi

# RUN PROP and get output
echo "Predicting cleavage sites..." 1>&2
echo "COMMAND: $RUN_PROP -p $signalp_opt $infile > $tempfile" 1>&2
# start_sec_temp=$(date '+%s')

$RUN_PROP -p $signalp_opt $infile >$tempfile
# end_sec_temp=$(date '+%s')

cp $tempfile $outdir/prop.raw.out
sed -i 's/ \+$//' $tempfile
sed -i 's/^[[:space:]]*[0-9]\+[[:space:]]*/Sequence: /' $tempfile

# $ROOT_DIR/scripts/get-runtime.sh $start_sec_temp $end_sec_temp 1>&2
# echo 1>&2
echo -e "Output: $tempfile\n" 1>&2

# Parse the output
# Write each sequence and cleavage site to the F*.txt
echo "Writing ProP results into a separate file for each sequence..." 1>&2
echo -e "COMAMND: awk -v var=\"$outdir\" 'BEGIN{x=\"/dev/null\"}/^Sequence:/{x=var\"/F\"++i\".txt\";}{print > x;}' $tempfile\n" 1>&2
# echo -e "COMAMND: awk -v var=\"$outdir\" 'BEGIN{x=\"/dev/null\"}/^\\t[0-9]+/{x=var\"/F\"++i\".txt\";}{print > x;}' $tempfile\n" 1>&2
# awk -v var="$outdir" 'BEGIN{x="/dev/null"}/^\t[0-9]+/{x=var"/F"++i".txt";}{print > x;}' $tempfile
awk -v var="$outdir" 'BEGIN{x="/dev/null"}/^Sequence:/{x=var"/F"++i".txt";}{print > x;}' $tempfile
# exit 0
echo "Converting ProP output to a TSV file..." 1>&2
tsv=$outdir/prop.tsv

echo -e "Sequence\tSignal Peptide\tPropeptide Cleavage" >$tsv
for i in $outdir/F*.txt; do
	seqname=$(head -n1 $i | awk '{print $NF}')
	signal_site=$(awk '/Signal peptide cleavage site predicted/ {print $NF}' $i)

	if [[ "$signal_site" == "none" ]]; then # || -z "$signal_site" ]] for if -s isn't used for prop
		signal_site=0
	else
		signal_site=$(awk '/Signal peptide cleavage site predicted/ {print $(NF-3)}' $i)
	fi

	prop_sites=$(awk '/\*ProP\*/ {print $2}' $i | tr '\n' ',' | sed 's/,$//')

	if [[ -z "$prop_sites" ]]; then
		prop_sites=0
	fi

	echo -e "$seqname\t$signal_site\t$prop_sites" >>$tsv
	rm $i
done

# Sambina's cleaving script
echo "Cleaving peptides..." 1>&2
# start_cleave=$(date '+%s')
$ROOT_DIR/scripts/cleave-seq.py $infile $tsv $outdir
# end_cleave=$(date '+%s')
# $ROOT_DIR/scripts/get-runtime.sh $start_cleave $end_cleave
# echo 1>&2

# DESCRIBE OUTPUT FILES HERE
echo "Output Files:" 1>&2
echo -e "\
- signal_seq.faa: contains all the signal sequences\n\
- adjacent_seq.faa: contains all the recombined peptide sequences that have adjacent cleaved sequences\n\
- mature_cleaved_seq.FASTA: contains all the cleaved sequences\n\
\t- includes all mature, prop and prepro sequences\n\
- recombined_seq.FASTA: Contains all the non-adjacent recombined sequences, both two and three cleaved sequences stitched together\n\
\t- includes all mature, pro, and prepro sequences)\n\
" 1>&2

echo "Combining mature_cleaved_seq.faa and recombined_seq.faa into cleaved.mature.faa..." 1>&2

if [[ "$consecutive" = true ]]; then
	cat $outdir/mature_cleaved_seq.faa $outdir/recombined_seq.faa $outdir/adjacent_seq.faa >$outdir/cleaved.mature.faa
else
	cat $outdir/mature_cleaved_seq.faa $outdir/recombined_seq.faa >$outdir/cleaved.mature.faa
fi

outfile=$outdir/cleaved.mature.faa
outfile_len=$outdir/cleaved.mature.len.faa
if [[ ! -s "$outfile" ]]; then
	touch $outdir/CLEAVE.FAIL
	echo "ERROR: Cleaving output file $outfile does not exist or is empty." 1>&2
	if [[ "$email" = true ]]; then
		org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		echo "$outdir" | mail -s "Failed cleaving peptides for $org" $address
		echo "Email alert sent to $address." 1>&2
	fi
	exit 3
fi

touch $outdir/CLEAVE.DONE
echo "PROGRAM: $(command -v $RUN_SEQTK)" 1>&2
seqtk_version=$($RUN_SEQTK 2>&1 || true)
echo -e "VERSION: $(echo "$seqtk_version" | awk '/Version:/ {print $NF}')\n" 1>&2

# keep only sequences that are >=2 and  <=200
echo "Removing sequences with length < 2 or > 200 amino acids..." 1>&2
echo -e "COMMAND: $RUN_SEQTK subseq $outfile <($RUN_SEQTK comp $outfile | awk '{if(\$2>=2 && \$2<=200) print \$1}') > $outfile_len\n" 1>&2
$RUN_SEQTK subseq $outfile <($RUN_SEQTK comp $outfile | awk '{if($2>=2 && $2<=200) print $1}') >$outfile_len
echo -e "Removed $($RUN_SEQTK comp $outfile | awk '{if($2<2 || $2>200) print $1}' | wc -l) sequences.\n" 1>&2

echo -e "Number of sequences remaining: $(grep -c '^>' $outfile_len || true)\n" 1>&2

echo -e "Output: $outfile_len\n" 1>&2

if [[ ! -s $outfile_len ]]; then
	touch $outdir/CLEAVE_LEN.FAIL
	echo "ERROR: Length filtering output file $outfile_len does not exist or is empty." 1>&2
	if [[ "$email" = true ]]; then
		org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
		echo "$outdir" | mail -s "Failed filtering out long sequences for $org" $address
		echo "Email alert sent to $address." 1>&2
	fi
	exit 4
fi

default_name="$(realpath -s $(dirname $outdir)/cleavage)"
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

touch $outdir/CLEAVE_LEN.DONE
echo "STATUS: DONE." 1>&2

if [[ "$email" = true ]]; then
	org=$(echo "$outdir" | awk -F "/" '{print $(NF-2), $(NF-1)}')
	echo "$outdir" | mail -s "Finished cleaving peptides for $org" $address
	echo -e "\nEmail alert sent to $address." 1>&2
fi
