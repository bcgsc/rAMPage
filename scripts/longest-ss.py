#!/usr/bin/env python

from __future__ import print_function
import os
import sys

args = sys.argv[1:]
if len(args) != 1:
    print(f"USAGE: {sys.argv[0]} <secondary structure string>", file=sys.stderr)
    print(f"DESCRIPTION: Takes a secondary structure string from SABLE and outputs summary:", file=sys.stderr)
    print(f"Number of Alpha Helix Residues\tLongest Alpha Helix\tNumber of Beta Strand Residues\tLongest Beta Strand", file=sys.stderr)
    print(f"11\t6\t9\t5", file = sys.stderr)
    sys.exit(1)

# read in ss from command line
ss = args[0]

count=1
i=0

alpha = []
beta = []

# check each consecutive char until does not match
# start checking form that 'non-match' consecutively
while True:
	if i == len(ss)-1:
            if ss[i] == 'H':
                alpha.append(count)
            elif ss[i] == 'E':
                beta.append(count)
            break
	for j in range(i+1,len(ss)):
		if ss[i] == ss[j]:
			count+=1
			if j == len(ss)-1:
                            if ss[i] == 'H':
                                alpha.append(count)
                            elif ss[i] == 'E':
                                beta.append(count)
                            i=j
                            break
		else:
                    if i == 0:
                            if ss[i] == 'H':
                                alpha.append(count)
                            elif ss[i] == 'E':
                                beta.append(count)
                    else:
                            if ss[i] == 'H':
                                alpha.append(count)
                            elif ss[i] == 'E':
                                beta.append(count)
                    i=j
                    count=1
                    break

if len(alpha) == 0:
    alpha_max = 0
    alpha_sum = 0
else:
    alpha_max = max(alpha)
    alpha_sum = sum(alpha)

if len(beta) == 0:
    beta_max = 0
    beta_sum = 0
else:
    beta_max = max(beta)
    beta_sum = sum(beta)

print(f"{alpha_sum}\t{alpha_max}\t{beta_sum}\t{beta_max}")
