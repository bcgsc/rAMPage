#!/usr/bin/env bash
set -euo pipefail

major_version=0
minor_version=9
patch_version=1

version_message="rAMPage v${major_version}.${minor_version}.${patch_version}\nDiana Lin, Canada's Michael Smith Genome Sciences Centre, BC Cancer\nCopyright 2021"

start_sec=$(date '+%s')

FULL_PROGRAM=$0
PROGRAM=$(basename ${FULL_PROGRAM})

if [[ "$PROGRAM" == "slurm_script" ]]; then
	FULL_PROGRAM=$(scontrol show job $SLURM_JOBID | awk '/Command=/ {print $1}' | awk -F "=" '{print $2}')
	PROGRAM=$(basename ${FULL_PROGRAM})

fi

## SCRIPT that wraps around the Makefile
args="${FULL_PROGRAM} $*"

# 0 - table function
function table() {
	if column -L <(echo) &>/dev/null; then
		cat | column -s $'\t' -t -L 1>&2
	else
		{
			cat | column -s $'\t' -t
			echo
		} 1>&2
	fi
}

# 1 - get_help function
function get_help() {
	{
		echo -e "PROGRAM: $PROGRAM\n"
		# DESCRIPTION:
		echo "DESCRIPTION:"
		echo -e "\
		\tRuns the rAMPage pipeline, using the Makefile.\n \
		" | table

		echo "USAGE(S):"
		echo -e "\
		\t$PROGRAM [-a <address>] [-b] [-c <taxonomic class>] [-d] [-f] [-h] [-m] [-n <species name>] [-o <output directory>] [-p] [-r <FASTA.gz>] [-s] [-t <int>] [-v] <input reads TXT file>\n \
		" | table

		echo "OPTIONS:"
		echo -e "\
		\t-a <address>\temail address for alerts\n \
		\t-b\tbenchmark (uses /usr/bin/time -pv)\n \
		\t-c <class>\ttaxonomic class of the dataset\t(default = top-level directory in \$outdir)\n \
		\t-d\tdebug mode of Makefile\n \
		\t-f\tforce characterization even if no AMPs found\n \
		\t-h\tshow help menu\n \
		\t-m <target>\tMakefile target\t(default = exonerate)\n \
		\t-n <species>\ttaxonomic species or name of the dataset\t(default = second-level directory in \$outdir)\n \
		\t-o <directory>\toutput directory\t(default = directory of input reads TXT file)\n \
		\t-p\trun processes in parallel\n \
		\t-r <FASTA.gz>\treference transcriptome\t(accepted multiple times, *.fna.gz *.fsa_nt.gz)\n \
		\t-s\tstrand-specific library construction\t(default = false)\n \
		\t-t <int>\tnumber of threads\t(default = 48)\n \
		\t-v\tprint version number\n \
		\t-E <e-value>\tE-value threshold for homology search\t(default = 1e-5)\n \
		\t-S <0 to 1>\tAMPlify score threshold for amphibian AMPs\t(default = 0.90)\n \
		\t-L <int>\tLength threshold for AMPs\t(default = 30)\n \
		\t-C <int>\tCharge threshold for AMPs\t(default = 2)\n \
		\t-R\tDisable redundancy removal during transcript assembly\n \
		" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com -c class -n species -p -s -t 8 -o /path/to/output/directory -r /path/to/reference.fna.gz -r /path/to/reference.fsa_nt.gz /path/to/input.txt \n \
		" | table

		echo "INPUT EXAMPLE:"
		echo -e "\
		\ttissue /path/to/readA_1.fastq.gz /path/to/readA_2.fastq.gz\n \
		\ttissue /path/to/readB_1.fastq.gz /path/to/readB_2.fastq.gz\n \
		" | table

		echo "MAKEFILE TARGETS:"
		echo -e "\
		\t01) check\t08) homology\n \
		\t02) reads\t09) cleavage\n \
		\t03) trim\t10) amplify\n \
		\t04) readslist\t11) annotation\n \
		\t05) assembly\t12) exonerate\n \
		\t06) filtering\t13) sable\n \
		\t07) translation\t14) all\n \
		" | table

		#	echo "Reads must be compressed in .gz format."
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

# 2 - print error function
function print_error() {
	{
		echo -e "CALL: $args (wd: $(pwd))\n"
		message="$1"
		echo "$PROGRAM: ERROR: $message"
		print_line
		get_help
	} 1>&2
}

# 3 - no args given

if [[ "$#" -eq 0 ]]; then
	get_help
fi

# 4 - get options
num_threads=48
stranded=false
ref=false
outdir=""
# failed=false
threads=""
parallel=false
email=false
email_opt=""
class=""
species=""
benchmark=false
target="exonerate"
debug=""
forced_characterization=false
rr_assembly=true

custom_evalue=1e-5
custom_score=0.90
custom_length=30
custom_charge=2

while getopts :hba:c:dfr:m:n:o:pst:vE:S:L:C:R opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		email_opt="EMAIL=$address"
		;;
	c)
		# class="${OPTARG,,}"
		class=$(echo "$OPTARG" | sed 's/.\+/\L&/')
		;;
	d)
		debug="--debug"
		;;
	f) forced_characterization=true ;;
	h) get_help ;;
	m) target=$(echo "$OPTARG" | sed 's/.\+/\L&/') ;;
	n)
		species=$(echo "$OPTARG" | sed 's/.\+/\L&/')
		# species="${OPTARG,,}"
		;;
	o) outdir="$(realpath $OPTARG)" ;;
	p) parallel=true ;;
	r)
		reference+=("$OPTARG")
		ref=true
		;;
	s) stranded=true ;;
	t)
		num_threads="$OPTARG"
		threads="THREADS=$num_threads"
		;;
	b) benchmark=true ;;
	v)
		echo -e "$version_message" 1>&2
		exit 0
		;;
	E) custom_evalue=$OPTARG ;;
	S) custom_score=$OPTARG ;;
	L) custom_length=$OPTARG ;;
	C) custom_charge=$OPTARG ;;
	R) rr_assembly=false ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

