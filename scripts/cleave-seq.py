#!/usr/bin/env python3

from __future__ import print_function
from Bio import SeqIO
from itertools import combinations

import os
import sys
import pandas as pd
import csv

# Ask for input of
# Important: 1st argument is path to FASTA, second argument is path to TSV, third argument is Output directory
args = sys.argv[1:]

if len(sys.argv[1:]) != 3:
    script_name = sys.argv[0]
    print(f"Usage: {script_name} <FASTA> <ProP TSV file> <output directory>", file=sys.stderr)
    sys.exit(1)

INPUT_FASTA = args[0]
TSV = args[1]
OUTDIR = args[2]
if os.path.isdir(OUTDIR):
    print("Directory already exists. Proceeding with cleaving...", file=sys.stderr)
else:
    print("Directory does NOT exist. Create a new directory and try again...", file=sys.stderr)
    sys.exit(1)


# Read the input TSV, convert it to csv
# the csv file is named new_csv and the variable its stored in is called read
name = TSV
col_list = ["Sequence", "Signal Peptide", "Propeptide Cleavage"]
name_tsv = pd.read_table(name, sep='\t', usecols=col_list)

name_tsv.to_csv(OUTDIR + "/new_csv")
csv_read = pd.read_csv(OUTDIR + "/new_csv")

sig_seq = open(OUTDIR + "/signal_seq.faa", "w+")
cleaved_seq = open(OUTDIR + '/mature_cleaved_seq.faa', "w+")
recombined_seq = open(OUTDIR + '/recombined_seq.faa', "w+")
adj_seq = open(OUTDIR + "/adjacent_seq.faa", "w+")

# Read FASTA input
fasta_input = open(INPUT_FASTA, 'r')
fasta_dict = SeqIO.to_dict(SeqIO.parse(fasta_input, "fasta"))

with open(OUTDIR + "/new_csv", newline='') as f:
    reader = csv.reader(f)
    row1 = next(reader)  # gets the first line
    for row in reader:

        key = row[1]
        sequence = fasta_dict[key]
        sequence = str(sequence.seq[:])

        # Making a list of all the positions
        Signal_P = int(row[2])

        list_p_str = row[3].split(",")
        if list_p_str[0] == "0":
            ProP = []
        else:
            ProP = list(map(int, list_p_str))

        cut_list = [int(Signal_P)]
        cut_list = cut_list + ProP

        n_prop = len(ProP)

# Cleaving using string slicing

# Case 1: where there is a signal and Pro peptide cleavage sites and its before the first cleavage site

        if Signal_P > 0 and n_prop > 0:

            if cut_list[1] > cut_list[0]:
                signal_seq = sequence[0:cut_list[0]]
                list_seq = []
                sig_seq.write(">" + str(key) + "-signal_sequence" + "\n" + str(signal_seq) + "\n")

                a = 0
                b = 1
                m = 1
                while n_prop >= 0:
                    Name_mature = ""

                    # because of 0 based indexing, start from cut_list[a] and not cut_list[a] + 1
                    if n_prop == 0:
                        Name_mature = sequence[cut_list[a]:]
                    else:
                        Name_mature = sequence[cut_list[a]: cut_list[b]]

                    cleaved_seq.write(">" + str(key) + "-sig_mature-" + str(m) + "\n" + str(Name_mature) + "\n")
                    list_seq.append(Name_mature)
                    m += 1
                    a += 1
                    b += 1
                    n_prop = n_prop - 1

                length_recomb = combinations(range(1, len(list_seq) + 1), 2)
                for v in list(length_recomb):
                    if v[1] - v[0] != 1:
                        recombined_seq.write(">" + str(key) + "-sig_recomb-" + str(v[0]) + "_" + str(v[1]) +
                                             "\n" + list_seq[v[0] - 1] + list_seq[v[1] - 1] + "\n")
                    else:
                        adj_seq.write(">" + str(key) + "-sig_recomb-" + str(v[0]) + "_" + str(v[1]) +
                                      "\n" + list_seq[v[0] - 1] + list_seq[v[1] - 1] + "\n")

                if len(list_seq) >= 3:
                    length_recomb = combinations(range(1, len(list_seq) + 1), 3)
                    for v in list(length_recomb):
                        if v[1] - v[0] != 1 and v[2] - v[1] != 1:
                            recombined_seq.write(">" + str(key) + "-sig_recomb-" + str(v[0]) + "_" + str(v[1]) +
                                                 "_" + str(v[2]) + "\n" + list_seq[v[0] - 1] + list_seq[v[1] - 1] +
                                                 list_seq[v[2] - 1] + "\n")
                        else:
                            adj_seq.write(">" + str(key) + "-sig_recomb-" + str(v[0]) + "_" + str(v[1]) +
                                          "_" + str(v[2]) + "\n" + list_seq[v[0] - 1] + list_seq[v[1] - 1] +
                                          list_seq[v[2] - 1] + "\n")

