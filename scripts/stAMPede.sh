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
	{
		echo -e "PROGRAM: $PROGRAM\n"
		echo "DESCRIPTION:"
		echo -e "\
		\tA wrapper around rAMPage.sh to allow running of multiple assemblies.\n \
		" | table

		echo "USAGE(S)":
		echo -e "\
		\t$PROGRAM [-a <address>] [-d] [-h] [-m] [-p] [-s] [-t <int>] [-v] <accessions TXT file>\n \
		" | table

		echo "OPTION(S):"
		echo -e "\
		\t-a <address>\temail address for alerts\n \
		\t-d\tdebug mode\n \
		\t-h\tshow help menu\n \
		\t-m <target>\tMakefile target\t(default = exonerate)\n \
		\t-p\tallow parallel processes for each dataset\n \
		\t-s\tsimultaenously run rAMPAge on all datasets\t(default if SLURM available)\n \
		\t-t <int>\tnumber of threads\t(default = 48)\n \
		\t-v\tverbose (uses /usr/bin/time -pv to time each rAMPage run)\n \
		" | table

		echo "ACCESSIONS TXT FORMAT:"
		echo -e "\
		\tCLASS/SPECIES/TISSUE_OR_CONDITION/input.txt strandedness\n \
		\tamphibia/ptoftae/skin-liver/input.txt nonstranded\n \
		\tinsecta/mgulosa/venom/input.txt stranded\n \
		" | table

		echo "EXAMPLE(S):"
		echo -e "\
		\t$PROGRAM -a user@example.com -p -s -v accessions.txt\n \
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
parallel=false
verbose=false
multi=false
threads=48
debug=""
target=""
# 4 - get options
while getopts :ha:dpst:vm: opt; do
	case $opt in
	a)
		address="$OPTARG"
		email=true
		;;
	d) debug="-d" ;;
	h) get_help ;;
	m) if [[ "${OPTARG,,}" =~ ^(check|reads|trim|readslist|assembly|filtering|translation|homology|cleavage|amplify|annotation|exonerate|sable|all|clean)$ ]]; then
		target="-m ${OPTARG,,}"
	else
		print_error "Invalid Makefile target specified with -m ${OPTARG}."
	fi ;;
	p) parallel=true ;;
	s) multi=true ;;
	t) threads="$OPTARG" ;;
	v) verbose=true ;;
	\?) print_error "Invalid option: -$OPTARG" ;;
	esac
done

shift $((OPTIND - 1))

# 5 - wrong number arguments given
if [[ "$#" -ne 1 ]]; then
	print_error "Incorrect number of arguments."
fi

# 6 check input files
if [[ ! -f $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) does not exist."
elif [[ ! -s $(realpath $1) ]]; then
	print_error "Input file $(realpath $1) is empty."
fi

# 7 - remove status files
if [[ ! -v ROOT_DIR && ! -f "$ROOT_DIR/CONFIG.DONE" ]]; then
	echo "Environment variables have not been successfuly configured yet." 1>&2
	exit 1
fi
rm -f $ROOT_DIR/STAMPEDE.DONE

# 8 - print environemnt details

{
	echo "HOSTNAME: $(hostname)"
	echo -e "START: $(date)\n"

	echo -e "PATH=$PATH\n"

	echo "CALL: $args (wd: $(pwd))"
	echo -e "THREADS: $threads\n"
} 1>&2

input=$(realpath $1)

num_cols=$(awk '{print NF}' $input | sort -u)

if [[ "$num_cols" -ne 2 ]]; then
	print_error "Input file $input requires 2 columns."
fi

if [[ "$parallel" = true ]]; then
	parallel_opt="-p"
else
	parallel_opt=""
fi

if [[ "$verbose" = true ]]; then
	verbose_opt="-v"
else
	verbose_opt=""
fi

if ! command -v mail &>/dev/null; then
	email=false
	echo -e "System does not have email set up.\n" 1>&2
fi
if command -v sbatch &>/dev/null; then
	while read path strandedness; do
		if [[ "$strandedness" != *[Ss][Tt][Rr][Aa][Nn][Dd][Ee][Dd] ]]; then
			print_error "Column 2 of $input must be 'stranded' or 'nonstranded'."
		fi

		if [[ "$strandedness" == [Ss][Tt][Rr][Aa][Nn][Dd][Ee][Dd] ]]; then
			strand_opt="-s"
		else
			strand_opt=""
		fi
		if [[ "$email" = true ]]; then
			sbatch_email_opt="--mail-type=END"
		else
			sbatch_email_opt=""
		fi
		input_path=$(realpath $path)
		outdir=$(dirname $input_path)
		results+=($outdir)
		class=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}')
		species=$(echo "$outdir" | awk -F "/" '{print $(NF-1)}')
		pool=$(echo "$outdir" | awk -F "/" '{print $NF}' | sed 's/-/_/g')
		echo "Running rAMPage on $(echo "$species" | sed 's/.\+/\L&/' | sed 's/^./\u&. /')..." 1>&2
		echo -e "COMMAND: sbatch $sbatch_email_opt --exclusive --job-name=${species}-${pool} --output ${species}-${pool}.out $ROOT_DIR/scripts/rAMPage.sh $target $debug $verbose_opt -o $outdir -c $class -n $species $strand_opt $parallel_opt $input_path 1>&2\n" 1>&2
		sbatch $sbatch_email_opt --exclusive --job-name=${species}-${pool} --output ${species}-${pool}.out $ROOT_DIR/scripts/rAMPage.sh $target $debug $verbose_opt -o $outdir -c $class -n $species $strand_opt $parallel_opt $input_path
		print_line
	done <$input
	email=false # don't email when this script is done because it just submits only