# 5 - incorrect number of arguments
if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 - check inputs
if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) is empty."
fi

if [[ "${target,,}" =~ ^(check|reads|trim|readslist|assembly|filtering|translation|homology|cleavage|amplify|annotation|exonerate|sable|all|clean)$ ]]; then
	export TARGET=${target,,}
else
	print_error "Invalid Makefile target specified with -m $target."
fi

# check that input file is somehwere in the repository
# if [[ "$(realpath $1)" != */rAMPage* ]]; then
	# print_error "Input file $(realpath $1) must be located within the rAMPage directory."
# fi

if [[ ! -v ROOT_DIR ]]; then
	print_error "ROOT_DIR is unbound. Please export ROOT_DIR=/path/to/rAMPage/GitHub/directory."
fi

if [[ -z $class ]]; then
	# get class from outdir
	class=$(echo "$outdir" | sed "s|$ROOT_DIR||" | awk -F "/" '{print $2}' | sed 's/.\+/\L&/')

fi

if [[ -z $species ]]; then
	species=$(echo "$outdir" | sed "s|$ROOT_DIR||" | awk -F "/" '{print $3}' | sed 's/.\+/\L&/')
fi

export CLASS=$class
# export CLASS=${class,,}
export SPECIES=$species
# export SPECIES=${species,,}

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi

# 7 - remove status files
rm -f $outdir/RAMPAGE.DONE

# 8 - print environemnt details
if [[ ! -v ROOT_DIR && ! -f "$ROOT_DIR/CONFIG.DONE" ]]; then
	echo "Environment variables have not been successfuly configured yet." 1>&2
	exit 1
fi

input=$(realpath $1)

if [[ -z $outdir ]]; then
	outdir=$(dirname $input)
else
	mkdir -p $outdir
	# if INPUT given ISN'T in the output directory, put it there (it IS supposed to be there)
	if [[ ! -s $outdir/$(basename $input) ]]; then
		mv $input $outdir/$(basename $input)
	fi
	input=$outdir/$(basename $input)
fi
mkdir -p $outdir/logs

