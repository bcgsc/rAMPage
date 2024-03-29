SHELL := /usr/bin/env bash -ceuo pipefail
INPUT := input.txt
INPUT_PROCESSED := $(shell x='$(INPUT)'; echo "$${x/.txt/.processed.txt}")
ENTAPDIR := $(shell dirname $(RUN_ENTAP))
DATABASES := $(wildcard $(ENTAPDIR)/bin/*.dmnd)

SCORE := ""
LENGTH := ""
CHARGE := ""

REF_AMP := $(wildcard $(ROOT_DIR)/amp_seqs/amps.*.prot.combined.faa)
REF_AMP_PRECURSOR := $(wildcard $(ROOT_DIR)/amp_seqs/amps.*.prot.precursor.faa)
REF_AMP_MATURE := $(wildcard $(ROOT_DIR)/amp_seqs/amps.*.prot.mature.faa)

.PHONY: all amplify cleavage homology translation filtering assembly readslist trim reads accessions clean exonerate annotation

# final
all: sable/final_annotation.tsv

sable: sable/final_annotation.tsv

sable/final_annotation.tsv sable/SABLE_results.tsv sable/SABLE.DONE logs/13-sable.log &: $(ROOT_DIR)/scripts/run-sable.sh $(ROOT_DIR)/scripts/process-sable.sh exonerate/annotated.nr.faa exonerate/final_annotation.tsv DEPENDENCIES.CHECK exonerate/EXONERATE.DONE
	@if [[ -s logs/13-sable.log ]]; then \
		timestamp=$$(ls -l --time-style='+%Y%m%d_%H%M%S' logs/13-sable.log | awk '{print $$(NF-1)}'); \
		mv logs/13-sable.log logs/.13-sable-$${timestamp}.log; \
	fi
	@echo "STAGE 13: SABLE: $$(realpath logs)/13-sable.log: $$(date)" 1>&2
	@if [[ $(EMAIL) == true ]]; then \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< -a $(ADDRESS) -t $(THREADS) -o sable exonerate/annotated.nr.faa exonerate/final_annotation.tsv &> logs/13-sable.log; \
		else \
			$< -a $(ADDRESS) -t $(THREADS) -o sable exonerate/annotated.nr.faa exonerate/final_annotation.tsv &> logs/13-sable.log; \
		fi; \
	else \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< -t $(THREADS) -o sable exonerate/annotated.nr.faa exonerate/final_annotation.tsv &> logs/13-sable.log; \
		else \
			$< -t $(THREADS) -o sable exonerate/annotated.nr.faa exonerate/final_annotation.tsv &> logs/13-sable.log; \
		fi; \
	fi

# 12. exonerate
exonerate: exonerate/annotated.nr.faa
exonerate/EXONERATE.DONE exonerate/final_annotation.tsv exonerate/annotated.nr.faa logs/12-exonerate.log &: $(ROOT_DIR)/scripts/exonerate.sh $(REF_AMP_PRECURSOR) $(REF_AMP_MATURE) annotation/amps.final.annotated.faa annotation/final_annotations.final.tsv DEPENDENCIES.CHECK annotation/ANNOTATION.DONE
	@if [[ -s logs/12-exonerate.log ]]; then \
		timestamp=$$(ls -l --time-style='+%Y%m%d_%H%M%S' logs/12-exonerate.log | awk '{print $$(NF-1)}'); \
		mv logs/12-exonerate.log logs/.12-exonerate-$${timestamp}.log; \
	fi
	@echo "STAGE 12: EXONERATE: $$(realpath logs)/12-exonerate.log: $$(date)" 1>&2
	@if [[ $(EMAIL) == true ]]; then \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< -a $(ADDRESS) -o exonerate annotation/amps.final.annotated.faa annotation/final_annotations.final.tsv &> logs/12-exonerate.log; \
		else \
			$< -a $(ADDRESS) -o exonerate annotation/amps.final.annotated.faa annotation/final_annotations.final.tsv &> logs/12-exonerate.log; \
		fi; \
	else \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< -o exonerate annotation/amps.final.annotated.faa annotation/final_annotations.final.tsv &> logs/12-exonerate.log; \
		else \
			$< -o exonerate annotation/amps.final.annotated.faa annotation/final_annotations.final.tsv &> logs/12-exonerate.log; \
		fi; \
	fi
		
# 11. 
annotation: annotation/final_results/final_annotations.final.tsv
annotation/final_annotations.final.tsv annotation/final_results/final_annotations.final.tsv annotation/amps.final.annotated.faa annotation/ANNOTATION.DONE logs/11-annotation.log &: $(ROOT_DIR)/scripts/run-entap.sh amplify/amps.final.faa amplify/AMPlify_results.final.tsv $(DATABASES) $(ENTAPDIR)/CONFIG.DONE DEPENDENCIES.CHECK amplify/AMPLIFY.DONE
	@if [[ -s logs/11-annotation.log ]]; then \
		timestamp=$$(ls -l --time-style='+%Y%m%d_%H%M%S' logs/11-annotation.log | awk '{print $$(NF-1)}'); \
		mv logs/11-annotation.log logs/.11-annotation-$${timestamp}.log; \
	fi
	@echo "STAGE 11: ANNOTATION: $$(realpath logs)/11-annotation.log: $$(date)" 1>&2
	@if [[ $(EMAIL) == true ]]; then \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< -a $(ADDRESS) -t $(THREADS) -o annotation -i amplify/amps.final.faa -f amplify/AMPlify_results.final.tsv $(DATABASES) &> logs/11-annotation.log; \
		else \
			$< -a $(ADDRESS) -t $(THREADS) -o annotation -i amplify/amps.final.faa -f amplify/AMPlify_results.final.tsv $(DATABASES) &> logs/11-annotation.log; \
		fi; \
	else \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< -t $(THREADS) -o annotation -i amplify/amps.final.faa -f amplify/AMPlify_results.final.tsv $(DATABASES) &> logs/11-annotation.log; \
		else \
			$< -t $(THREADS) -o annotation -i amplify/amps.final.faa -f amplify/AMPlify_results.final.tsv $(DATABASES) &> logs/11-annotation.log; \
		fi; \
	fi

# 10. amplify
amplify: amplify/amps.final.faa

amplify/AMPlify_results.final.tsv amplify/amps.final.faa amplify/AMPLIFY.DONE logs/10-amplify.log &: $(ROOT_DIR)/scripts/run-amplify.sh cleavage/cleaved.mature.len.rmdup.nr.faa cleavage/CLEAVE.DONE DEPENDENCIES.CHECK
	@if [[ -s logs/10-amplify.log ]]; then \
		timestamp=$$(ls -l --time-style='+%Y%m%d_%H%M%S' logs/10-amplify.log | awk '{print $$(NF-1)}'); \
		mv logs/10-amplify.log logs/.10-amplify-$${timestamp}.log; \
	fi
	@echo "STAGE 10: AMPLIFY: $$(realpath logs)/10-amplify.log: $$(date)" 1>&2
	@if [[ $(EMAIL) == true ]]; then \
		if [[ $(BENCHMARK) == true ]]; then \
			if [[ $(FILTER_ONLY) == true ]]; then \
				if [[ -n "$(SCORE)" && -n "$(LENGTH)" && -n "$(CHARGE)" ]]; then \
					/usr/bin/time -pv $< -d -a $(ADDRESS) -o amplify $(SCORE) $(LENGTH) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" && -n "$(LENGTH)" ]]; then \
					/usr/bin/time -pv $< -d -a $(ADDRESS) -o amplify $(SCORE) $(LENGTH) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" && -n "$(CHARGE)" ]]; then \
					/usr/bin/time -pv $< -d -a $(ADDRESS) -o amplify $(SCORE) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(LENGTH)" && -n "$(CHARGE)" ]]; then \
					/usr/bin/time -pv $< -d -a $(ADDRESS) -o amplify $(LENGTH) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" ]]; then \
					/usr/bin/time -pv $< -d -a $(ADDRESS) -o amplify $(SCORE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(LENGTH)" ]]; then \
					/usr/bin/time -pv $< -d -a $(ADDRESS) -o amplify $(LENGTH) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(CHARGE)" ]]; then \
					/usr/bin/time -pv $< -d -a $(ADDRESS) -o amplify $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				else \
					/usr/bin/time -pv $< -d -a $(ADDRESS) -o amplify cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				fi; \
			else \
				if [[ -n "$(SCORE)" && -n "$(LENGTH)" && -n "$(CHARGE)" ]]; then \
					/usr/bin/time -pv $< -a $(ADDRESS) -o amplify $(SCORE) $(LENGTH) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" && -n "$(LENGTH)" ]]; then \
					/usr/bin/time -pv $< -a $(ADDRESS) -o amplify $(SCORE) $(LENGTH) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" && -n "$(CHARGE)" ]]; then \
					/usr/bin/time -pv $< -a $(ADDRESS) -o amplify $(SCORE) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(LENGTH)" && -n "$(CHARGE)" ]]; then \
					/usr/bin/time -pv $< -a $(ADDRESS) -o amplify $(LENGTH) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" ]]; then \
					/usr/bin/time -pv $< -a $(ADDRESS) -o amplify $(SCORE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(LENGTH)" ]]; then \
					/usr/bin/time -pv $< -a $(ADDRESS) -o amplify $(LENGTH) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(CHARGE)" ]]; then \
					/usr/bin/time -pv $< -a $(ADDRESS) -o amplify $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				else \
					/usr/bin/time -pv $< -a $(ADDRESS) -o amplify cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				fi; \
			fi; \
		else \
			if [[ $(FILTER_ONLY) == true ]]; then \
				if [[ -n "$(SCORE)" && -n "$(LENGTH)" && -n "$(CHARGE)" ]]; then \
					$< -d -a $(ADDRESS) -o amplify $(SCORE) $(LENGTH) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" && -n "$(LENGTH)" ]]; then \
					$< -d -a $(ADDRESS) -o amplify $(SCORE) $(LENGTH) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" && -n "$(CHARGE)" ]]; then \
					$< -d -a $(ADDRESS) -o amplify $(SCORE) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(LENGTH)" && -n "$(CHARGE)" ]]; then \
					$< -d -a $(ADDRESS) -o amplify $(LENGTH) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" ]]; then \
					$< -d -a $(ADDRESS) -o amplify $(SCORE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(LENGTH)" ]]; then \
					$< -d -a $(ADDRESS) -o amplify $(LENGTH) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(CHARGE)" ]]; then \
					$< -d -a $(ADDRESS) -o amplify $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				else \
					$< -d -a $(ADDRESS) -o amplify cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				fi; \
			else \
				if [[ -n "$(SCORE)" && -n "$(LENGTH)" && -n "$(CHARGE)" ]]; then \
					$< -a $(ADDRESS) -o amplify $(SCORE) $(LENGTH) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" && -n "$(LENGTH)" ]]; then \
					$< -a $(ADDRESS) -o amplify $(SCORE) $(LENGTH) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" && -n "$(CHARGE)" ]]; then \
					$< -a $(ADDRESS) -o amplify $(SCORE) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(LENGTH)" && -n "$(CHARGE)" ]]; then \
					$< -a $(ADDRESS) -o amplify $(LENGTH) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" ]]; then \
					$< -a $(ADDRESS) -o amplify $(SCORE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(LENGTH)" ]]; then \
					$< -a $(ADDRESS) -o amplify $(LENGTH) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(CHARGE)" ]]; then \
					$< -a $(ADDRESS) -o amplify $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				else \
					$< -a $(ADDRESS) -o amplify cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				fi; \
			fi; \
		fi; \
	else \
		if [[ $(BENCHMARK) == true ]]; then \
			if [[ $(FILTER_ONLY) == true ]]; then \
				if [[ -n "$(SCORE)" && -n "$(LENGTH)" && -n "$(CHARGE)" ]]; then \
					/usr/bin/time -pv $< -d -o amplify $(SCORE) $(LENGTH) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" && -n "$(LENGTH)" ]]; then \
					/usr/bin/time -pv $< -d -o amplify $(SCORE) $(LENGTH) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" && -n "$(CHARGE)" ]]; then \
					/usr/bin/time -pv $< -d -o amplify $(SCORE) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(LENGTH)" && -n "$(CHARGE)" ]]; then \
					/usr/bin/time -pv $< -d -o amplify $(LENGTH) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" ]]; then \
					/usr/bin/time -pv $< -d -o amplify $(SCORE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(LENGTH)" ]]; then \
					/usr/bin/time -pv $< -d -o amplify $(LENGTH) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(CHARGE)" ]]; then \
					/usr/bin/time -pv $< -d -o amplify $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				else \
					/usr/bin/time -pv $< -d -o amplify cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				fi; \
			else \
				if [[ -n "$(SCORE)" && -n "$(LENGTH)" && -n "$(CHARGE)" ]]; then \
					/usr/bin/time -pv $< -o amplify $(SCORE) $(LENGTH) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" && -n "$(LENGTH)" ]]; then \
					/usr/bin/time -pv $< -o amplify $(SCORE) $(LENGTH) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" && -n "$(CHARGE)" ]]; then \
					/usr/bin/time -pv $< -o amplify $(SCORE) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(LENGTH)" && -n "$(CHARGE)" ]]; then \
					/usr/bin/time -pv $< -o amplify $(LENGTH) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" ]]; then \
					/usr/bin/time -pv $< -o amplify $(SCORE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(LENGTH)" ]]; then \
					/usr/bin/time -pv $< -o amplify $(LENGTH) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(CHARGE)" ]]; then \
					/usr/bin/time -pv $< -o amplify $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				else \
					/usr/bin/time -pv $< -o amplify cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				fi; \
			fi; \
		else \
			if [[ $(FILTER_ONLY) == true ]]; then \
				if [[ -n "$(SCORE)" && -n "$(LENGTH)" && -n "$(CHARGE)" ]]; then \
					$< -d -o amplify $(SCORE) $(LENGTH) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" && -n "$(LENGTH)" ]]; then \
					$< -d -o amplify $(SCORE) $(LENGTH) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" && -n "$(CHARGE)" ]]; then \
					$< -d -o amplify $(SCORE) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(LENGTH)" && -n "$(CHARGE)" ]]; then \
					$< -d -o amplify $(LENGTH) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" ]]; then \
					$< -d -o amplify $(SCORE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(LENGTH)" ]]; then \
					$< -d -o amplify $(LENGTH) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(CHARGE)" ]]; then \
					$< -d -o amplify $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				else \
					$< -d -o amplify cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				fi; \
			else \
				if [[ -n "$(SCORE)" && -n "$(LENGTH)" && -n "$(CHARGE)" ]]; then \
					$< -o amplify $(SCORE) $(LENGTH) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" && -n "$(LENGTH)" ]]; then \
					$< -o amplify $(SCORE) $(LENGTH) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" && -n "$(CHARGE)" ]]; then \
					$< -o amplify $(SCORE) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(LENGTH)" && -n "$(CHARGE)" ]]; then \
					$< -o amplify $(LENGTH) $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(SCORE)" ]]; then \
					$< -o amplify $(SCORE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(LENGTH)" ]]; then \
					$< -o amplify $(LENGTH) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				elif [[ -n "$(CHARGE)" ]]; then \
					$< -o amplify $(CHARGE) cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				else \
					$< -o amplify cleavage/cleaved.mature.len.rmdup.nr.faa &> logs/10-amplify.log; \
				fi; \
			fi; \
		fi; \
	fi

# 9. cleavage
cleavage: cleavage/cleaved.mature.len.rmdup.nr.faa

cleavage/cleaved.mature.len.rmdup.nr.faa cleavage/CLEAVE.DONE logs/09-cleavage.log &: $(ROOT_DIR)/scripts/cleave.sh $(ROOT_DIR)/scripts/run-cdhit.sh homology/jackhmmer.nr.faa homology/HOMOLOGY.DONE DEPENDENCIES.CHECK
	@if [[ -s logs/09-cleavage.log ]]; then \
		timestamp=$$(ls -l --time-style='+%Y%m%d_%H%M%S' logs/09-cleavage.log | awk '{print $$(NF-1)}'); \
		mv logs/09-cleavage.log logs/.09-cleavage-$${timestamp}.log; \
	fi
	@echo "STAGE 09: PROPEPTIDE CLEAVAGE: $$(realpath logs)/09-cleavage.log: $$(date)" 1>&2
	@if [[ $(EMAIL) == true ]]; then \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< -a $(ADDRESS) -o cleavage homology/jackhmmer.nr.faa &> logs/09-cleavage.log; \
		else \
			$< -a $(ADDRESS) -o cleavage homology/jackhmmer.nr.faa &> logs/09-cleavage.log; \
		fi; \
	else \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< -o cleavage homology/jackhmmer.nr.faa &> logs/09-cleavage.log; \
		else \
			$< -o cleavage homology/jackhmmer.nr.faa &> logs/09-cleavage.log; \
		fi; \
	fi

# 8. homology search
homology: homology/jackhmmer.nr.faa

homology/jackhmmer.nr.faa homology/HOMOLOGY.DONE logs/08-homology.log &: $(ROOT_DIR)/scripts/run-jackhmmer.sh $(REF_AMP) translation/rnabloom.transcripts.filtered.transdecoder.faa $(ROOT_DIR)/scripts/run-cdhit.sh translation/TRANSLATION.DONE DEPENDENCIES.CHECK
	@if [[ -s logs/08-homology.log ]]; then \
		timestamp=$$(ls -l --time-style='+%Y%m%d_%H%M%S' logs/08-homology.log | awk '{print $$(NF-1)}'); \
		mv logs/08-homology.log logs/.08-homology-$${timestamp}.log; \
	fi
	@echo "STAGE 08: HOMOLOGY SEARCH: $$(realpath logs)/08-homology.log: $$(date)" 1>&2
	@if [[ $(EMAIL) == true ]]; then \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< -a $(ADDRESS) -o homology -t $(THREADS) -e $(EVALUE) translation/rnabloom.transcripts.filtered.transdecoder.faa &> logs/08-homology.log; \
		else \
			$< -a $(ADDRESS) -o homology -t $(THREADS) -e $(EVALUE) translation/rnabloom.transcripts.filtered.transdecoder.faa &> logs/08-homology.log; \
		fi; \
	else \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< -o homology -t $(THREADS) -e $(EVALUE) translation/rnabloom.transcripts.filtered.transdecoder.faa &> logs/08-homology.log; \
		else \
			$< -o homology -t $(THREADS) -e $(EVALUE) translation/rnabloom.transcripts.filtered.transdecoder.faa &> logs/08-homology.log; \
		fi; \
	fi

# 7. translation 
translation: translation/rnabloom.transcripts.filtered.transdecoder.faa

translation/rnabloom.transcripts.filtered.transdecoder.faa translation/TRANSLATION.DONE logs/07-translation.log &: $(ROOT_DIR)/scripts/translate.sh filtering/rnabloom.transcripts.filtered.fa filtering/FILTERING.DONE DEPENDENCIES.CHECK
	@if [[ -s logs/07-translation.log ]]; then \
		timestamp=$$(ls -l --time-style='+%Y%m%d_%H%M%S' logs/07-translation.log | awk '{print $$(NF-1)}'); \
		mv logs/07-translation.log logs/.07-translation-$${timestamp}.log; \
	fi
	@echo "STAGE 07: IN SILICO TRANSLATION: $$(realpath logs)/07-translation.log: $$(date)" 1>&2
	@if [[ $(EMAIL) == true ]]; then \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< -a $(ADDRESS) -o translation filtering/rnabloom.transcripts.filtered.fa &> logs/07-translation.log; \
		else \
			$< -a $(ADDRESS) -o translation filtering/rnabloom.transcripts.filtered.fa &> logs/07-translation.log; \
		fi; \
	else \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< -o translation filtering/rnabloom.transcripts.filtered.fa &> logs/07-translation.log; \
		else \
			$< -o translation filtering/rnabloom.transcripts.filtered.fa &> logs/07-translation.log; \
		fi; \
	fi

# 6. filter expression 
filtering: filtering/rnabloom.transcripts.filtered.fa

filtering/rnabloom.transcripts.filtered.fa filtering/FILTERING.DONE logs/06-filtering.log &: $(ROOT_DIR)/scripts/filter-expression.sh assembly/rnabloom.transcripts.all.fa trimmed_reads/readslist.txt assembly/ASSEMBLY.DONE DEPENDENCIES.CHECK
	@if [[ -s logs/06-filtering.log ]]; then \
		timestamp=$$(ls -l --time-style='+%Y%m%d_%H%M%S' logs/06-filtering.log | awk '{print $$(NF-1)}'); \
		mv logs/06-filtering.log logs/.06-filtering-$${timestamp}.log; \
	fi
	@echo "STAGE 06: EXPRESSION FILTERING: $$(realpath logs)/06-filtering.log: $$(date)" 1>&2
	@if [[ $(EMAIL) == true ]]; then \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< -a $(ADDRESS) -t $(THREADS) -o filtering -r assembly/rnabloom.transcripts.all.fa trimmed_reads/readslist.txt &> logs/06-filtering.log; \
		else \
			$< -a $(ADDRESS) -t $(THREADS) -o filtering -r assembly/rnabloom.transcripts.all.fa trimmed_reads/readslist.txt &> logs/06-filtering.log; \
		fi; \
	else \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< -t $(THREADS) -o filtering -r assembly/rnabloom.transcripts.all.fa trimmed_reads/readslist.txt &> logs/06-filtering.log; \
		else \
			$< -t $(THREADS) -o filtering -r assembly/rnabloom.transcripts.all.fa trimmed_reads/readslist.txt &> logs/06-filtering.log; \
		fi; \
	fi


# 5. assembly
assembly: assembly/rnabloom.transcripts.all.fa

assembly/rnabloom.transcripts.all.fa assembly/ASSEMBLY.DONE logs/05-assembly.log &: $(ROOT_DIR)/scripts/run-rnabloom.sh trimmed_reads/readslist.txt trimmed_reads/READSLIST.DONE DEPENDENCIES.CHECK
	@if [[ -s logs/05-assembly.log ]]; then \
		timestamp=$$(ls -l --time-style='+%Y%m%d_%H%M%S' logs/05-assembly.log | awk '{print $$(NF-1)}'); \
		mv logs/05-assembly.log logs/.05-assembly-$${timestamp}.log; \
	fi
	@echo "STAGE 05: TRANSCRIPTOME ASSEMBLY: $$(realpath logs)/05-assembly.log: $$(date)" 1>&2
	@if [[ $(EMAIL) == true ]]; then \
		if [[ $(BENCHMARK) == true ]]; then \
			if [[ $(RR) == true ]]; then \
				/usr/bin/time -pv $< -a $(ADDRESS) -o assembly -t $(THREADS) trimmed_reads/readslist.txt &> logs/05-assembly.log; \
			else \
				/usr/bin/time -pv $< -a $(ADDRESS) -o assembly -t $(THREADS) -R trimmed_reads/readslist.txt &> logs/05-assembly.log; \
			fi; \
		else \
			if [[ $(RR) == true ]]; then \
				$< -a $(ADDRESS) -o assembly -t $(THREADS) trimmed_reads/readslist.txt &> logs/05-assembly.log; \
			else \
				$< -a $(ADDRESS) -o assembly -t $(THREADS) -R trimmed_reads/readslist.txt &> logs/05-assembly.log; \
			fi; \
		fi; \
	else \
		if [[ $(BENCHMARK) == true ]]; then \
			if [[ $(RR) == true ]]; then \
				/usr/bin/time -pv $< -o assembly -t $(THREADS) trimmed_reads/readslist.txt &> logs/05-assembly.log; \
			else \
				/usr/bin/time -pv $< -o assembly -t $(THREADS) -R trimmed_reads/readslist.txt &> logs/05-assembly.log; \
			fi; \
		else \
			if [[ $(RR) == true ]]; then \
				$< -o assembly -t $(THREADS) trimmed_reads/readslist.txt &> logs/05-assembly.log; \
			else \
				$< -o assembly -t $(THREADS) -R trimmed_reads/readslist.txt &> logs/05-assembly.log; \
			fi; \
		fi; \
	fi

# 4. make a reads list
readslist: trimmed_reads/readslist.txt

trimmed_reads/readslist.txt trimmed_reads/READSLIST.DONE logs/04-readslist.log &: $(ROOT_DIR)/scripts/build-reads-list.sh $(INPUT_PROCESSED) trimmed_reads/TRIM.DONE DEPENDENCIES.CHECK
	@if [[ -s logs/04-readslist.log ]]; then \
		timestamp=$$(ls -l --time-style='+%Y%m%d_%H%M%S' logs/04-readslist.log | awk '{print $$(NF-1)}'); \
		mv logs/04-readslist.log logs/.04-readslist-$${timestamp}.log; \
	fi
	@echo "STAGE 04: MAKING A READS LIST: $$(realpath logs)/04-readslist.log: $$(date)" 1>&2
	@if [[ $(EMAIL) == true ]]; then \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< -a $(ADDRESS) -i trimmed_reads $(INPUT_PROCESSED) &> logs/04-readslist.log; \
		else \
			$< -a $(ADDRESS) -i trimmed_reads $(INPUT_PROCESSED) &> logs/04-readslist.log; \
		fi; \
	else \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< -i trimmed_reads $(INPUT_PROCESSED) &> logs/04-readslist.log; \
		else \
			$< -i trimmed_reads $(INPUT_PROCESSED) &> logs/04-readslist.log; \
		fi; \
	fi; \


# 3. trim the reads
trim: trimmed_reads/TRIM.DONE

trimmed_reads/TRIM.DONE logs/03-trimmed_reads.log &: $(ROOT_DIR)/scripts/trim-reads.sh $(ROOT_DIR)/scripts/run-fastp.sh $(INPUT_PROCESSED) DEPENDENCIES.CHECK raw_reads/READS.DONE
	@if [[ -s logs/03-trimmed_reads.log ]]; then \
		timestamp=$$(ls -l --time-style='+%Y%m%d_%H%M%S' logs/03-trimmed_reads.log | awk '{print $$(NF-1)}'); \
		mv logs/03-trimmed_reads.log logs/.03-trimmed_reads-$${timestamp}.log; \
	fi
	@echo "STAGE 03: TRIMMING READS: $$(realpath logs)/03-trimmed_reads.log: $$(date)" 1>&2
	@if [[ $(EMAIL) == true ]]; then \
		if [[ $(PARALLEL) == true ]]; then \
			if [[ $(BENCHMARK) == true ]]; then \
				/usr/bin/time -pv $< -a $(ADDRESS) -i raw_reads -o trimmed_reads -t $(THREADS) -p $(INPUT_PROCESSED) &> logs/03-trimmed_reads.log; \
			else \
				$< -a $(ADDRESS) -i raw_reads -o trimmed_reads -t $(THREADS) -p $(INPUT_PROCESSED) &> logs/03-trimmed_reads.log; \
			fi; \
		else \
			if [[ $(BENCHMARK) == true ]]; then \
				/usr/bin/time -pv $< -a $(ADDRESS) -i raw_reads -o trimmed_reads -t $(THREADS) $(INPUT_PROCESSED) &> logs/03-trimmed_reads.log; \
			else \
				$< -a $(ADDRESS) -i raw_reads -o trimmed_reads -t $(THREADS) $(INPUT_PROCESSED) &> logs/03-trimmed_reads.log; \
			fi; \
		fi; \
	else \
		if [[ $(PARALLEL) == true ]]; then \
			if [[ $(BENCHMARK) == true ]]; then \
				/usr/bin/time -pv $< -i raw_reads -o trimmed_reads -t $(THREADS) -p $(INPUT_PROCESSED) &> logs/03-trimmed_reads.log; \
			else \
				$< -i raw_reads -o trimmed_reads -t $(THREADS) -p $(INPUT_PROCESSED) &> logs/03-trimmed_reads.log; \
			fi; \
		else \
			if [[ $(BENCHMARK) == true ]]; then \
				/usr/bin/time -pv $< -i raw_reads -o trimmed_reads -t $(THREADS) $(INPUT_PROCESSED) &> logs/03-trimmed_reads.log; \
			else \
				$< -i raw_reads -o trimmed_reads -t $(THREADS) $(INPUT_PROCESSED) &> logs/03-trimmed_reads.log; \
			fi; \
		fi; \
	fi

reads: raw_reads/READS.DONE

raw_reads/READS.DONE $(INPUT_PROCESSED) logs/02-raw_reads.log &: $(ROOT_DIR)/scripts/check-reads.sh $(INPUT) DEPENDENCIES.CHECK
	@if [[ -s logs/02-raw_reads.log ]]; then \
		timestamp=$$(ls -l --time-style='+%Y%m%d_%H%M%S' logs/02-raw_reads.log | awk '{print $$(NF-1)}'); \
		mv logs/02-raw_reads.log logs/.02-raw_reads-$${timestamp}.log; \
	fi
	@echo "STAGE 02: GETTING READS: $$(realpath logs)/02-raw_reads.log: $$(date)" 1>&2
	@if [[ $(EMAIL) == true ]]; then \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< -a $(ADDRESS) $(INPUT) &> logs/02-raw_reads.log; \
		else \
			$< -a $(ADDRESS) $(INPUT) &> logs/02-raw_reads.log; \
		fi; \
	else \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv $< $(INPUT) &> logs/02-raw_reads.log; \
		else \
			$< $(INPUT) &> logs/02-raw_reads.log; \
		fi; \
	fi

check: DEPENDENCIES.CHECK
DEPENDENCIES.CHECK logs/01-check.log &: $(ROOT_DIR)/scripts/check-dependencies.sh $(ROOT_DIR)/CONFIG.DONE
	@mkdir -p logs
	@if [[ -s logs/01-check.log ]]; then \
		timestamp=$$(ls -l --time-style='+%Y%m%d_%H%M%S' logs/01-check.log | awk '{print $$(NF-1)}'); \
		mv logs/01-check.log logs/.01-check-$${timestamp}.log; \
	fi
	@echo "STAGE 01: CHECK DEPENDENCIES: $$(realpath logs)/01-check.log: $$(date)" 1>&2
	@if [[ $(EMAIL) == true ]]; then \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv --append -o logs/01-check.log $< -a $(ADDRESS) 2>> logs/01-check.log | tee -a logs/01-check.log 1>&2; \
		else \
			$< -a $(ADDRESS) 2>> logs/01-check.log | tee -a logs/01-check.log 1>&2; \
		fi; \
	else \
		if [[ $(BENCHMARK) == true ]]; then \
			/usr/bin/time -pv --append -o logs/01-check.log $< 2>> logs/01-check.log | tee -a logs/01-check.log 1>&2; \
		else \
			$< 2>> logs/01-check.log | tee -a logs/01-check.log 1>&2; \
		fi; \
	fi

clean:
	@rm -f DEPENDENCIES.CHECK $(INPUT_PROCESSED) nohup.out raw_reads/READS.DONE RAMPAGE.DONE env.txt
	@rm -rf trimmed_reads assembly filtering translation homology cleavage amplify sable exonerate annotation logs