elif [[ "$multi" = false ]]; then
	while read path strandedness; do
		if [[ "$strandedness" != *[Ss][Tt][Rr][Aa][Nn][Dd][Ee][Dd] ]]; then
			print_error "Column 2 of $input must be 'stranded' or 'nonstranded'."
		fi

		if [[ "$strandedness" == [Ss][Tt][Rr][Aa][Nn][Dd][Ee][Dd] ]]; then
			strand_opt="-s"
		else
			strand_opt=""
		fi
		if [[ "$email" = true ]]; then
			email_opt="-a $address"
		else
			email_opt=""
		fi
		input_path=$(realpath $path)
		outdir=$(dirname $input_path)
		results+=($outdir)
		class=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}')
		species=$(echo "$outdir" | awk -F "/" '{print $(NF-1)}')
		pool=$(echo "$outdir" | awk -F "/" '{print $NF}' | sed 's/-/_/g')
		echo "Running rAMPage on $(echo "$species" | sed 's/.\+/\L&/' | sed 's/^./\u&. /')..." 1>&2
		echo -e "COMMAND: $ROOT_DIR/scripts/rAMPage.sh $target $debug $email_opt $verbose_opt -o $outdir -c $class -n $species $strand_opt $parallel_opt $input_path 1>&2\n" 1>&2
		$ROOT_DIR/scripts/rAMPage.sh $target $debug $email_opt $verbose_opt -o $outdir -c $class -n $species $strand_opt $parallel_opt $input_path 1>&2
		print_line
	done <$input
	echo -e "Path\tPercent of CPU this job got\tElapsed (wall clock) time (h:mm:ss or m:ss)\tMaximum resident set size (kbytes)" >$ROOT_DIR/summary.tsv

	if [[ "$verbose" = true ]]; then
		while read path strandedness; do
			dir=$(dirname $path)
			info=$(grep 'rAMPage' $dir/logs/00-summary.tsv)
			echo -e "$dir\t$info" >>$ROOT_DIR/summary.tsv
		done <$input
		echo 1>&2
		column -s $'\t' -t $ROOT_DIR/summary.tsv 1>&2
	fi
