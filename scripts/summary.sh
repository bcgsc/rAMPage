#!/usr/bin/env bash
set -euo pipefail
PROGRAM=$(basename $0)
function get_help() {

	# DESCRIPTION
	{
		echo "DESCRIPTION:"
		echo -e "\
		\tGet summary statistics from fastp, RNA-Bloom, Salmon, TransDecoder, HMMER, ProP, and AMPlify.\n \
		" | column -s$'\t' -t -L

		# USAGE
		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [OPTIONS] <TSV file>\n \
		\t$PROGRAM [OPTIONS] <ORDER/SPECIES/TISSUE> ...\n \
		" | column -s$'\t' -t -L

		# OPTIONS
		echo "OPTION(S):"
		echo -e "\
		\t-h\tshow this help menu\n \
		" | column -s$'\t' -t -L

		# EXAMPLE
		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM anura/xlaevis/liver\n \
		\t$PROGRAM file.tsv\n \
		" | column -s$'\t' -t -L

		# TSV FORMAT
		echo "TSV FORMAT:"
		echo -e "\tORDER/SPECIES/TISSUE\tSRA ACCESSION(S)\tSTRANDEDNESS"
		echo

		#TSV EXAMPLE
		echo "TSV EXAMPLE: (no header)"
		echo -e "\
		\tanura/ptoftae/skin-liver\tSRX5102741-46 SRX5102761-62\tnonstranded\n \
		\thymenoptera/mgulosa/venom\tSRX3556750\tstranded\n \
		" | column -s$'\t' -t -L
	} 1>&2
	exit 1
}
while getopts :h opt; do
	case $opt in
	h) get_help ;;
	\?)
		echo "ERROR: Invalid option: -$OPTARG" 1>&2
		printf '%.0s=' $(seq 1 $(tput cols)) 1>&2
		echo 1>&2
		get_help
		;;
	esac
done

shift $((OPTIND - 1))

if [[ "$#" -eq 0 ]]; then
	get_help
fi

# if [[ "$#" -ne 1 ]]
# then
# 	echo "ERROR: Incorrect number of arguments." 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2
# 	get_help
# fi
if [[ -f $1 ]]; then
	if [[ "$#" -ne 1 ]]; then
		echo "ERROR: Incorrect number of arguments." 1>&2
		printf '%.0s=' $(seq 1 $(tput cols)) 1>&2
		echo 1>&2
		get_help
	fi
	commandline=false
elif [[ -d $ROOT_DIR/$1 ]]; then
	commandline=true
else
	echo "ERROR: Incorrect arguments." 1>&2
	printf '%.0s=' $(seq 1 $(tput cols)) 1>&2
	echo 1>&2
	get_help
fi
timestamp=$(date '+%Y%m%d_%H%M%S')
outfile=$ROOT_DIR/summary/summary_table-${timestamp}.tsv
# echo -e "Path\tAccession\tNumber of Reads\tNumber of Transcripts\tNumber of Annotated Sequences\tNumber of Potential AMPs (nhmmer)" | tee $outfile
echo -e "Path\t \
Number of Trimmed Reads\t \
Number of Transcripts\t \
Number of Transcripts After Filtering\t \
Number of Valid ORFs\tNumber of Potential AMPs (using HMMs)\t \
Number of Potential AMPs (using HMMs then AMPlify)\t \
Number of Short Unique Potential AMPs (length <= 50)\t \
Number of Confident Unique Potential AMPs (score >= 0.99)\t \
Number of Positive Unique Potential AMPs (charge >=2)\t \
Number of Confident and Short Unique Potential AMPs\t \
Number of Confident and Positive Unique Potential AMPs\t \
Number of Short and Positive Unique Potential AMPs\t \
Number of Confident, Short, and Positive Unique AMPs" | tee $outfile

