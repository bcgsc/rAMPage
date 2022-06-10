#!/bin/bash
set -o pipefail
if [[ ! -v ROOT_DIR ]]; then
	echo "ROOT_DIR is unset."
	exit 1
fi

outdir=$ROOT_DIR/src
echo -e "PATH=$PATH\n"

cd $outdir || exit 1

# SIGNALP changes
sed -i "s|SIGNALP=/usr/opt/signalp-3.0|SIGNALP=$outdir/signalp-3.0|" signalp-3.0/signalp
sed -i "s|AWK=nawk|AWK=awk|" signalp-3.0/signalp

# PROP CHANGES
sed -i "s|/usr/cbs/packages/prop/1.0c|$outdir|" prop-1.0c/prop
sed -i "51s|setenv SIGNALP /usr/cbs/bio/bin/signalp|setenv SIGNALP $outdir/signalp-3.0/signalp|" prop-1.0c/prop

echo "Testing SignalP:"
signalp-3.0/signalp -t euk signalp-3.0/test/test.seq
signalp_code="$?"

echo "Testing ProP:"
prop-1.0c/prop prop-1.0c/test/EDA_HUMAN.fsa 2>&1 | tee temp.out
prop_code=$(grep -c 'Segmentation fault' temp.out)

echo "Testing ProP with SignalP:"
prop-1.0c/prop -s prop-1.0c/test/EDA_HUMAN.fsa 2>&1 | tee temp.out
prop_with_sig_code=$(grep -c 'Segmentation fault' temp.out)
rm temp.out

if [[ "$signalp_code" -eq 0 ]]; then
	echo "SignalP: SUCCESS"
else
	echo "SignalP: FAILED"
fi

if [[ "$prop_code" -eq 0 ]]; then
	echo "ProP: SUCCESS"
else
	echo "ProP: FAILED"
fi

if [[ "$prop_with_sig_code" -eq 0 ]]; then
	echo "ProP with SignalP: SUCCESS"
else
	echo "ProP with SignalP: FAILED"
fi
