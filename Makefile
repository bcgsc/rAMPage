SHELL = /usr/bin/env bash
PARALLEL = false
# MULTI = true
TSV = accessions.tsv
EMAIL = ""

FILTER_BY_CHARGE = true
FILTER_BY_LENGTH = true
FILTER_BY_SCORE = true

.PHONY = all clean config setup pipeline sable
	
all: sable

# run setup.sh with all the directories to create
setup: SETUP.DONE

check: $(TSV)
	if [[ ! -s $(TSV) ]]; then \
		echo "$(TSV) file does not exist or is empty." 1>&2; \
		exit 1; \
	fi

# check for CONFIG.DONE to make sure the configuration was done before
SETUP.DONE: scripts/setup.sh CONFIG.DONE $(TSV) check
	$< $(TSV)
 
pipeline: $(ROOT_DIR)/PIPELINE.DONE
	
$(ROOT_DIR)/PIPELINE.DONE: $(ROOT_DIR)/scripts/Makefile $(ROOT_DIR)/SETUP.DONE $(TSV) check
	while read sp; do \
		if [[ $(PARALLEL) == true ]]; then \
			if [[ $(EMAIL) == true ]]; then \
				/usr/bin/time -pv make -f $< -C $(ROOT_DIR)/$$sp PARALLEL=true EMAIL=$(EMAIL); \
			else \
				/usr/bin/time -pv make -f $< PARALLEL=true; \
			fi; \
		else \
			if [[ $(EMAIL) == true ]]; then \
				/usr/bin/time -pv make -f $< -C $(ROOT_DIR)/$$sp PARALLEL=false EMAIL=$(EMAIL); \
			else \
				/usr/bin/time -pv make -f $< -C $(ROOT_DIR)/$$sp PARALLEL=false; \
			fi; \
		fi; \
	done < <(cut -f1 -d$$'\t' $(TSV))
	
	if [[ $$(ls */*/*/amplify/AMPLIFY.DONE | wc -l) -ge $$(wc -l $(TSV) | cut -f1 -d' ') ]]; then \
		touch $(ROOT_DIR)/PIPELINE.DONE; \
	else \
		touch $(ROOT_DIR)/PIPELINE.FAIL; \
	fi

# combine the FASTA files from all the runs
combine: pipeline
	cat $(ROOT_DIR)/*/*/*/amplify/AMPlify_results.tsv > $(ROOT_DIR)/rr/AMPlify_results.tsv
	cat $(ROOT_DIR)/*/*/*/amplify/amps.charge.nr.faa > $(ROOT_DIR)/rr/amps.charge.faa
	cat $(ROOT_DIR)/*/*/*/amplify/amps.short.nr.faa > $(ROOT_DIR)/rr/amps.short.faa
	cat $(ROOT_DIR)/*/*/*/amplify/amps.conf.nr.faa > $(ROOT_DIR)/rr/amps.conf.faa
	cat $(ROOT_DIR)/*/*/*/amplify/amps.short.charge.nr.faa > $(ROOT_DIR)/rr/amps.short.charge.faa
	cat $(ROOT_DIR)/*/*/*/amplify/amps.conf.short.nr.faa > $(ROOT_DIR)/rr/amps.conf.short.faa
	cat $(ROOT_DIR)/*/*/*/amplify/amps.conf.charge.nr.faa > $(ROOT_DIR)/rr/amps.conf.charge.faa
	cat $(ROOT_DIR)/*/*/*/amplify/amps.conf.short.charge.nr.faa > $(ROOT_DIR)/rr/amps.conf.short.charge.faa
	cat $(ROOT_DIR)/*/*/*/amplify/amps.nr.faa > $(ROOT_DIR)/rr/amps.faa

# redundancy removal
rr: $(ROOT_DIR)/rr/RR.DONE

$(ROOT_DIR)/rr/RR.DONE: $(ROOT_DIR)/scripts/run-cdhit.sh combine
	mkdir -p rr
	/usr/bin/time -pv bash -c '\
 		$< -v $(ROOT_DIR)/rr/amps.charge.faa \
			&>> $(ROOT_DIR)/logs/11-redundancy_removal.log; \
 		$< $(ROOT_DIR)/rr/amps.short.faa \
			&>> $(ROOT_DIR)/logs/11-redundancy_removal.log; \
 		$< $(ROOT_DIR)/rr/amps.conf.faa \
			&>> $(ROOT_DIR)/logs/11-redundancy_removal.log; \
 		$< $(ROOT_DIR)/rr/amps.short.charge.faa \
			&>> $(ROOT_DIR)/logs/11-redundancy_removal.log; \
 		$< $(ROOT_DIR)/rr/amps.conf.short.faa \
			&>> $(ROOT_DIR)/logs/11-redundancy_removal.log; \
 		$< $(ROOT_DIR)/rr/amps.conf.charge.faa \
			&>> $(ROOT_DIR)/logs/11-redundancy_removal.log; \
 		$< $(ROOT_DIR)/rr/amps.conf.short.charge.faa \
			&>> $(ROOT_DIR)/logs/11-redundancy_removal.log; \
 		$< $(ROOT_DIR)/rr/amps.faa \
			&>> $(ROOT_DIR)/logs/11-redundancy_removal.log' \
 		&>> $(ROOT_DIR)/logs/11-redundancy_removal.log
	touch rr/RR.DONE