if [[ "$commandline" = false ]]; then
	while read path; do #	while IFS=$'\t' read path accession
		fastp_log=$(ls -t $ROOT_DIR/$path/logs/03-trimmed_reads-*.log 2>/dev/null | head -n1 || true)
		if [[ -s $fastp_log ]]; then
			# number of filtered reads
			num_reads=$(awk '/Reads passed filter:/ {print $NF}' $fastp_log)

			if [[ "$num_reads" == 0 || -z "$num_reads" ]]; then
				num_reads="NA"
			fi

			# number of transcripts
			rnabloom_log=$(ls -t $ROOT_DIR/$path/logs/05-assembly*.log 2>/dev/null | head -n1 || true)
			if [[ -s $rnabloom_log ]]; then
				num_transcripts=$(awk '/Total number of assembled non-redundant transcripts:/ {print $NF}' $rnabloom_log)
				#			num_transcripts=$(printf "%'d" $num_transcripts)
				if [[ "$num_transcripts" == 0 || -z $num_transcripts ]]; then
					num_transcripts="NA"
				fi
			else
				num_transcripts="NA"
			fi
		else
			num_reads="NA"
			num_transcripts="NA"
		fi
		filter_log=$(ls -t $ROOT_DIR/$path/logs/06-filtering-*.log 2>/dev/null | head -n1 || true)

		if [[ -s $filter_log ]]; then
			num_filter=$(awk '/^After +filtering:/ {print $NF}' $filter_log)
			if [[ $num_filter == 0 || -z $num_filter ]]; then
				num_filter="NA"
			fi
		else
			num_filter="NA"
		fi

		td_log=$(ls -t $ROOT_DIR/$path/logs/07-translation-*.log 2>/dev/null | head -n1 || true)

		# number of annotated sequences
		if [[ -s $td_log ]]; then
			num_annotated=$(awk '/Number of valid ORFs:/ {print $NF}' $td_log)

			if [[ "$num_annotated" == 0 || -z $num_annotated ]]; then
				num_annotated="NA"
			fi
		else
			num_annotated="NA"
		fi

		# number of AMP proteins

		jackhmmer_log=$(ls -t $ROOT_DIR/$path/logs/08-homology*.log 2>/dev/null | head -n1 || true)
		if [[ -s $jackhmmer_log ]]; then
			jackhmmer_count=$(awk '/Number of AMPs found \(non-redundant\):/ {print $NF}' $jackhmmer_log)
			if [[ "$jackhmmer_count" == 0 || -z "$jackhmmer_count" ]]; then
				jackhmmer_count="NA"
			fi
		else
			jackhmmer_count="NA"
		fi
		amplify_log=$(ls -t $ROOT_DIR/$path/logs/10-amplify-*.log 2>/dev/null | head -n1 || true)

		if [[ -s $amplify_log ]]; then
			amplify_count=$(awk '/Number of unique AMPs:/ {print $NF}' $amplify_log)
			if [[ "$amplify_count" == 0 || -z "$amplify_count" ]]; then
				amplify_count="NA"
				amplify_conf="NA"
				amplify_charge="NA"
				amplify_conf_charge="NA"
				amplify_short="NA"
				amplify_short_charge="NA"
				amplify_conf_short="NA"
				amplify_conf_short_charge="NA"
			else
				amplify_conf=$(awk '/Number of high-confidence \(score >= [0-9]\.?[0-9]*\) unique AMPs:/ {print $NF}' $amplify_log)
				amplify_short=$(awk '/Number of short \(length <= [0-9]+\) unique AMPs:/ {print $NF}' $amplify_log)
				amplify_charge=$(awk '/Number of positive \(charge >= -?[0-9]+\) unique AMPs:/ {print $NF}' $amplify_log)
				amplify_conf_charge=$(awk '/Number of high confidence \(score >= [0-9]\.?[0-9]*\) and positive \(charge >= -?[0-9]+\) unique AMPS:/ {print $NF}' $amplify_log)
				amplify_short_charge=$(awk '/Number of short \(length <= [0-9]+\) and high-confidence \(score >= [0-9]\.?[0-9]*\) unique AMPs:/ {print $NF}' $amplify_log)
				amplify_conf_short_charge=$(awk '/Number of positive \(charge >= -?[0-9]+\), short \(length <= [0-9]+\), and high-confidence \(score >= [0-9]\.?[0-9]*\) unique AMPs:/ {print $NF}' $amplify_log)
			fi
		else
			amplify_count="NA"
			amplify_conf="NA"
			amplify_charge="NA"
			amplify_short="NA"
			amplify_conf_short="NA"
			amplify_conf_short_charge="NA"
		fi
		# Final line
		echo -e "$path\t$num_reads\t$num_transcripts\t$num_filter\t$num_annotated\t$jackhmmer_count\t$amplify_count\t$amplify_short\t$amplify_conf\t$amplify_charge\t$amplify_conf_short\t$amplify_conf_charge\t$amplify_short_charge\t$amplify_conf_short_charge" | tee -a $outfile

		#	echo -e "$path\t$accession\t$num_reads\t$num_transcripts\t$num_annotated\t$nhmmer_count" | tee -a $outfile
		#	done < <(cut -f1,2 -d$'\t' $1)
	done < <(cut -f1 -d$'\t' $1)
