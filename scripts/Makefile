SHELL = /bin/bash
THREADS = 48
END := $(wildcard *.END)
LIB := $(wildcard *.LIB)
TAXON_CLASS := $(wildcard *.CLASS)
REF_AMP := $(wildcard $(ROOT_DIR)/amp_seqs/amps.*.prot.combined.faa)
RAW_READS := $(wildcard raw_reads/*.fastq.gz)
TRIMMED_READS := $(wildcard trimmed_reads/*.paired.fastq.gz)

.PHONY: all amplify cleavage homology translation filtering assembly readslist trim reads accessions clean
# final
all: amplify

# 10. amplify
amplify: amplify/amps.conf.short.charge.nr.faa

amplify/amps.conf.short.charge.nr.faa amplify/AMPLIFY.DONE: $(ROOT_DIR)/scripts/run-amplify.sh cleavage/cleaved.mature.len.faa $(ROOT_DIR)/scripts/get-runtime.sh $(ROOT_DIR)/scripts/run-cdhit.sh cleavage/CLEAVE.DONE
	$< -o amplify cleavage/cleaved.mature.len.faa &> logs/10-amplify.log

# 9. cleavage
cleavage: cleavage/cleaved.mature.len.faa

cleavage/cleaved.mature.len.faa cleavage/CLEAVE.DONE: $(ROOT_DIR)/scripts/cleave.sh homology/jackhmmer.nr.faa $(ROOT_DIR)/scripts/get-runtime.sh homology/HOMOLOGY.DONE
	$< -o cleavage homology/jackhmmer.nr.faa &> logs/09-cleavage.log

# 8. homology search
homology: homology/jackhmmer.nr.faa

homology/jackhmmer.nr.faa homology/HOMOLOGY.DONE: $(ROOT_DIR)/scripts/run-jackhmmer.sh $(REF_AMP) translation/rnabloom.transcripts.filtered.transdecoder.faa $(ROOT_DIR)/scripts/get-runtime.sh $(TAXON_CLASS) $(ROOT_DIR)/scripts/run-cdhit.sh translation/TRANSLATION.DONE
	$< -i translation -o homology -t $(THREADS) &> logs/08-homology.log

# 7. translation 
translation: translation/rnabloom.transcripts.filtered.transdecoder.faa

translation/rnabloom.transcripts.filtered.transdecoder.faa translation/TRANSLATION.DONE: $(ROOT_DIR)/scripts/translate.sh filtering/rnabloom.transcripts.filtered.fa $(ROOT_DIR)/scripts/get-runtime.sh filtering/FILTER.DONE
	$< -o translation filtering/rnabloom.transcripts.filtered.fa &> logs/07-translation.log

# 6. filter expression 
filtering: filtering/rnabloom.transcripts.filtered.fa

filtering/rnabloom.transcripts.filtered.fa filtering/FILTER.DONE: $(ROOT_DIR)/scripts/filter-expression.sh assembly/rnabloom.transcripts.all.fa trimmed_reads/reads.txt $(ROOT_DIR)/scripts/get-runtime.sh assembly/ASSEMBLY.DONE
	$< -t $(THREADS) -o filtering -r assembly/rnabloom.transcripts.all.fa trimmed_reads/reads.txt &> logs/06-filtering.log

# 5. assembly
assembly: assembly/rnabloom.transcripts.all.fa

assembly/rnabloom.transcripts.all.fa assembly/ASSEMBLY.DONE: $(ROOT_DIR)/scripts/run-rnabloom.sh trimmed_reads/reads.txt $(LIB) $(END) $(ROOT_DIR)/scripts/get-runtime.sh trimmed_reads/READSLIST.DONE
	$< -o assembly -t $(THREADS) trimmed_reads/reads.txt &> logs/05-assembly.log

# 4. make a reads list
readslist: trimmed_reads/reads.txt

trimmed_reads/reads.txt trimmed_reads/READSLIST.DONE: $(ROOT_DIR)/scripts/make-reads-list.sh sra/metadata.tsv $(TRIMMED_READS) $(LIB) $(END) $(ROOT_DIR)/scripts/get-runtime.sh trimmed_reads/TRIM.DONE
	$< -d trimmed_reads sra/metadata.tsv &> logs/04-readslist.log

# 3. trim the reads
trim: $(TRIMMED_READS) trimmed_reads/TRIM.DONE

# trimmed_reads/%.paired.fastq.gz: $(ROOT_DIR)/scripts/trim-reads.sh $(ROOT_DIR)/scripts/run-fastp.sh raw_reads/%.fastq.gz $(ROOT_DIR)/scripts/get-runtime.sh raw_reads/READS.DONE
#	$< -i raw_reads -o trimmed_reads -t $(THREADS) &> logs/03-trimmed_reads.log
trimmed_reads/TRIM.DONE: $(ROOT_DIR)/scripts/trim-reads.sh $(ROOT_DIR)/scripts/run-fastp.sh $(RAW_READS) $(ROOT_DIR)/scripts/get-runtime.sh raw_reads/READS.DONE
	$< -i raw_reads -o trimmed_reads -t $(THREADS) &> logs/03-trimmed_reads.log

# 2. download reads
reads: $(RAW_READS) raw_reads/READS.DONE

# Use the DONE file INSTEAD of wildcard
# raw_reads/%.fastq.gz: $(ROOT_DIR)/scripts/get-reads.sh $(ROOT_DIR)/scripts/get-accession.sh sra/runs.txt $(ROOT_DIR)/scripts/get-runtime.sh sra/RUNS.DONE sra/METADATA.DONE
#	$< -o raw_reads sra/runs.txt &> logs/02-raw_reads.log
raw_reads/READS.DONE: $(ROOT_DIR)/scripts/get-reads.sh $(ROOT_DIR)/scripts/get-accession.sh sra/runs.txt $(ROOT_DIR)/scripts/get-runtime.sh sra/RUNS.DONE sra/METADATA.DONE
	$< -o raw_reads sra/runs.txt &> logs/02-raw_reads.log
# 1. get runs
accessions: sra/runs.txt sra/metadata.tsv

sra/runs.txt sra/metadata.tsv sra/RUNS.DONE sra/METADATA.DONE: $(ROOT_DIR)/scripts/get-runs.sh accessions.txt $(ROOT_DIR)/scripts/get-runtime.sh # $(ROOT_DIR)/CONFIG.DONE $(ROOT_DIR)/SETUP.DONE
	$< -o sra accessions.txt &> logs/01-sra.log

clean:
	rm logs/* 2> /dev/null || true
	rm -rf sra raw_reads trimmed_reads assembly filtering translation homology cleavage amplify nohup.out || true
