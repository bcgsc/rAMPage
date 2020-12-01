SHELL := /usr/bin/env bash -euo pipefail -c
THREADS = 48
INPUT = input.txt
PARALLEL = false
EMAIL = ""

END := $(wildcard *.END)
LIB := $(wildcard *.LIB)
TAXON_CLASS := $(wildcard *.CLASS)
REF_AMP := $(wildcard $(ROOT_DIR)/amp_seqs/amps.*.prot.combined.faa)
RAW_READS := $(wildcard raw_reads/*.fastq.gz)
TRIMMED_READS := $(wildcard trimmed_reads/*.paired.fastq.gz)

.PHONY: all amplify cleavage homology translation filtering assembly readslist trim reads accessions check clean
# final
all: amplify

# 10. amplify
amplify: amplify/amps.conf.short.charge.nr.faa

amplify/amps.conf.short.charge.nr.faa amplify/AMPLIFY.DONE &: $(ROOT_DIR)/scripts/run-amplify.sh cleavage/cleaved.mature.len.faa $(ROOT_DIR)/scripts/get-runtime.sh $(ROOT_DIR)/scripts/run-cdhit.sh cleavage/CLEAVE.DONE
	@echo "STAGE 10: AMPLIFY: $$(realpath logs/10-amplify.log)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		/usr/bin/time -pv $< -a $(EMAIL) -o amplify cleavage/cleaved.mature.len.faa &> logs/10-amplify.log; \
	else \
		/usr/bin/time -pv $< -o amplify cleavage/cleaved.mature.len.faa; \
	fi

# 9. cleavage
cleavage: cleavage/cleaved.mature.len.faa

cleavage/cleaved.mature.len.faa cleavage/CLEAVE.DONE &: $(ROOT_DIR)/scripts/cleave.sh homology/jackhmmer.nr.faa $(ROOT_DIR)/scripts/get-runtime.sh homology/HOMOLOGY.DONE
	@echo "STAGE 09: PROPEPTIDE CLEAVAGE: $$(realpath logs/09-cleavage.log)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		/usr/bin/time -pv $< -a $(EMAIL) -o cleavage homology/jackhmmer.nr.faa &> logs/09-cleavage.log; \
	else \
		/usr/bin/time -pv $< -o cleavage homology/jackhmmer.nr.faa &> logs/09-cleavage.log; \
	fi

# 8. homology search
homology: homology/jackhmmer.nr.faa

homology/jackhmmer.nr.faa homology/HOMOLOGY.DONE &: $(ROOT_DIR)/scripts/run-jackhmmer.sh $(REF_AMP) translation/rnabloom.transcripts.filtered.transdecoder.faa $(ROOT_DIR)/scripts/get-runtime.sh $(TAXON_CLASS) $(ROOT_DIR)/scripts/run-cdhit.sh translation/TRANSLATION.DONE
	@echo "STAGE 08: HOMOLOGY SEARCH: $$(realpath translation/rnabloom.transcripts.filtered.transdecoder.faa)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		/usr/bin/time -pv $< -a $(EMAIL) -o homology -t $(THREADS) translation/rnabloom.transcripts.filtered.transdecoder.faa &> logs/08-homology.log; \
	else \
		/usr/bin/time -pv $< -o homology -t $(THREADS) translation/rnabloom.transcripts.filtered.transdecoder.faa &> logs/08-homology.log; \
	fi

# 7. translation 
translation: translation/rnabloom.transcripts.filtered.transdecoder.faa

translation/rnabloom.transcripts.filtered.transdecoder.faa translation/TRANSLATION.DONE &: $(ROOT_DIR)/scripts/translate.sh filtering/rnabloom.transcripts.filtered.fa $(ROOT_DIR)/scripts/get-runtime.sh filtering/FILTER.DONE
	@echo "STAGE 07: IN SILICO TRANSLATION: $$(realpath logs/07-translation.log)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		/usr/bin/time -pv $< -a $(EMAIL) -o translation filtering/rnabloom.transcripts.filtered.fa &> logs/07-translation.log; \
	else \
		/usr/bin/time -pv $< -o translation filtering/rnabloom.transcripts.filtered.fa &> logs/07-translation.log; \
	fi

# 6. filter expression 
filtering: filtering/rnabloom.transcripts.filtered.fa

filtering/rnabloom.transcripts.filtered.fa filtering/FILTER.DONE &: $(ROOT_DIR)/scripts/filter-expression.sh assembly/rnabloom.transcripts.all.fa trimmed_reads/readslist.txt $(ROOT_DIR)/scripts/get-runtime.sh assembly/ASSEMBLY.DONE
	@echo "STAGE 06: EXPRESSION FILTERING: $$(realpath logs/06-filtering.log)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		/usr/bin/time -pv $< -a $(EMAIL) -t $(THREADS) -o filtering -r assembly/rnabloom.transcripts.all.fa trimmed_reads/readslist.txt &> logs/06-filtering.log; \
	else \
		/usr/bin/time -pv $< -t $(THREADS) -o filtering -r assembly/rnabloom.transcripts.all.fa trimmed_reads/readslist.txt &> logs/06-filtering.log; \
	fi


# 5. assembly
assembly: assembly/rnabloom.transcripts.all.fa

assembly/rnabloom.transcripts.all.fa assembly/ASSEMBLY.DONE &: $(ROOT_DIR)/scripts/run-rnabloom.sh trimmed_reads/readslist.txt $(LIB) $(END) $(ROOT_DIR)/scripts/get-runtime.sh trimmed_reads/READSLIST.DONE
	@echo "STAGE 05: TRANSCRIPTOME ASSEMBLY: $$(realpath logs/05-assembly.log)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		/usr/bin/time -pv $< -a $(EMAIL) -o assembly -t $(THREADS) trimmed_reads/readslist.txt &> logs/05-assembly.log; \
	else \
		/usr/bin/time -pv $< -o assembly -t $(THREADS) trimmed_reads/readslist.txt &> logs/05-assembly.log; \
	fi

# 4. make a reads list
readslist: trimmed_reads/readslist.txt

trimmed_reads/readslist.txt trimmed_reads/READSLIST.DONE &: $(ROOT_DIR)/scripts/build-reads-list.sh $(INPUT) $(TRIMMED_READS) $(LIB) $(END) trimmed_reads/TRIM.DONE
	@echo "STAGE 04: MAKING A READS LIST: $$(realpath logs/04-readslist.log)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		/usr/bin/time -pv $< -a $(EMAIL) -i trimmed_reads $(INPUT) &> logs/04-readslist.log; \
	else \
		/usr/bin/time -pv $< -i trimmed_reads $(INPUT) &> logs/04-readslist.log; \
	fi


# 3. trim the reads
trim: trimmed_reads/TRIM.DONE

trimmed_reads/TRIM.DONE input.trimmed.txt &: $(ROOT_DIR)/scripts/trim-reads.sh $(ROOT_DIR)/scripts/run-fastp.sh $(RAW_READS) $(ROOT_DIR)/scripts/get-runtime.sh raw_reads/READS.DONE
	@echo "STAGE 03: TRIMMING READS: $$(realpath logs/03-trimmed_reads.log)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
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

reads: raw_reads/READS.DONE

raw_reads/READS.DONE input.raw.txt &: $(ROOT_DIR)/scripts/check-reads.sh $(INPUT) check
	@echo "STAGE 02: GETTING READS: $$(realpath logs/02-raw_reads.log)" 1>&2
	@$< $(INPUT) &> logs/02-raw_reads.log

check: $(ROOT_DIR)/scripts/check-dependencies.sh $(ROOT_DIR)/CONFIG.DONE
	@echo "STAGE 01: CHECK DEPENDENCIES $$(realpath logs/01-check.log)" 1>&2
	@$< | tee logs/01-check.log 1>&2

clean:
	@rm -f logs/* 2> /dev/null
	@rm -rf $(END) $(LIB) $(TAXON_CLASS) trimmed_reads assembly filtering translation homology cleavage amplify nohup.out