else
	for path in "$@"; do
		fastp_log=$(ls -t $ROOT_DIR/$path/logs/03-trimmed_reads-*.log 2>/dev/null | head -n1 || true)
		if [[ -s $fastp_log ]]; then
			# number of filtered reads
			num_reads=$(awk '/Reads passed filter:/ {print $NF}' $fastp_log)

			if [[ "$num_reads" == 0 || -z "$num_reads" ]]; then
				num_reads="NA"
			fi

			# number of transcripts
			rnabloom_log=$(ls -t $ROOT_DIR/$path/logs/05-assembly-*.log 2>/dev/null | head -n1 || true)
			if [[ -s $rnabloom_log ]]; then
				num_transcripts=$(awk '/Total number of assembled non-redundant transcripts:/ {print $NF}' $rnabloom_log)
				#			num_transcripts=$(printf "%'d" $num_transcripts)
				if [[ "$num_transcripts" == 0 || -z $num_transcripts ]]; then
					num_transcripts="NA"
				fi
			else
				num_transcripts="NA"
			fi
		else
			num_reads="NA"
			num_transcripts="NA"
		fi
		filter_log=$(ls -t $ROOT_DIR/$path/logs/06-filtering-*.log 2>/dev/null | head -n1 || true)

		if [[ -s $filter_log ]]; then
			num_filter=$(awk '/^After +filtering:/ {print $NF}' $filter_log)
			if [[ $num_filter == 0 || -z $num_filter ]]; then
				num_filter="NA"
			fi
		else
			num_filter="NA"
		fi

		td_log=$(ls -t $ROOT_DIR/$path/logs/07-translation-*.log 2>/dev/null | head -n1 || true)

		# number of annotated sequences
		if [[ -s $td_log ]]; then
			num_annotated=$(awk '/Number of valid ORFs:/ {print $NF}' $td_log)

			if [[ "$num_annotated" == 0 || -z $num_annotated ]]; then
				num_annotated="NA"
			fi
		else
			num_annotated="NA"
		fi

		# number of AMP proteins

		jackhmmer_log=$(ls -t $ROOT_DIR/$path/logs/08-homology-*.log 2>/dev/null | head -n1 || true)
		if [[ -s $jackhmmer_log ]]; then
			jackhmmer_count=$(awk '/Number of AMPs found \(non-redundant\):/ {print $NF}' $jackhmmer_log)
			if [[ "$jackhmmer_count" == 0 || -z "$jackhmmer_count" ]]; then
				jackhmmer_count="NA"
			fi
		else
			jackhmmer_count="NA"
		fi

		amplify_log=$(ls -t $ROOT_DIR/$path/logs/10-amplify-*.log 2>/dev/null | head -n1 || true)

		if [[ -s $amplify_log ]]; then
			amplify_count=$(awk '/Number of unique AMPs:/ {print $NF}' $amplify_log)
			if [[ "$amplify_count" == 0 || -z "$amplify_count" ]]; then
				amplify_count="NA"
				amplify_conf="NA"
				amplify_short="NA"
				amplify_charge="NA"
				amplify_conf_charge="NA"
				amplify_short_charge="NA"
				amplify_conf_short="NA"
				amplify_conf_short_charge="NA"
			else
				amplify_conf=$(awk '/Number of high-confidence \(score >= [0-9]\.?[0-9]*\) unique AMPs:/ {print $NF}' $amplify_log)
				amplify_short=$(awk '/Number of short \(length <= [0-9]+\) unique AMPs:/ {print $NF}' $amplify_log)
				amplify_charge=$(awk '/Number of positive \(charge >= -?[0-9]+\) unique AMPs:/ {print $NF}' $amplify_log)
				amplify_conf_charge=$(awk '/Number of high confidence \(score >= [0-9]\.?[0-9]*\) and positive \(charge >= -?[0-9]+\) unique AMPS:/ {print $NF}' $amplify_log)
				amplify_short_charge=$(awk '/Number of short \(length <= [0-9]+\) and high-confidence \(score >= [0-9]\.?[0-9]*\) unique AMPs:/ {print $NF}' $amplify_log)
				amplify_conf_short=$(awk '/Number of short \(length <= [0-9]+\) and high-confidence \(score >= [0-9]\.?[0-9]*\) unique AMPs:/ {print $NF}' $amplify_log)
				amplify_conf_short_charge=$(awk '/Number of positive \(charge >= -?[0-9]+\), short \(length <= [0-9]+\), and high-confidence \(score >= [0-9]\.?[0-9]*\) unique AMPs:/ {print $NF}' $amplify_log)

			fi
		else
			amplify_count="NA"
			amplify_conf="NA"
			amplify_charge="NA"
			amplify_short="NA"
			amplify_conf_charge="NA"
			amplify_short_charge="NA"
			amplify_conf_short="NA"
			amplify_conf_short_charge="NA"
		fi
		# Final line
		echo -e "$path\t$num_reads\t$num_transcripts\t$num_filter\t$num_annotated\t$jackhmmer_count\t$amplify_count\t$amplify_short\t$amplify_conf\t$amplify_charge\t$amplify_conf_short\t$amplify_conf_charge\t$amplify_short_charge\t$amplify_conf_short_charge" | tee -a $outfile

		#	echo -e "$path\t$accession\t$num_reads\t$num_transcripts\t$num_annotated\t$nhmmer_count" | tee -a $outfile
	done
fi
