#!/bin/bash
set -euo pipefail
PROGRAM=$(basename $0)
# nr_fasta=$(dirname $RUN_ENTAP)/extra-db/nr.fasta

# 1 - get_help function
function get_help() {
	echo "DESCRIPTION:" 1>&2
	echo -e "\
		\tConfigures environment variables for the run.sable script.\n\
		\tFor more information: $(dirname $RUN_SABLE)/README\n \
		" | column -s $'\t' -t 1>&2
	echo 1>&2

	echo "USAGE(S):" 1>&2
	echo -e "\
		\t$PROGRAM [OPTIONS]\n \
		" | column -s $'\t' -t 1>&2
	echo 1>&2

	echo "OPTION(S):" 1>&2
	echo -e "\
		\t-h\tshow this help menu\n\
		\t-t\tnumber of threads\t(default = 8)\n\
		" | column -s$'\t' -t 1>&2

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

# 3 - no arguments given is NORMAL, do not check
# if [[ "$#" -eq 0 ]]
# then
# 	get_help;
# fa

# 4 - get options
custom_threads=false
while getopts :ht: opt; do
	case $opt in
	#		f) nr_fasta=$(realpath $OPTARG);;
	h) get_help ;;
	t)
		threads="$OPTARG"
		custom_threads=true
		;;
	\?)
		print_line "Invalid option: -$OPTARG"
		;;
	esac
done

shift $((OPTIND - 1))

# 5 - incorrect number of arguments
if [[ "$#" -ne 0 ]]; then
	print_line "Incorrect number of arguments."
fi

# 6 - no 'input' files to check

# 7 - do NOT remove status files, only want this configuration done once

# 8 - print env
echo "HOSTNAME: $(hostname)" 1>&2
echo -e "START: $(date)" 1>&2
# start_sec=$(date '+%s')

if command -v pigz &>/dev/null; then
	if [[ "$custom_threads" = true ]]; then
		compress="pigz -p $threads"
	else
		compress=pigz
	fi
else
	compress=gzip
fi
# DOWNLOAD THE NR FASTA
sable_dir=$(dirname $RUN_SABLE)

outdir=$sable_dir/nr
mkdir -p $outdir
# nr="ftp://ftp.ncbi.nlm.nih.gov/blast/db"
nr="ftp://ftp.ncbi.nlm.nih.gov/blast/db/FASTA/nr.gz"
if [[ -f $outdir/SABLE_CONFIG.FAIL ]]; then
	rm $outdir/SABLE_CONFIG.FAIL
fi

if [[ -f $outdir/SABLE_CONFIG.DONE ]]; then
	rm $outdir/SABLE_CONFIG.DONE
fi

# Download NCBI NR database
filename=$(basename "$nr")
# Download the NR based on time stamp
echo "Downloading the metadata for the NCBI NR protein database..." 1>&2
nr_start=$(date '+%s')
wget -N -o $outdir/nr.log -P $outdir $(dirname $(dirname $nr))/README ${nr}.md5

# give full path in checksum
sed -i "s|nr.gz|$outdir/nr.gz|" $outdir/${filename}.md5

echo "Downloading the NCBI NR protein database..." 1>&2
wget -N -a $outdir/nr.log -P $outdir $nr # $(dirname $(dirname $nr))/README
nr_end=$(date '+%s')
$ROOT_DIR/scripts/get-runtime.sh $nr_start $nr_end 1>&2
echo 1>&2

# Do a MD5SUM to check
echo "Checking the MD5 sum of the NCBI NR protein database..." 1>&2
md5sum -c $outdir/${filename}.md5

echo "Decompressing ${filename}..." 1>&2
${compress} -d $outdir/$filename

# rename to FASTA
mv $outdir/${filename/.gz/} $outdir/${filename/.gz/.fasta}

