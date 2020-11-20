SHELL = /usr/bin/env bash
THREADS = 48
PARALLEL = false
EMAIL = ""

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
	if [[ -n $(EMAIL) ]]; then \
		/usr/bin/time -pv $< -a $(EMAIL) -o amplify cleavage/cleaved.mature.len.faa &> logs/10-amplify.log; \
	else \
		/usr/bin/time -pv $< -o amplify cleavage/cleaved.mature.len.faa; \
	fi

# 9. cleavage
cleavage: cleavage/cleaved.mature.len.faa

cleavage/cleaved.mature.len.faa cleavage/CLEAVE.DONE: $(ROOT_DIR)/scripts/cleave.sh homology/jackhmmer.nr.faa $(ROOT_DIR)/scripts/get-runtime.sh homology/HOMOLOGY.DONE
	if [[ -n $(EMAIL) ]]; then \
		/usr/bin/time -pv $< -a $(EMAIL) -o cleavage homology/jackhmmer.nr.faa &> logs/09-cleavage.log; \
	else \
		/usr/bin/time -pv $< -o cleavage homology/jackhmmer.nr.faa &> logs/09-cleavage.log; \
	fi

# 8. homology search
homology: homology/jackhmmer.nr.faa

homology/jackhmmer.nr.faa homology/HOMOLOGY.DONE: $(ROOT_DIR)/scripts/run-jackhmmer.sh $(REF_AMP) translation/rnabloom.transcripts.filtered.transdecoder.faa $(ROOT_DIR)/scripts/get-runtime.sh $(TAXON_CLASS) $(ROOT_DIR)/scripts/run-cdhit.sh translation/TRANSLATION.DONE
	if [[ -n $(EMAIL) ]]; then \
		/usr/bin/time -pv $< -a $(EMAIL) -o homology -t $(THREADS) translation/rnabloom.transcripts.filtered.transdecoder.faa &> logs/08-homology.log; \
	else \
		/usr/bin/time -pv $< -o homology -t $(THREADS) translation/rnabloom.transcripts.filtered.transdecoder.faa &> logs/08-homology.log; \
	fi

# 7. translation 
translation: translation/rnabloom.transcripts.filtered.transdecoder.faa

translation/rnabloom.transcripts.filtered.transdecoder.faa translation/TRANSLATION.DONE: $(ROOT_DIR)/scripts/translate.sh filtering/rnabloom.transcripts.filtered.fa $(ROOT_DIR)/scripts/get-runtime.sh filtering/FILTER.DONE
	if [[ -n $(EMAIL) ]]; then \
		/usr/bin/time -pv $< -a $(EMAIL) -o translation filtering/rnabloom.transcripts.filtered.fa &> logs/07-translation.log; \
	else \
		/usr/bin/time -pv $< -o translation filtering/rnabloom.transcripts.filtered.fa &> logs/07-translation.log; \
	fi

# 6. filter expression 
filtering: filtering/rnabloom.transcripts.filtered.fa

filtering/rnabloom.transcripts.filtered.fa filtering/FILTER.DONE: $(ROOT_DIR)/scripts/filter-expression.sh assembly/rnabloom.transcripts.all.fa trimmed_reads/reads.txt $(ROOT_DIR)/scripts/get-runtime.sh assembly/ASSEMBLY.DONE
	if [[ -n $(EMAIL) ]]; then \
		/usr/bin/time -pv $< -a $(EMAIL) -t $(THREADS) -o filtering -r assembly/rnabloom.transcripts.all.fa trimmed_reads/reads.txt &> logs/06-filtering.log; \
	else \
		/usr/bin/time -pv $< -t $(THREADS) -o filtering -r assembly/rnabloom.transcripts.all.fa trimmed_reads/reads.txt &> logs/06-filtering.log; \
	fi


# 5. assembly
assembly: assembly/rnabloom.transcripts.all.fa

assembly/rnabloom.transcripts.all.fa assembly/ASSEMBLY.DONE: $(ROOT_DIR)/scripts/run-rnabloom.sh trimmed_reads/reads.txt $(LIB) $(END) $(ROOT_DIR)/scripts/get-runtime.sh trimmed_reads/READSLIST.DONE
	if [[ -n $(EMAIL) ]]; then \
		/usr/bin/time -pv $< -a $(EMAIL) -o assembly -t $(THREADS) trimmed_reads/reads.txt &> logs/05-assembly.log; \
	else \
		/usr/bin/time -pv $< -o assembly -t $(THREADS) trimmed_reads/reads.txt &> logs/05-assembly.log; \
	fi