{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo "CALL: $args (wd: $(pwd))"
	echo -e "THREADS: $num_threads\n"
} | tee $outdir/logs/00-rAMPage.log 1>&2

# check that all rows have the same number of columns
if [[ "$(awk '{print NF}' $input | sort -u | wc -l)" -ne 1 ]]; then
	print_error "Inconsistent number of columns."
fi

export WORKDIR=$outdir

# check that there are either 2 or 3 columns
num_cols=$(awk '{print NF}' $input | sort -u)
if [[ "$num_cols" -eq 2 ]]; then
	#	touch $outdir/SINGLE.END
	export PAIRED=false
elif [[ "$num_cols" -eq 3 ]]; then
	#	touch $outdir/PAIRED.END
	export PAIRED=true
else
	print_error "There are too many columns in the input TXT file."
fi

if [[ "$stranded" = true ]]; then
	#	touch $outdir/STRANDED.LIB
	export STRANDED=true
else
	#	touch $outdir/NONSTRANDED.LIB
	export STRANDED=false
fi

{
	echo "EXPORTED VARIABLES:"
	print_line
	echo "TARGET=$TARGET"
	echo "WORKDIR=$WORKDIR"
	echo "PAIRED=$PAIRED"
	echo "STRANDED=$STRANDED"
	echo "CLASS=$CLASS"
	echo "SPECIES=$SPECIES"
	echo "FORCE_CHAR"=$forced_characterization
	print_line
	echo
} | tee -a $outdir/logs/00-rAMPage.log 1>&2
# class=$(echo "$outdir" | sed "s|$ROOT_DIR/\?||" | awk -F "/" '{print $1}')
# if [[ -n $class ]]; then
# 	touch $outdir/${class^^}.CLASS
# else
# 	print_error "Invalid class taxon in the parent directory name: $(dirname $input | sed "s|$ROOT_DIR/\?||")."
# fi

# MOVE reference to working dir
if [[ $ref = true ]]; then
	for i in "${reference[@]}"; do
		if [[ -s "$i" ]]; then
			if [[ ! -s "$outdir/$(basename $i)" ]]; then
				mv $i $outdir
			fi
		else
			print_error "Reference $(basename $i) does not exist or is empty."
		fi
	done
fi

db=$ROOT_DIR/amp_seqs/amps.${CLASS^}.prot.combined.faa
if [[ ! -s $db ]]; then
	print_error "Reference AMP sequences not found in $db."
fi
if ! /usr/bin/time -pv echo &>/dev/null; then
	benchmark=false
	echo -e "Benchmark option selected but /usr/bin/time -pv not available.\n" 1>&2
fi

if [[ $CLASS == [Aa]mphibia ]]; then
	if (($(echo "$custom_score < 0.50" | bc -l))); then
		places=$(echo "$custom_score" | cut -d. -f2 | tr -d '\n' | wc -m)
		custom_score=$(printf "%1.${places}f" 0.50)
		scores="-s $custom_score"
		# want 0.50 to be the lowest option
	else
		places=$(echo "$custom_score" | cut -d. -f2 | tr -d '\n' | wc -m)
		custom_score2=$(printf "%1.${places}f" $(echo "${custom_score}-0.1" | bc -l))
		if (($(echo "$custom_score2 >= 0.50" | bc -l))); then
			custom_score2_opt="-s $custom_score2"
		else
			custom_score2_opt=""
		fi
		custom_score3=$(printf "%1.${places}f" $(echo "${custom_score2}-0.1" | bc -l))
		if (($(echo "$custom_score3 >= 0.50" | bc -l))); then
			custom_score3_opt="-s $custom_score3"
		else
			custom_score3_opt=""
		fi
		scores="-s $custom_score $custom_score2_opt $custom_score3_opt"
	fi