# echo "Downloading the metadata for the NCBI NR protein database..." 1>&2
#  nr_start=$(date '+%s')
# wget -N -o $outdir/nr.log -P $outdir $nr/README
#
# echo "Downloading the pre-formatted NCBI NR protein database..." 1>&2
# wget -N -a $outdir/nr.log -P $outdir $nr/nr*
#
# nr_end=$(date '+%s')
# $ROOT_DIR/scripts/get-runtime.sh $nr_start $nr_end 1>&2
# echo 1>&2
#
# if [[ ! -f $outdir/MD5SUM.DONE ]]
# then
# 	echo "Checking the MD5 sum of the NCBI NR protein database..." 1>&2
# 	# sed -i "s|nr\.|$outdir/nr.|" $outdir/*.md5
# 	cd $outdir
# 	md5sum -c *.md5
# 	if [[ "$?" -ne 0 ]]
# 	then
# 		echo "ERROR: MD5 checksum failed. The NCBI NR database was not downloaded correctly." 1>&2; printf '%.0s=' $(seq 1 $(tput cols)) 1>&2; echo 1>&2; get_help
# 	fi
# 	touch $outdir/MD5SUM.DONE
# 	cd - &> /dev/null
# else
# 	echo "Skipping MD5 sum check as it's already been done..." 1>&2
# fi
#
#
# echo "Decompressing tarballs..." 1>&2
#
# for i in $outdir/*.tar.gz
# do
# 	tar -C $outdir -I $compress -xf $i & # 2>> $outdir/tar.log only when verbose &
# done
#
# wait

# change the environment variables
echo "PROGRAM: $(command -v $RUN_SABLE)"
echo -e "VERSION: $(grep "SABLE ver" $RUN_SABLE | awk '{print $NF}')\n"

sed -i "s|export SABLE_DIR=\".\+\"|export SABLE_DIR=\"$sable_dir\"|" $RUN_SABLE
sed -i "s|export BLAST_DIR=\".\+\"|export BLAST_DIR=\"$BLAST_DIR\"|" $RUN_SABLE
sed -i "s|^export PRIMARY_DATABASE=\".\+\"|export PRIMARY_DATABASE=\"$sable_dir/GI_indexes/pfam_index\"|" $RUN_SABLE
sed -i "s|export SECONDARY_DATABASE=\".\+\"|export SECONDARY_DATABASE=\"$sable_dir/GI_indexes/swissprot_index\"|" $RUN_SABLE
sed -i "s|mkdir \$PBS_JOBID|mkdir -p \$PBS_JOBID|" $RUN_SABLE

# Add threads to SABLE
if [[ "$(grep -c THREADS $sable_dir/sable.pl)" -eq 0 ]]; then
	sed -i 's/\$installDir=\$ENV{SABLE_DIR}/\$THREADS=int(\$ARGV[0]);\n$installDir=\$ENV{SABLE_DIR}/' $sable_dir/sable.pl
	sed -i 's/-num_threads 2/-num_threads \$THREADS/g' $sable_dir/sable.pl
	sed -i 's/remDir=\$PWD/remDir=\$PWD;\nTHREADS=\$1;/' $RUN_SABLE
	sed -i 's/sable.pl$/sable.pl \$THREADS/' $RUN_SABLE
fi

# makeblastdb
echo "PROGRAM: $(command -v $BLAST_DIR/makeblastdb)" 1>&2
echo -e "VERSION: $($BLAST_DIR/makeblastdb -version | tail -n1 | cut -f4- -d' ')\n" 1>&2

echo "Configuring NR database for SABLE..." 1>&2
echo -e "COMMAND: $BLAST_DIR/makeblastdb -dbtype prot -in $outdir/nr.fasta -out $outdir/nr -logfile $outdir/makeblastdb -parse_seqids\n" 1>&2
$BLAST_DIR/makeblastdb -dbtype prot -in $outdir/nr.fasta -out $outdir/nr -logfile $outdir/nr.log -parse_seqids

if [[ "$(ls $outdir/nr.*.pni 2>/dev/null | wc -l)" -gt 0 ]]; then
	touch $outdir/SABLE_CONFIG.DONE
	#	sed -i "s|export NR_DIR=\".\+\"|export NR_DIR=\"$nr_dir/nr\"|" $RUN_SABLE
	sed -i "s|export NR_DIR=\".\+\"|export NR_DIR=\"$outdir\"|" $RUN_SABLE
else
	touch $outdir/SABLE_CONFIG.FAIL
	echo "ERROR: makeblastdb for NR failed." 1>&2
	exit 2
fi
echo "END: $(date)" 1>&2
# end_sec=$(date '+%s')

# $ROOT_DIR/scripts/get-runtime.sh -T $start_sec $end_sec 1>&2
# echo 1>&2

echo "STATUS: complete" 1>&2