else
	while read path strandedness; do
		if [[ "$strandedness" != *[Ss][Tt][Rr][Aa][Nn][Dd][Ee][Dd] ]]; then
			print_error "Column 2 of $input must be 'stranded' or 'nonstranded'."
		fi

		if [[ "$strandedness" == [Ss][Tt][Rr][Aa][Nn][Dd][Ee][Dd] ]]; then
			strand_opt="-s"
		else
			strand_opt=""
		fi
		if [[ "$email" = true ]]; then
			email_opt="-a $address"
		else
			email_opt=""
		fi
		input_path=$(realpath $path)
		outdir=$(dirname $input_path)
		results+=($outdir)
		class=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}')
		species=$(echo "$outdir" | awk -F "/" '{print $(NF-1)}')
		pool=$(echo "$outdir" | awk -F "/" '{print $NF}' | sed 's/-/_/g')
		mkdir -p $outdir/logs
		echo "Running rAMPage on $(echo "$species" | sed 's/.\+/\L&/' | sed 's/^./\u&. /')..." 1>&2
		echo "See $outdir/logs/00-rAMPage.log for details." 1>&2
		echo -e "COMMAND: nohup $ROOT_DIR/scripts/rAMPage.sh $target $debug $email_opt $verbose_opt -o $outdir -c $class -n $species $strand_opt $parallel_opt $input_path &>/dev/null &\n" 1>&2

		nohup $ROOT_DIR/scripts/rAMPage.sh $target $debug $email_opt $verbose_opt -o $outdir -c $class -n $species $strand_opt $parallel_opt $input_path &>${species}-${pool}.out &
	done <$input
	echo "Submitted using nohup." 1>&2
#	wait
#
#	#
#	if [[ "$verbose" = true ]]; then
#		while read path strandedness; do
#			input_path=$(realpath $path)
#			outdir=$(dirname $input_path)
#			exit_status=$(awk '/Exit status:/ {print $NF}' $outdir/logs/00-rAMPage.log)
#			class=$(echo "$outdir" | awk -F "/" '{print $(NF-2)}')
#			species=$(echo "$outdir" | awk -F "/" '{print $(NF-1)}')
#			if [[ "$exit_status" -ne 0 ]]; then
#				species=$(echo "$species" | sed 's/^./\u&. /')
#				echo "ERROR: $species: FAILED" 1>&2
#				echo -e "\nEND: $(date)\n" 1>&2
#				echo -e "STATUS: FAILED\n" 1>&2
#
#				if [[ "$email" = true ]]; then
#					# 	species=$(echo "$species" | sed 's/.\+/\L&/' | sed 's/^./\u&. /')
#					# echo "$outdir" | mail -s "${species^}: rAMPage: SUCCESS" "$address"
#					pwd | mail -s "stAMPede: FAILED" "$address"
#					echo -e "\nEmail alert sent to $address." 1>&2
#				fi
#				touch $ROOT_DIR/STAMPEDE.FAIL
#				exit 1
#			fi
#		done <$input
#	fi
#	echo -e "Path\tPercent of CPU this job got\tElapsed (wall clock) time (h:mm:ss or m:ss)\tMaximum resident set size (kbytes)" >$ROOT_DIR/summary.tsv
#
## 	if [[ "$verbose" = true ]]; then
## 		while read path strandedness; do
## 			dir=$(dirname $path)
## 			info=$(grep 'rAMPage' $dir/logs/00-summary.tsv)
## 			echo -e "$dir\t$info" >>$ROOT_DIR/summary.tsv
## 		done <$input
## 		echo 1>&2
## 		column -s $'\t' -t $ROOT_DIR/summary.tsv 1>&2
## 	fi
fi

echo -e "\nEND: $(date)\n" 1>&2
echo -e "STATUS: DONE\n" 1>&2

# if ! command -v sbatch &>/dev/null; then
# 	if [[ "${#results[@]}" -ne 0 ]]; then
# 		echo "Output:" 1>&2
# 		for i in ${results[@]}; do
# 			echo -e "\t - $i/amplify/amps.final.faa\n"
# 		done | table 1>&2
# 		echo 1>&2
# 		if [[ "$verbose" = true ]]; then
# 			echo "Summary: $ROOT_DIR/summary.tsv" 1>&2
# 		fi
# 	fi
# fi
# touch $ROOT_DIR/STAMPEDE.DONE
#
# if [[ "$email" = true ]]; then
# 	# 	species=$(echo "$species" | sed 's/.\+/\L&/' | sed 's/^./\u&. /')
# 	# echo "$outdir" | mail -s "${species^}: rAMPage: SUCCESS" "$address"
# 	pwd | mail -s "stAMPede: SUCCESS" "$address"
# 	echo -e "\nEmail alert sent to $address." 1>&2
# fi