else
	if (($(echo "$custom_score < 0.5" | bc -l))); then
		places=$(echo "$custom_score" | cut -d. -f2 | tr -d '\n' | wc -m)
		custom_score=$(printf "%1.${places}f" 0.50)
		scores="-s $custom_score"
		# want 0.50 to be the lowest option
	else
		places=$(echo "$custom_score" | cut -d. -f2 | tr -d '\n' | wc -m)
		custom_score1=$(printf "%1.${places}f" $(echo "${custom_score}-0.1" | bc -l))
		if (($(echo "$custom_score1 >= 0.50" | bc -l))); then
			custom_score1_opt="-s $custom_score1"
		else
			custom_score1_opt=""
		fi

		custom_score2=$(printf "%1.${places}f" $(echo "${custom_score1}-0.1" | bc -l))
		if (($(echo "$custom_score2 >= 0.50" | bc -l))); then
			custom_score2_opt="-s $custom_score2"
		else
			custom_score2_opt=""
		fi

		custom_score3=$(printf "%1.${places}f" $(echo "${custom_score2}-0.1" | bc -l))
		if (($(echo "$custom_score3 >= 0.50" | bc -l))); then
			custom_score3_opt="-s $custom_score3"
		else
			custom_score3_opt=""
		fi
		if [[ -z "$custom_score1_opt" ]]; then
			scores="-s $custom_score"
		else
			scores="$custom_score1_opt $custom_score2_opt $custom_score3_opt"
		fi
	fi
fi

custom_length2=$(echo "${custom_length}+20" | bc -l)
custom_length3=$(echo "${custom_length2}+20" | bc -l)
lengths="-l $custom_length -l $custom_length2 -l $custom_length3"

custom_charge2=$(echo "${custom_charge}+2" | bc -l)
custom_charge3=$(echo "${custom_charge2}+2" | bc -l)
custom_charge4=$(echo "${custom_charge3}+2" | bc -l)

charges="-c $custom_charge -c $custom_charge2 -c $custom_charge3 -c $custom_charge4"

# RUN THE PIPELINE USING THE MAKE FILE
echo "Running rAMPage..." 1>&2
echo -e "$version_message" 1>&2
if [[ "$benchmark" = true ]]; then
	if [[ "$target" != "clean" ]]; then
		echo "COMMAND: /usr/bin/time -pv make INPUT=$input $threads PARALLEL=$parallel BENCHMARK=$benchmark SCORE=$scores LENGTH=$lengths CHARGE=$charges EVALUE=$custom_evalue RR=$rr_assembly $email_opt -C $outdir -f $ROOT_DIR/scripts/Makefile $debug $target 2>&1 | tee $outdir/logs/00-rAMPage.log 1>&2" 1>&2

		/usr/bin/time -pv make INPUT=$input $threads PARALLEL=$parallel BENCHMARK=$benchmark SCORE="$scores" LENGTH="$lengths" CHARGE="$charges" EVALUE=$custom_evalue RR=$rr_assembly $email_opt -C $outdir -f $ROOT_DIR/scripts/Makefile $debug $target 2>&1 | tee -a $outdir/logs/00-rAMPage.log 1>&2
	else
		echo "COMMAND: /usr/bin/time -pv make INPUT=$input $threads PARALLEL=$parallel BENCHMARK=$benchmark SCORE=$scores LENGTH=$lengths CHARGE=$charges EVALUE=$custom_evalue RR=$rr_assembly $email_opt -C $outdir -f $ROOT_DIR/scripts/Makefile $debug $target 1>&2" 1>&2

		/usr/bin/time -pv make INPUT=$input $threads PARALLEL=$parallel BENCHMARK=$benchmark SCORE="$scores" LENGTH="$lengths" CHARGE="$charges" EVALUE=$custom_evalue RR=$rr_assembly $email_opt -C $outdir -f $ROOT_DIR/scripts/Makefile $debug $target 1>&2
	fi
