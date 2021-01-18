SHELL := /usr/bin/env bash -ceuo pipefail
THREADS := 48
INPUT := input.txt
INPUT_PROCESSED := $(shell x='$(INPUT)'; echo "$${x/.txt/.processed.txt}")
PARALLEL := false
EMAIL := ""
VERBOSE := true
ENTAPDIR := $(shell dirname $(RUN_ENTAP))
DATABASES := $(wildcard $(ENTAPDIR)/bin/*.dmnd)

REF_AMP := $(wildcard $(ROOT_DIR)/amp_seqs/amps.*.prot.combined.faa)

.PHONY: all amplify cleavage homology translation filtering assembly readslist trim reads accessions clean exonerate annotation

# final
all: sable/SABLE_results.tsv

sable: sable/SABLE_results.tsv

sable/SABLE_results.tsv sable/SABLE.DONE logs/13-sable.log &: $(ROOT_DIR)/scripts/run-sable.sh $(ROOT_DIR)/scripts/process-sable.sh exonerate/labelled.amps.exonerate.nr.faa amplify/AMPlify_results.final.tsv DEPENDENCIES.CHECK exonerate/EXONERATE.DONE amplify/AMPLIFY.DONE
	@echo "STAGE 13: SABLE: $$(realpath logs)/13-sable.log: $$(date)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -a $(EMAIL) -o sable exonerate/labelled.amps.exonerate.nr.faa amplify/AMPlify_results.final.tsv &> logs/13-sable.log; \
		else \
			$< -a $(EMAIL) -o sable exonerate/labelled.amps.exonerate.nr.faa amplify/AMPlify_results.final.tsv &> logs/13-sable.log; \
		fi; \
	else \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -o sable exonerate/labelled.amps.exonerate.nr.faa amplify/AMPlify_results.final.tsv &> logs/13-sable.log; \
		else \
			$< -o sable exonerate/labelled.amps.exonerate.nr.faa amplify/AMPlify_results.final.tsv &> logs/13-sable.log; \
		fi; \
	fi

# 12. exonerate
exonerate: exonerate/labelled.amps.exonerate.nr.faa
exonerate/EXONERATE.DONE exonerate/labelled.amps.exonerate.nr.faa logs/12-exonerate.log &: $(ROOT_DIR)/scripts/exonerate.sh $(REF_AMP) annotation/amps.final.annotated.faa annotation/final_annotations.final.tsv DEPENDENCIES.CHECK annotation/ANNOTATION.DONE
	@echo "STAGE 12: EXONERATE: $$(realpath logs)/12-exonerate.log: $$(date)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -a $(EMAIL) -o exonerate annotation/amps.final.annotated.faa annotation/final_annotations.final.tsv &> logs/12-exonerate.log; \
		else \
			$< -a $(EMAIL) -o exonerate annotation/amps.final.annotated.faa annotation/final_annotations.final.tsv &> logs/12-exonerate.log; \
		fi; \
	else \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -o exonerate annotation/amps.final.annotated.faa annotation/final_annotations.final.tsv &> logs/12-exonerate.log; \
		else \
			$< -o exonerate annotation/amps.final.annotated.faa annotation/final_annotations.final.tsv &> logs/12-exonerate.log; \
		fi; \
	fi
		
# 11. 
annotation: annotation/final_results/final_annotations.final.tsv
annotation/final_annotations.final.tsv annotation/final_results/final_annotations.final.tsv annotation/amps.final.annotated.faa annotation/ANNOTATION.DONE logs/11-annotation.log &: $(ROOT_DIR)/scripts/run-entap.sh amplify/amps.final.faa $(DATABASES) $(ENTAPDIR)/CONFIG.DONE DEPENDENCIES.CHECK amplify/AMPLIFY.DONE
	@echo "STAGE 11: ANNOTATION: $$(realpath logs)/11-annotation.log: $$(date)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -a $(EMAIL) -o annotation -i amplify/amps.final.faa $(DATABASES) &> logs/11-annotation.log; \
		else \
			$< -a $(EMAIL) -o annotation -i amplify/amps.final.faa $(DATABASES) &> logs/11-annotation.log; \
		fi; \
	else \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -o annotation -i amplify/amps.final.faa $(DATABASES) &> logs/11-annotation.log; \
		else \
			$< -o annotation -i amplify/amps.final.faa $(DATABASES) &> logs/11-annotation.log; \
		fi; \
	fi


# 10. amplify
amplify: amplify/amps.final.faa

amplify/AMPlify_results.final.tsv amplify/amps.final.faa amplify/AMPLIFY.DONE logs/10-amplify.log &: $(ROOT_DIR)/scripts/run-amplify.sh cleavage/cleaved.mature.len.faa $(ROOT_DIR)/scripts/run-cdhit.sh cleavage/CLEAVE.DONE DEPENDENCIES.CHECK
	@echo "STAGE 10: AMPLIFY: $$(realpath logs)/10-amplify.log: $$(date)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -a $(EMAIL) -o amplify cleavage/cleaved.mature.len.faa &> logs/10-amplify.log; \
		else \
			$< -a $(EMAIL) -o amplify cleavage/cleaved.mature.len.faa &> logs/10-amplify.log; \
		fi; \
	else \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -o amplify cleavage/cleaved.mature.len.faa &> logs/10-amplify.log; \
		else \
			$< -o amplify cleavage/cleaved.mature.len.faa &> logs/10-amplify.log; \
		fi; \
	fi

# 9. cleavage
cleavage: cleavage/cleaved.mature.len.faa

cleavage/cleaved.mature.len.faa cleavage/CLEAVE.DONE logs/09-cleavage.log &: $(ROOT_DIR)/scripts/cleave.sh homology/jackhmmer.nr.faa homology/HOMOLOGY.DONE DEPENDENCIES.CHECK
	@echo "STAGE 09: PROPEPTIDE CLEAVAGE: $$(realpath logs)/09-cleavage.log: $$(date)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -a $(EMAIL) -o cleavage homology/jackhmmer.nr.faa &> logs/09-cleavage.log; \
		else \
			$< -a $(EMAIL) -o cleavage homology/jackhmmer.nr.faa &> logs/09-cleavage.log; \
		fi; \
	else \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -o cleavage homology/jackhmmer.nr.faa &> logs/09-cleavage.log; \
		else \
			$< -o cleavage homology/jackhmmer.nr.faa &> logs/09-cleavage.log; \
		fi; \
	fi

# 8. homology search
homology: homology/jackhmmer.nr.faa

homology/jackhmmer.nr.faa homology/HOMOLOGY.DONE logs/08-homology.log &: $(ROOT_DIR)/scripts/run-jackhmmer.sh $(REF_AMP) translation/rnabloom.transcripts.filtered.transdecoder.faa $(ROOT_DIR)/scripts/run-cdhit.sh translation/TRANSLATION.DONE DEPENDENCIES.CHECK
	@echo "STAGE 08: HOMOLOGY SEARCH: $$(realpath logs)/08-homology.log: $$(date)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -a $(EMAIL) -o homology -t $(THREADS) translation/rnabloom.transcripts.filtered.transdecoder.faa &> logs/08-homology.log; \
		else \
			$< -a $(EMAIL) -o homology -t $(THREADS) translation/rnabloom.transcripts.filtered.transdecoder.faa &> logs/08-homology.log; \
		fi; \
	else \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -o homology -t $(THREADS) translation/rnabloom.transcripts.filtered.transdecoder.faa &> logs/08-homology.log; \
		else \
			$< -o homology -t $(THREADS) translation/rnabloom.transcripts.filtered.transdecoder.faa &> logs/08-homology.log; \
		fi; \
	fi

# 7. translation 
translation: translation/rnabloom.transcripts.filtered.transdecoder.faa

translation/rnabloom.transcripts.filtered.transdecoder.faa translation/TRANSLATION.DONE logs/07-translation.log &: $(ROOT_DIR)/scripts/translate.sh filtering/rnabloom.transcripts.filtered.fa filtering/FILTERING.DONE DEPENDENCIES.CHECK
	@echo "STAGE 07: IN SILICO TRANSLATION: $$(realpath logs)/07-translation.log: $$(date)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -a $(EMAIL) -o translation filtering/rnabloom.transcripts.filtered.fa &> logs/07-translation.log; \
		else \
			$< -a $(EMAIL) -o translation filtering/rnabloom.transcripts.filtered.fa &> logs/07-translation.log; \
		fi; \
	else \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -o translation filtering/rnabloom.transcripts.filtered.fa &> logs/07-translation.log; \
		else \
			$< -o translation filtering/rnabloom.transcripts.filtered.fa &> logs/07-translation.log; \
		fi; \
	fi

# 6. filter expression 
filtering: filtering/rnabloom.transcripts.filtered.fa

filtering/rnabloom.transcripts.filtered.fa filtering/FILTERING.DONE logs/06-filtering.log &: $(ROOT_DIR)/scripts/filter-expression.sh assembly/rnabloom.transcripts.all.fa trimmed_reads/readslist.txt assembly/ASSEMBLY.DONE DEPENDENCIES.CHECK
	@echo "STAGE 06: EXPRESSION FILTERING: $$(realpath logs)/06-filtering.log: $$(date)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -a $(EMAIL) -t $(THREADS) -o filtering -r assembly/rnabloom.transcripts.all.fa trimmed_reads/readslist.txt &> logs/06-filtering.log; \
		else \
			$< -a $(EMAIL) -t $(THREADS) -o filtering -r assembly/rnabloom.transcripts.all.fa trimmed_reads/readslist.txt &> logs/06-filtering.log; \
		fi; \
	else \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -t $(THREADS) -o filtering -r assembly/rnabloom.transcripts.all.fa trimmed_reads/readslist.txt &> logs/06-filtering.log; \
		else \
			$< -t $(THREADS) -o filtering -r assembly/rnabloom.transcripts.all.fa trimmed_reads/readslist.txt &> logs/06-filtering.log; \
		fi; \
	fi


# 5. assembly
assembly: assembly/rnabloom.transcripts.all.fa

assembly/rnabloom.transcripts.all.fa assembly/ASSEMBLY.DONE logs/05-assembly.log &: $(ROOT_DIR)/scripts/run-rnabloom.sh trimmed_reads/readslist.txt trimmed_reads/READSLIST.DONE DEPENDENCIES.CHECK
	@echo "STAGE 05: TRANSCRIPTOME ASSEMBLY: $$(realpath logs)/05-assembly.log: $$(date)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -a $(EMAIL) -o assembly -t $(THREADS) trimmed_reads/readslist.txt &> logs/05-assembly.log; \
		else \
			$< -a $(EMAIL) -o assembly -t $(THREADS) trimmed_reads/readslist.txt &> logs/05-assembly.log; \
		fi; \
	else \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -o assembly -t $(THREADS) trimmed_reads/readslist.txt &> logs/05-assembly.log; \
		else \
			$< -o assembly -t $(THREADS) trimmed_reads/readslist.txt &> logs/05-assembly.log; \
		fi; \
	fi

# 4. make a reads list
readslist: trimmed_reads/readslist.txt

trimmed_reads/readslist.txt trimmed_reads/READSLIST.DONE logs/04-readslist.log &: $(ROOT_DIR)/scripts/build-reads-list.sh $(INPUT_PROCESSED) trimmed_reads/TRIM.DONE DEPENDENCIES.CHECK
	@echo "STAGE 04: MAKING A READS LIST: $$(realpath logs)/04-readslist.log: $$(date)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -a $(EMAIL) -i trimmed_reads $(INPUT_PROCESSED) &> logs/04-readslist.log; \
		else \
			$< -a $(EMAIL) -i trimmed_reads $(INPUT_PROCESSED) &> logs/04-readslist.log; \
		fi; \
	else \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -i trimmed_reads $(INPUT_PROCESSED) &> logs/04-readslist.log; \
		else \
			$< -i trimmed_reads $(INPUT_PROCESSED) &> logs/04-readslist.log; \
		fi; \
	fi; \


# 3. trim the reads
trim: trimmed_reads/TRIM.DONE

trimmed_reads/TRIM.DONE logs/03-trimmed_reads.log &: $(ROOT_DIR)/scripts/trim-reads.sh $(ROOT_DIR)/scripts/run-fastp.sh $(INPUT_PROCESSED) DEPENDENCIES.CHECK raw_reads/READS.DONE
	@echo "STAGE 03: TRIMMING READS: $$(realpath logs)/03-trimmed_reads.log: $$(date)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		if [[ $(PARALLEL) == true ]]; then \
			if [[ $(VERBOSE) == true ]]; then \
				/usr/bin/time -pv $< -a $(EMAIL) -i raw_reads -o trimmed_reads -t $(THREADS) -p $(INPUT_PROCESSED) &> logs/03-trimmed_reads.log; \
			else \
				$< -a $(EMAIL) -i raw_reads -o trimmed_reads -t $(THREADS) -p $(INPUT_PROCESSED) &> logs/03-trimmed_reads.log; \
			fi; \
		else \
			if [[ $(VERBOSE) == true ]]; then \
				/usr/bin/time -pv $< -a $(EMAIL) -i raw_reads -o trimmed_reads -t $(THREADS) $(INPUT_PROCESSED) &> logs/03-trimmed_reads.log; \
			else \
				$< -a $(EMAIL) -i raw_reads -o trimmed_reads -t $(THREADS) $(INPUT_PROCESSED) &> logs/03-trimmed_reads.log; \
			fi; \
		fi; \
	else \
		if [[ $(PARALLEL) == true ]]; then \
			if [[ $(VERBOSE) == true ]]; then \
				/usr/bin/time -pv $< -i raw_reads -o trimmed_reads -t $(THREADS) -p $(INPUT_PROCESSED) &> logs/03-trimmed_reads.log; \
			else \
				$< -i raw_reads -o trimmed_reads -t $(THREADS) -p $(INPUT_PROCESSED) &> logs/03-trimmed_reads.log; \
			fi; \
		else \
			if [[ $(VERBOSE) == true ]]; then \
				/usr/bin/time -pv $< -i raw_reads -o trimmed_reads -t $(THREADS) $(INPUT_PROCESSED) &> logs/03-trimmed_reads.log; \
			else \
				$< -i raw_reads -o trimmed_reads -t $(THREADS) $(INPUT_PROCESSED) &> logs/03-trimmed_reads.log; \
			fi; \
		fi; \
	fi

reads: raw_reads/READS.DONE

raw_reads/READS.DONE $(INPUT_PROCESSED) logs/02-raw_reads.log &: $(ROOT_DIR)/scripts/check-reads.sh $(INPUT) DEPENDENCIES.CHECK
	@echo "STAGE 02: GETTING READS: $$(realpath logs)/02-raw_reads.log: $$(date)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< -a $(EMAIL) $(INPUT) &> logs/02-raw_reads.log; \
		else \
			$< -a $(EMAIL) $(INPUT) &> logs/02-raw_reads.log; \
		fi; \
	else \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv $< $(INPUT) &> logs/02-raw_reads.log; \
		else \
			$< $(INPUT) &> logs/02-raw_reads.log; \
		fi; \
	fi

check: DEPENDENCIES.CHECK
DEPENDENCIES.CHECK logs/01-check.log &: $(ROOT_DIR)/scripts/check-dependencies.sh $(ROOT_DIR)/CONFIG.DONE
	@mkdir -p logs
	@rm -f logs/01-check.log
	@echo "STAGE 01: CHECK DEPENDENCIES: $$(realpath logs)/01-check.log: $$(date)" 1>&2
	@if [[ -n $(EMAIL) ]]; then \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv --append -o logs/01-check.log $< -a $(EMAIL) 2>> logs/01-check.log | tee -a logs/01-check.log 1>&2; \
		else \
			$< -a $(EMAIL) 2>> logs/01-check.log | tee -a logs/01-check.log 1>&2; \
		fi; \
	else \
		if [[ $(VERBOSE) == true ]]; then \
			/usr/bin/time -pv --append -o logs/01-check.log $< 2>> logs/01-check.log | tee -a logs/01-check.log 1>&2; \
		else \
			$< 2>> logs/01-check.log | tee -a logs/01-check.log 1>&2; \
		fi; \
	fi

clean:
	@rm -rf DEPENDENCIES.CHECK $(INPUT_PROCESSED) trimmed_reads assembly filtering translation homology cleavage amplify nohup.out logs sable raw_reads/READS.DONE RAMPAGE.DONE exonerate annotation
