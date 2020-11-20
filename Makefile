SHELL = /usr/bin/env bash
PARALLEL = false
TSV = accessions.tsv
EMAIL = ""

FILTER_BY_CHARGE = true
FILTER_BY_LENGTH = true
FILTER_BY_SCORE = true

.PHONY = all clean config setup launch

all: launch

# run setup.sh with all the directories to create
setup: SETUP.DONE

# check for CONFIG.DONE to make sure the configuration was done before
SETUP.DONE: scripts/setup.sh CONFIG.DONE $(TSV)
	$< $(TSV)
 
CHECK := $(wildcard $(ROOT_DIR)/*/*/*/amplify/AMPLIFY.DONE)
launch: $(CHECK)
 	
$(CHECK): setup 
	while read sp; do \
		if [[ $(PARALLEL) == true ]]; then \
			if [[ $(EMAIL) == true ]]; then \
				(cp $(ROOT_DIR)/scripts/Makefile $(ROOT_DIR)/$(sp) && cd $(ROOT_DIR)/$(sp) && make PARALLEL=true EMAIL=$(EMAIL)) & \
			else \
				(cp $(ROOT_DIR)/scripts/Makefile $(ROOT_DIR)/$(sp) && cd $(ROOT_DIR)/$(sp) && make PARALLEL=true) & \
			fi; \
		else \
			if [[ $(EMAIL) == true ]]; then \
				(cp $(ROOT_DIR)/scripts/Makefile $(ROOT_DIR)/$(sp) && cd $(ROOT_DIR)/$(sp) && make PARALLEL=false EMAIL=$(EMAIL)) & \
			else \
				(cp $(ROOT_DIR)/scripts/Makefile $(ROOT_DIR)/$(sp) && cd $(ROOT_DIR)/$(sp) && make PARALLEL=false) & \
			fi; \
		fi; \
	done < $(TSV); \
	wait
	touch $(ROOT_DIR)/PIPELINE.DONE

# redundancy removal
rr: $(ROOT_DIR)/rr/RR.DONE

$(ROOT_DIR)/rr/RR.DONE: $(ROOT_DIR)/scripts/run-cdhit.sh $(ROOT_DIR)/scripts/get-runtime.sh $(ROOT_DIR)/PIPELINE.DONE
	mkdir -p rr
	cat $(ROOT_DIR)/*/*/*/amplify/AMPlify_results.tsv > $(ROOT_DIR)/rr/AMPlify_results.tsv
	cat $(ROOT_DIR)/*/*/*/amplify/amps.charge.nr.faa > $(ROOT_DIR)/rr/amps.charge.faa
	cat $(ROOT_DIR)/*/*/*/amplify/amps.short.nr.faa > $(ROOT_DIR)/rr/amps.short.faa
	cat $(ROOT_DIR)/*/*/*/amplify/amps.conf.nr.faa > $(ROOT_DIR)/rr/amps.conf.faa
	cat $(ROOT_DIR)/*/*/*/amplify/amps.short.charge.nr.faa > $(ROOT_DIR)/rr/amps.short.charge.faa
	cat $(ROOT_DIR)/*/*/*/amplify/amps.conf.short.nr.faa > $(ROOT_DIR)/rr/amps.conf.short.faa
	cat $(ROOT_DIR)/*/*/*/amplify/amps.conf.charge.nr.faa > $(ROOT_DIR)/rr/amps.conf.charge.faa
	cat $(ROOT_DIR)/*/*/*/amplify/amps.conf.short.charge.nr.faa > $(ROOT_DIR)/rr/amps.conf.short.charge.faa
	cat $(ROOT_DIR)/*/*/*/amplify/amps.nr.faa > $(ROOT_DIR)/rr/amps.faa
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
sable: $(ROOT_DIR)/sable/SABLE_results.tsv

$(ROOT_DIR)/sable/SABLE.DONE $(ROOT_DIR)/sable/OUT_SABLE_graph $(ROOT_DIR)/sable/SABLE_results.tsv: $(ROOT_DIR)/scripts/run-sable.sh $(ROOT_DIR)/rr/RR.DONE
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
	# rm -f $(ROOT_DIR)/PIPELINE.DONE
	rm -rf $(ROOT_DIR)/rr $(ROOT_DIR)/sable
	rm -f $(ROOT_DIR)/logs/*
	rm -f $(ROOT_DIR)/nohup.out