else
	if [[ "$target" != "clean" ]]; then
		echo "COMMAND: make INPUT=$input $threads PARALLEL=$parallel BENCHMARK=$benchmark SCORE=$scores LENGTH=$lengths CHARGE=$charges EVALUE=$custom_evalue RR=$rr_assembly $email_opt -C $outdir -f $ROOT_DIR/scripts/Makefile $debug $target 2>&1 | tee $outdir/logs/00-rAMPage.log 1>&2" 1>&2

		make INPUT=$input $threads PARALLEL=$parallel BENCHMARK=$benchmark SCORE="$scores" LENGTH="$lengths" CHARGE="$charges" EVALUE=$custom_evalue RR=$rr_assembly $email_opt -C $outdir -f $ROOT_DIR/scripts/Makefile $debug $target 2>&1 | tee -a $outdir/logs/00-rAMPage.log 1>&2
	else
		echo "COMMAND: make INPUT=$input $threads PARALLEL=$parallel BENCHMARK=$benchmark SCORE=$scores LENGTH=$lengths CHARGE=$charges EVALUE=$custom_evalue RR=$rr_assembly $email_opt -C $outdir -f $ROOT_DIR/scripts/Makefile $debug $target 1>&2" 1>&2

		make INPUT=$input $threads PARALLEL=$parallel BENCHMARK=$benchmark SCORE="$scores" LENGTH="$lengths" CHARGE="$charges" EVALUE=$custom_evalue RR=$rr_assembly $email_opt -C $outdir -f $ROOT_DIR/scripts/Makefile $debug $target 1>&2
	fi
fi

# PERFORM SUMMARY
if [[ "$target" != "clean" ]]; then
	if [[ "$email" = true ]]; then
		if [[ "$benchmark" == true ]]; then
			echo -e "\nSummary of time, CPU, and memory usage: $outdir/logs/00-summary.log" 1>&2
			/usr/bin/time -pv $ROOT_DIR/scripts/summarize-benchmark.sh -a "$address" $outdir/logs &>$outdir/logs/00-summary.log
		else
			echo -e "\nBenchmark option not selected-- time, CPU, and memory usage not recorded." 1>&2
		fi
	else
		if [[ "$benchmark" == true ]]; then
			echo -e "\nSummary of time, CPU, and memory usage: $outdir/logs/00-summary.log" 1>&2
			/usr/bin/time -pv $ROOT_DIR/scripts/summarize-benchmark.sh $outdir/logs &>$outdir/logs/00-summary.log
		else
			echo -e "\nBenchmark option not selected-- time, CPU, and memory usage not recorded." 1>&2
		fi
	fi
	# summarize the log files here
	if [[ "$email" = true ]]; then
		if [[ "$benchmark" == true ]]; then
			echo -e "\nSummary statistics: $outdir/logs/00-stats.log" 1>&2
			/usr/bin/time -pv $ROOT_DIR/scripts/summarize.sh -a "$address" $outdir/logs &>$outdir/logs/00-stats.log
		else
			echo -e "\nSummary statistics: $outdir/logs/00-stats.log" 1>&2
			$ROOT_DIR/scripts/summarize.sh -a "$address" $outdir/logs &>$outdir/logs/00-stats.log
		fi
	else
		if [[ "$benchmark" == true ]]; then
			echo -e "\nSummary statistics: $outdir/logs/00-stats.log" 1>&2
			/usr/bin/time -pv $ROOT_DIR/scripts/summarize.sh $outdir/logs &>$outdir/logs/00-stats.log
		else
			echo -e "\nSummary statistics: $outdir/logs/00-stats.log" 1>&2
			$ROOT_DIR/scripts/summarize.sh $outdir/logs &>$outdir/logs/00-stats.log
		fi
	fi
fi

end_sec=$(date '+%s')

echo -e "\nEND: $(date)" 1>&2
runtime=$($ROOT_DIR/scripts/convert-time.sh $(echo "${end_sec}-${start_sec}" | bc))
echo "RUNTIME: ${runtime}" 1>&2
echo -e "\nSTATUS: DONE" 1>&2
touch $outdir/RAMPAGE.DONE

if [[ "$email" = true ]]; then
	species=$(echo "$SPECIES" | sed 's/^./\u&. /')
	# echo "$outdir" | mail -s "${species^}: rAMPage: SUCCESS" "$address"
	echo "$outdir" | mail -s "${species}: rAMPage: SUCCESS" "$address"
	echo -e "\nEmail alert sent to $address." 1>&2
fi