# 4. make a reads list
readslist: trimmed_reads/reads.txt

trimmed_reads/reads.txt trimmed_reads/READSLIST.DONE: $(ROOT_DIR)/scripts/make-reads-list.sh sra/metadata.tsv $(TRIMMED_READS) $(LIB) $(END) $(ROOT_DIR)/scripts/get-runtime.sh trimmed_reads/TRIM.DONE
	/usr/bin/time -pv $< -d trimmed_reads sra/metadata.tsv &> logs/04-readslist.log

# 3. trim the reads
trim: $(TRIMMED_READS) trimmed_reads/TRIM.DONE

# trimmed_reads/%.paired.fastq.gz: $(ROOT_DIR)/scripts/trim-reads.sh $(ROOT_DIR)/scripts/run-fastp.sh raw_reads/%.fastq.gz $(ROOT_DIR)/scripts/get-runtime.sh raw_reads/READS.DONE
#	$< -i raw_reads -o trimmed_reads -t $(THREADS) &> logs/03-trimmed_reads.log

trimmed_reads/TRIM.DONE: $(ROOT_DIR)/scripts/trim-reads.sh $(ROOT_DIR)/scripts/run-fastp.sh $(RAW_READS) $(ROOT_DIR)/scripts/get-runtime.sh raw_reads/READS.DONE
	if [[ -n $(EMAIL) ]]; then \
		if [[ $(PARALLEL) == true ]]; then \
			/usr/bin/time -pv $< -a $(EMAIL) -i raw_reads -o trimmed_reads -t $(THREADS) -p &> logs/03-trimmed_reads.log; \
		else \
			/usr/bin/time -pv $< -a $(EMAIL) -i raw_reads -o trimmed_reads -t $(THREADS) &> logs/03-trimmed_reads.log; \
		fi; \
	else \
		if [[ $(PARALLEL) == true ]]; then \
			/usr/bin/time -pv $< -i raw_reads -o trimmed_reads -t $(THREADS) -p &> logs/03-trimmed_reads.log; \
		else \
			/usr/bin/time -pv $< -i raw_reads -o trimmed_reads -t $(THREADS) &> logs/03-trimmed_reads.log; \
		fi; \
	fi

# 2. download reads
reads: $(RAW_READS) raw_reads/READS.DONE

# Use the DONE file INSTEAD of wildcard
# raw_reads/%.fastq.gz: $(ROOT_DIR)/scripts/get-reads.sh $(ROOT_DIR)/scripts/get-accession.sh sra/runs.txt $(ROOT_DIR)/scripts/get-runtime.sh sra/RUNS.DONE sra/METADATA.DONE
#	$< -o raw_reads sra/runs.txt &> logs/02-raw_reads.log

raw_reads/READS.DONE: $(ROOT_DIR)/scripts/get-reads.sh $(ROOT_DIR)/scripts/get-accession.sh sra/runs.txt $(ROOT_DIR)/scripts/get-runtime.sh sra/RUNS.DONE sra/METADATA.DONE
	if [[ -n $(EMAIL) ]]; then \
		if [[ $(PARALLEL) == true ]]; then \
			/usr/bin/time -pv $< -a $(EMAIL) -o raw_reads -p sra/runs.txt &> logs/02-raw_reads.log; \
		else \
			/usr/bin/time -pv $< -a $(EMAIL) -o raw_reads sra/runs.txt &> logs/02-raw_reads.log; \
		fi; \
	else \
		if [[ $(PARALLEL) == true ]]; then \
			/usr/bin/time -pv $< -o raw_reads -p sra/runs.txt &> logs/02-raw_reads.log; \
		else \
			/usr/bin/time -pv $< -o raw_reads sra/runs.txt &> logs/02-raw_reads.log; \
		fi; \
	fi


# 1. get runs
accessions: sra/runs.txt sra/metadata.tsv

sra/runs.txt sra/metadata.tsv sra/RUNS.DONE sra/METADATA.DONE: $(ROOT_DIR)/scripts/get-runs.sh accessions.txt $(ROOT_DIR)/scripts/get-runtime.sh # $(ROOT_DIR)/CONFIG.DONE $(ROOT_DIR)/SETUP.DONE
	/usr/bin/time -pv $< -o sra accessions.txt &> logs/01-sra.log

clean:
	rm -f logs/* 2> /dev/null
	rm -rf sra raw_reads trimmed_reads assembly filtering translation homology cleavage amplify nohup.out