# run sable
sable: $(ROOT_DIR)/sable/SABLE_results.tsv $(ROOT_DIR)/sable/SABLE.DONE $(ROOT_DIR)/sable/OUT_SABLE_graph $(ROOT_DIR)/sable/SABLE_results.tsv

$(ROOT_DIR)/sable/SABLE.DONE $(ROOT_DIR)/sable/OUT_SABLE_graph $(ROOT_DIR)/sable/SABLE_results.tsv: $(ROOT_DIR)/scripts/run-sable.sh rr
	if [[ -n $(EMAIL) ]]; then \
		if [[ $(FILTER_BY_CHARGE) == true && $(FILTER_BY_LENGTH) == false && $(FILTER_BY_SCORE) == false ]]; then \
			$< -a $(EMAIL) -o sable $(ROOT_DIR)/rr/amps.charge.nr.faa \
				&> $(ROOT_DIR)/logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == false && $(FILTER_BY_LENGTH) == true && $(FILTER_BY_SCORE) == false ]]; then \
			$< -a $(EMAIL) -o sable $(ROOT_DIR)/rr/amps.short.nr.faa \
				&> $(ROOT_DIR)/logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == false && $(FILTER_BY_LENGTH) == false && $(FILTER_BY_SCORE) == true ]]; then \
			$< -a $(EMAIL) -o sable $(ROOT_DIR)/rr/amps.conf.nr.faa \
				&> $(ROOT_DIR)/logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == true && $(FILTER_BY_LENGTH) == true && $(FILTER_BY_SCORE) == false ]]; then \
			$< -a $(EMAIL) -o sable $(ROOT_DIR)/rr/amps.short.charge.nr.faa \
				&> $(ROOT_DIR)/logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == false && $(FILTER_BY_LENGTH) == true && $(FILTER_BY_SCORE) == true ]]; then \
			$< -a $(EMAIL) -o sable $(ROOT_DIR)/rr/amps.conf.short.nr.faa \
				&> $(ROOT_DIR)/logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == true && $(FILTER_BY_LENGTH) == false && $(FILTER_BY_SCORE) == true ]]; then \
			$< -a $(EMAIL) -o sable $(ROOT_DIR)/rr/amps.conf.charge.nr.faa \
				&> $(ROOT_DIR)/logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == true && $(FILTER_BY_LENGTH) == true && $(FILTER_BY_SCORE) == true ]]; then \
			$< -a $(EMAIL) -o sable $(ROOT_DIR)/rr/amps.conf.short.charge.nr.faa \
				&> $(ROOT_DIR)/logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == false && $(FILTER_BY_LENGTH) == false && $(FILTER_BY_SCORE) == false ]]; then \
			$< -a $(EMAIL) -o sable $(ROOT_DIR)/rr/amps.nr.faa \
				&> $(ROOT_DIR)/logs/12-sable.log; \
		fi; \
	else \
		if [[ $(FILTER_BY_CHARGE) == true && $(FILTER_BY_LENGTH) == false && $(FILTER_BY_SCORE) == false ]]; then \
			$< -o sable $(ROOT_DIR)/rr/amps.charge.nr.faa \
				&> $(ROOT_DIR)/logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == false && $(FILTER_BY_LENGTH) == true && $(FILTER_BY_SCORE) == false ]]; then \
			$< -o sable $(ROOT_DIR)/rr/amps.short.nr.faa \
				&> $(ROOT_DIR)/logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == false && $(FILTER_BY_LENGTH) == false && $(FILTER_BY_SCORE) == true ]]; then \
			$< -o sable $(ROOT_DIR)/rr/amps.conf.nr.faa \
				&> $(ROOT_DIR)/logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == true && $(FILTER_BY_LENGTH) == true && $(FILTER_BY_SCORE) == false ]]; then \
			$< -o sable $(ROOT_DIR)/rr/amps.short.charge.nr.faa \
				&> $(ROOT_DIR)/logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == false && $(FILTER_BY_LENGTH) == true && $(FILTER_BY_SCORE) == true ]]; then \
			$< -o sable $(ROOT_DIR)/rr/amps.conf.short.nr.faa \
				&> $(ROOT_DIR)/logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == true && $(FILTER_BY_LENGTH) == false && $(FILTER_BY_SCORE) == true ]]; then \
			$< -o sable $(ROOT_DIR)/rr/amps.conf.charge.nr.faa \
				&> $(ROOT_DIR)/logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == true && $(FILTER_BY_LENGTH) == true && $(FILTER_BY_SCORE) == true ]]; then \
			$< -o sable $(ROOT_DIR)/rr/amps.conf.short.charge.nr.faa \
				&> $(ROOT_DIR)/logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == false && $(FILTER_BY_LENGTH) == false && $(FILTER_BY_SCORE) == false ]]; then \
			$< -o sable $(ROOT_DIR)/rr/amps.nr.faa \
				&> $(ROOT_DIR)/logs/12-sable.log; \
		fi; \
	fi

clean:
	rm -f $(ROOT_DIR)/PIPELINE.DONE
	rm -f $(ROOT_DIR)/SETUP.DONE
	rm -rf $(ROOT_DIR)/rr
	rm -rf $(ROOT_DIR)/sable
	rm -f $(ROOT_DIR)/logs/*
	rm -f $(ROOT_DIR)/nohup.out
	rm -f nohup.out
	if [[ -f $(TSV) ]]; then \
		rm -rf $$(cut -f1 -d/ $(TSV) | sort -u); \
	fi
