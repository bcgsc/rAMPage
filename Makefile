SHELL = /usr/bin/env bash
PARALLEL = false
MULTI = true
TSV = accessions.tsv
EMAIL = ""

FILTER_BY_CHARGE = true
FILTER_BY_LENGTH = true
FILTER_BY_SCORE = true

.PHONY = all setup check pipeline combine rr sable
	
all: check sable

# run setup.sh with all the directories to create
setup: SETUP.DONE

check: $(TSV)
	if [[ ! -s $(TSV) ]]; then \
		echo "File $(TSV) does not exist or is empty." 1>&2; \
		exit 1; \
	fi

# check for CONFIG.DONE to make sure the configuration was done before
SETUP.DONE: scripts/setup.sh CONFIG.DONE $(TSV) check
	$< $(TSV)
 
pipeline: PIPELINE.DONE
	
PIPELINE.DONE: scripts/Makefile SETUP.DONE $(TSV) check
	if [[ $(MULTI) == true ]]; then \
		while read sp; do \
			if [[ $(PARALLEL) == true ]]; then \
				if [[ -n $(EMAIL) ]]; then \
					/usr/bin/time -pv make -f $(ROOT_DIR)/$< -C $$sp PARALLEL=true EMAIL=$(EMAIL) &> $$sp/logs/00-pipeline.log & \
				else \
					/usr/bin/time -pv make -f $(ROOT_DIR)/$< -C $$sp PARALLEL=true &> $$sp/logs/00-pipeline.log & \
				fi; \
			else \
				if [[ -n $(EMAIL) ]]; then \
					/usr/bin/time -pv make -f $(ROOT_DIR)/$< -C $$sp PARALLEL=false EMAIL=$(EMAIL) &> $$sp/logs/00-pipeline.log & \
				else \
					/usr/bin/time -pv make -f $(ROOT_DIR)/$< -C $$sp PARALLEL=false &> $$sp/logs/00-pipeline.log & \
				fi; \
			fi; \
		done < <(cut -f1 -d$$'\t' $(TSV)); \
		wait; \
	else \
		while read sp; do \
			if [[ $(PARALLEL) == true ]]; then \
				if [[ -n $(EMAIL) ]]; then \
					/usr/bin/time -pv make -f $(ROOT_DIR)/$< -C $$sp PARALLEL=true EMAIL=$(EMAIL) &> $$sp/logs/00-pipeline.log; \
				else \
					/usr/bin/time -pv make -f $(ROOT_DIR)/$< -C $$sp PARALLEL=true &> $$sp/logs/00-pipeline.log; \
				fi; \
			else \
				if [[ -n $(EMAIL) ]]; then \
					/usr/bin/time -pv make -f $(ROOT_DIR)/$< -C $$sp PARALLEL=false EMAIL=$(EMAIL) &> $$sp/logs/00-pipeline.log; \
				else \
					/usr/bin/time -pv make -f $(ROOT_DIR)/$< -C $$sp PARALLEL=false &> $$sp/logs/00-pipeline.log; \
				fi; \
			fi; \
		done < <(cut -f1 -d$$'\t' $(TSV)); \
	fi
	if [[ $$(ls */*/*/amplify/AMPLIFY.DONE | wc -l) -ge $$(wc -l $(TSV) | cut -f1 -d' ') ]]; then \
		touch PIPELINE.DONE; \
	else \
		touch PIPELINE.FAIL; \
	fi

# combine the FASTA files from all the runs
combine: pipeline
	mkdir -p rr
	cat */*/*/amplify/AMPlify_results.tsv > rr/AMPlify_results.tsv
	cat */*/*/amplify/amps.charge.nr.faa > rr/amps.charge.faa
	cat */*/*/amplify/amps.short.nr.faa > rr/amps.short.faa
	cat */*/*/amplify/amps.conf.nr.faa > rr/amps.conf.faa
	cat */*/*/amplify/amps.short.charge.nr.faa > rr/amps.short.charge.faa
	cat */*/*/amplify/amps.conf.short.nr.faa > rr/amps.conf.short.faa
	cat */*/*/amplify/amps.conf.charge.nr.faa > rr/amps.conf.charge.faa
	cat */*/*/amplify/amps.conf.short.charge.nr.faa > rr/amps.conf.short.charge.faa
	cat */*/*/amplify/amps.nr.faa > rr/amps.faa

# redundancy removal
rr: rr/RR.DONE