# when the first pro peptide is within the signal, cleave the whole signal and start the mature protein sequences after
            # the signal
            elif cut_list[1] < cut_list[0]:
                cut_list = [int(Signal_P)] + ProP[1:]
                signal_seq = sequence[0: cut_list[0]]
                sig_seq.write(">" + str(key) + "-signal_sequence" + "\n" + str(signal_seq) + "\n")

                a = 0
                b = 1
                m = 1
                list_seq = []

                while n_prop > 0:
                    Name_mature = ""

                    if n_prop == 1:
                        Name_mature = sequence[cut_list[a]:]
                    else:
                        Name_mature = sequence[cut_list[a]: cut_list[b]]

                    cleaved_seq.write(">" + str(key) + "-sig_in_mature-" + str(m) + "\n" + str(Name_mature) + "\n")
                    list_seq.append(Name_mature)

                    m = m + 1
                    a = a + 1
                    b = b + 1
                    n_prop = n_prop - 1

                length_recomb = combinations(range(1, len(list_seq) + 1), 2)
                for v in list(length_recomb):
                    if v[1] - v[0] != 1:
                        recombined_seq.write(">" + str(key) + "-sig_in_recomb-" + str(v[0]) + "_" + str(v[1]) +
                                             "\n" + list_seq[v[0] - 1] + list_seq[v[1] - 1] + "\n")
                    else:
                        adj_seq.write(">" + str(key) + "-sig_recomb-" + str(v[0]) + "_" + str(v[1]) +
                                      "\n" + list_seq[v[0] - 1] + list_seq[v[1] - 1] + "\n")

                if len(list_seq) >= 3:
                    length_recomb = combinations(range(1, len(list_seq) + 1), 3)
                    for v in list(length_recomb):
                        if v[1] - v[0] != 1 and v[2] - v[1] != 1:
                            recombined_seq.write(">" + str(key) + "-sig_recomb-" + str(v[0]) + "_" + str(v[1]) +
                                                 "_" + str(v[2]) + "\n" + list_seq[v[0] - 1] + list_seq[v[1] - 1] +
                                                 list_seq[v[2] - 1] + "\n")
                        else:
                            adj_seq.write(">" + str(key) + "-sig_recomb-" + str(v[0]) + "_" + str(v[1]) +
                                          "_" + str(v[2]) + "\n" + list_seq[v[0] - 1] + list_seq[v[1] - 1] +
                                          list_seq[v[2] - 1] + "\n")

# Case 2: where there is a signal sequence but no pro peptide cleavage site

        elif Signal_P > 0 and n_prop == 0:

            signal_seq = sequence[0: cut_list[0]]
            sig_seq.write(">" + str(key) + "-signal_sequence" + "\n" + str(signal_seq) + "\n")
            Name_pro = sequence[cut_list[0]:]
            cleaved_seq.write(">" + str(key) + "-pro"  "\n" + str(Name_pro) + "\n")