rr/RR.DONE: scripts/run-cdhit.sh combine
	/usr/bin/time -pv bash -c '\
 		$< -v rr/amps.charge.faa \
			&>> logs/11-redundancy_removal.log; \
 		$< rr/amps.short.faa \
			&>> logs/11-redundancy_removal.log; \
 		$< rr/amps.conf.faa \
			&>> logs/11-redundancy_removal.log; \
 		$< rr/amps.short.charge.faa \
			&>> logs/11-redundancy_removal.log; \
 		$< rr/amps.conf.short.faa \
			&>> logs/11-redundancy_removal.log; \
 		$< rr/amps.conf.charge.faa \
			&>> logs/11-redundancy_removal.log; \
 		$< rr/amps.conf.short.charge.faa \
			&>> logs/11-redundancy_removal.log; \
 		$< rr/amps.faa \
			&>> logs/11-redundancy_removal.log' \
 		&>> logs/11-redundancy_removal.log
	touch rr/RR.DONE

# run sable
sable: sable/SABLE.DONE

sable/SABLE.DONE: scripts/run-sable.sh rr
	if [[ -n $(EMAIL) ]]; then \
		if [[ $(FILTER_BY_CHARGE) == true && $(FILTER_BY_LENGTH) == false && $(FILTER_BY_SCORE) == false ]]; then \
			$< -a $(EMAIL) -o sable rr/amps.charge.nr.faa \
				&> logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == false && $(FILTER_BY_LENGTH) == true && $(FILTER_BY_SCORE) == false ]]; then \
			$< -a $(EMAIL) -o sable rr/amps.short.nr.faa \
				&> logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == false && $(FILTER_BY_LENGTH) == false && $(FILTER_BY_SCORE) == true ]]; then \
			$< -a $(EMAIL) -o sable rr/amps.conf.nr.faa \
				&> logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == true && $(FILTER_BY_LENGTH) == true && $(FILTER_BY_SCORE) == false ]]; then \
			$< -a $(EMAIL) -o sable rr/amps.short.charge.nr.faa \
				&> logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == false && $(FILTER_BY_LENGTH) == true && $(FILTER_BY_SCORE) == true ]]; then \
			$< -a $(EMAIL) -o sable rr/amps.conf.short.nr.faa \
				&> logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == true && $(FILTER_BY_LENGTH) == false && $(FILTER_BY_SCORE) == true ]]; then \
			$< -a $(EMAIL) -o sable rr/amps.conf.charge.nr.faa \
				&> logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == true && $(FILTER_BY_LENGTH) == true && $(FILTER_BY_SCORE) == true ]]; then \
			$< -a $(EMAIL) -o sable rr/amps.conf.short.charge.nr.faa \
				&> logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == false && $(FILTER_BY_LENGTH) == false && $(FILTER_BY_SCORE) == false ]]; then \
			$< -a $(EMAIL) -o sable rr/amps.nr.faa \
				&> logs/12-sable.log; \
		fi; \
	else \
		if [[ $(FILTER_BY_CHARGE) == true && $(FILTER_BY_LENGTH) == false && $(FILTER_BY_SCORE) == false ]]; then \
			$< -o sable rr/amps.charge.nr.faa \
				&> logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == false && $(FILTER_BY_LENGTH) == true && $(FILTER_BY_SCORE) == false ]]; then \
			$< -o sable rr/amps.short.nr.faa \
				&> logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == false && $(FILTER_BY_LENGTH) == false && $(FILTER_BY_SCORE) == true ]]; then \
			$< -o sable rr/amps.conf.nr.faa \
				&> logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == true && $(FILTER_BY_LENGTH) == true && $(FILTER_BY_SCORE) == false ]]; then \
			$< -o sable rr/amps.short.charge.nr.faa \
				&> logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == false && $(FILTER_BY_LENGTH) == true && $(FILTER_BY_SCORE) == true ]]; then \
			$< -o sable rr/amps.conf.short.nr.faa \
				&> logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == true && $(FILTER_BY_LENGTH) == false && $(FILTER_BY_SCORE) == true ]]; then \
			$< -o sable rr/amps.conf.charge.nr.faa \
				&> logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == true && $(FILTER_BY_LENGTH) == true && $(FILTER_BY_SCORE) == true ]]; then \
			$< -o sable rr/amps.conf.short.charge.nr.faa \
				&> logs/12-sable.log; \
		elif [[ $(FILTER_BY_CHARGE) == false && $(FILTER_BY_LENGTH) == false && $(FILTER_BY_SCORE) == false ]]; then \
			$< -o sable rr/amps.nr.faa \
				&> logs/12-sable.log; \
		fi; \
	fi

clean:
	rm -f CONFIG.DONE
	rm -f PIPELINE.DONE
	rm -f PIPELINE.FAIL
	rm -f SETUP.DONE
	rm -rf rr
	rm -rf sable
	rm -f logs/*
	rm -f nohup.out
	if [[ -s $(TSV) ]]; then \
		for i in $$(cut -f1 -d/ $(TSV) | sort -u); do \
			rm -rf $$i; \
		done; \
	fi