# Case 3: where there is no signal peptide, only cleave at peptide cleavage sites

        elif Signal_P == 0 and n_prop > 0:
            a = 0
            b = 1
            m = 2
            list_seq = []
            while n_prop >= 0:
                Name_mature = " "
                Name_mature_1 = " "

                # because of 0 based indexing, start from cut_list[a] and not cut_list[a] + 1
                if a == 0:
                    Name_mature_1 = sequence[0: cut_list[b]]
                    cleaved_seq.write(">" + str(key) + "-no_sig_mature-1" + "\n" + str(Name_mature_1) + "\n")
                    list_seq.append(Name_mature_1)

                else:
                    if n_prop == 0:
                        Name_mature = sequence[cut_list[a]:]
                    else:
                        Name_mature = sequence[cut_list[a]: cut_list[b]]

                    cleaved_seq.write(">" + str(key) + "-no_sig_mature-" + str(m) + "\n" + str(Name_mature) + "\n")
                    list_seq.append(Name_mature)

                    m += 1

                a += 1
                b += 1
                n_prop = n_prop - 1

            length_recomb = combinations(range(1, len(list_seq) + 1), 2)
            for v in list(length_recomb):
                if v[1] - v[0] != 1:
                    recombined_seq.write(">" + str(key) + "-no_sig_recomb-" + str(v[0]) + "_" + str(v[1]) +
                                         "\n" + list_seq[v[0] - 1] + list_seq[v[1] - 1] + "\n")
                else:
                    adj_seq.write(">" + str(key) + "-no_sig_recomb-" + str(v[0]) + "_" + str(v[1]) +
                                  "\n" + list_seq[v[0] - 1] + list_seq[v[1] - 1] + "\n")

            if len(list_seq) >= 3:
                length_recomb = combinations(range(1, len(list_seq) + 1), 3)
                for v in list(length_recomb):
                    if v[1] - v[0] != 1 and v[2] - v[1] != 1:
                        recombined_seq.write(">" + str(key) + "-no_sig_recomb-" + str(v[0]) + "_" + str(v[1]) +
                                             "_" + str(v[2]) + "\n" + list_seq[v[0] - 1] + list_seq[v[1] - 1] +
                                             list_seq[v[2] - 1] + "\n")
                    else:
                        adj_seq.write(">" + str(key) + "-no_sig_recomb-" + str(v[0]) + "_" + str(v[1]) +
                                      "_" + str(v[2]) + "\n" + list_seq[v[0] - 1] + list_seq[v[1] - 1] +
                                      list_seq[v[2] - 1] + "\n")

# Case 4: when the signal peptide cleavage site is the same/adjacent as the first propeptide cleavage site

        elif n_prop > 0 and Signal_P == ProP[0]:

            signal_seq = sequence[0: ProP[0]]
            sig_seq.write(">" + str(key) + "-signal_sequence" + "\n" + str(signal_seq) + "\n")

            a = 0
            b = 1
            m = 1
            list_seq = []
            while n_prop >= 0:

                # because of 0 based indexing, start from cut_list[a] and not cut_list[a] + 1
                if n_prop == 0:
                    Name_mature = sequence[cut_list[a]:]
                else:
                    Name_mature = sequence[cut_list[a]: cut_list[b]]

                cleaved_seq.write(">" + str(key) + "-sig_mature-" + str(m) + "\n" + str(Name_mature) + "\n")
                list_seq = list_seq.append(Name_mature)

                m += 1
                a += 1
                b += 1
                n_prop = n_prop - 1
            length_recomb = combinations(range(1, len(list_seq) + 1), 2)
            for v in list(length_recomb):
                if v[1] - v[0] != 1:
                    recombined_seq.write(">" + str(key) + "-sig_recomb-" + str(v[0]) + "_" + str(v[1]) +
                                         "\n" + list_seq[v[0] - 1] + list_seq[v[1] - 1] + "\n")
                else:
                    adj_seq.write(">" + str(key) + "-sig_recomb-" + str(v[0]) + "_" + str(v[1]) +
                                  "\n" + list_seq[v[0] - 1] + list_seq[v[1] - 1] + "\n")

            if len(list_seq) >= 3:
                length_recomb = combinations(range(1, len(list_seq) + 1), 3)
                for v in list(length_recomb):
                    if v[1] - v[0] != 1 and v[2] - v[1] != 1:
                        recombined_seq.write(">" + str(key) + "-sig_recomb-" + str(v[0]) + "_" + str(v[1]) +
                                             "_" + str(v[2]) + "\n" + list_seq[v[0] - 1] + list_seq[v[1] - 1] +
                                             list_seq[v[2] - 1] + "\n")
                    else:
                        adj_seq.write(">" + str(key) + "-sig_recomb-" + str(v[0]) + "_" + str(v[1]) +
                                      "_" + str(v[2]) + "\n" + list_seq[v[0] - 1] + list_seq[v[1] - 1] +
                                      list_seq[v[2] - 1] + "\n")

        # Case 5: when there is no signal cleavage site or no peptide cleavage site

        else:
            cleaved_seq.write(">" + str(key) + "-no_sig_no_prop" + "\n" + sequence + "\n")

sig_seq.close()
cleaved_seq.close()
recombined_seq.close()
adj_seq.close()
os.remove(OUTDIR + "/new_csv")
