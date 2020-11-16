SHELL = /usr/bin/env bash
PARALLEL = true

FILTER_BY_CHARGE = true
FILTER_BY_LENGTH = true
FILTER_BY_SCORE = true

.PHONY = all clean config setup launch

# only 1 is true
ifeq ($(FILTER_BY_CHARGE), true)
	ifeq ( $(FILTER_BY_LENGTH), false)
		ifeq ( $(FILTER_BY_SCORE), false)
			FASTA := $(wildcard $(ROOT_DIR)/*/*/*/amplify/amps.charge.nr.faa)
		endif
	endif
endif

ifeq ($(FILTER_BY_CHARGE), false)
	ifeq ( $(FILTER_BY_LENGTH), true)
		ifeq ( $(FILTER_BY_SCORE), false)
			FASTA := $(wildcard $(ROOT_DIR)/*/*/*/amplify/amps.short.nr.faa)
		endif
	endif
endif


ifeq ($(FILTER_BY_CHARGE), false)
	ifeq ( $(FILTER_BY_LENGTH), false)
		ifeq ( $(FILTER_BY_SCORE), true)
			FASTA := $(wildcard $(ROOT_DIR)/*/*/*/amplify/amps.conf.nr.faa)
		endif
	endif
endif

# only 2 are true
ifeq ($(FILTER_BY_CHARGE), true)
	ifeq ( $(FILTER_BY_LENGTH), true)
		ifeq ( $(FILTER_BY_SCORE), false)
			FASTA := $(wildcard $(ROOT_DIR)/*/*/*/amplify/amps.short.charge.nr.faa)
		endif
	endif
endif

ifeq ($(FILTER_BY_CHARGE), false)
	ifeq ( $(FILTER_BY_LENGTH), true)
		ifeq ( $(FILTER_BY_SCORE), true)
			FASTA := $(wildcard $(ROOT_DIR)/*/*/*/amplify/amps.conf.short.nr.faa)
		endif
	endif
endif

ifeq ($(FILTER_BY_CHARGE), true)
	ifeq ( $(FILTER_BY_LENGTH), false)
		ifeq ( $(FILTER_BY_SCORE), true)
			FASTA := $(wildcard $(ROOT_DIR)/*/*/*/amplify/amps.conf.charge.nr.faa)
		endif
	endif
endif

# if all are true

ifeq ($(FILTER_BY_CHARGE), true)
	ifeq ( $(FILTER_BY_LENGTH), true)
		ifeq ( $(FILTER_BY_SCORE), true)
			FASTA := $(wildcard $(ROOT_DIR)/*/*/*/amplify/amps.conf.short.charge.nr.faa)
		endif
	endif
endif

# if all are false
ifeq ($(FILTER_BY_CHARGE), false)
	ifeq ( $(FILTER_BY_LENGTH), false)
		ifeq ( $(FILTER_BY_SCORE), false)
			FASTA := $(wildcard $(ROOT_DIR)/*/*/*/amplify/amps.nr.faa)
		endif
	endif
endif

TSV := $(wildcard $(ROOT_DIR)/*/*/*/amplify/AMPlify_results.tsv)

all: launch

# first source scripts/config.sh
config: CONFIG.DONE
CONFIG.DONE: scripts/config.sh
	source $<
# run setup.sh with all the directories to create
setup: SETUP.DONE
SETUP.DONE: scripts/setup.sh master_accessions.tsv CONFIG.DONE 
	$< master_accessions.tsv

launch: $(FASTA) $(TSV)

$(TSV) $(FASTA): setup 
	while read sp; do (cp $(ROOT_DIR)/scripts/Makefile $(ROOT_DIR)/$(sp) && cd $(ROOT_DIR)/$(sp) && make PARALLEL=true) & done < master_accessions.tsv
	wait

# redundancy removal
rr: $(ROOT_DIR)/amps.nr.faa

$(ROOT_DIR)/amps.nr.faa: $(FASTA) $(TSV) $(ROOT_DIR)/scripts/run-cdhit.sh $(ROOT_DIR)/scripts/get-runtime.sh
	mkdir -p rr
	cat $(FASTA) > $(ROOT_DIR)/rr/amps.faa
	$(ROOT_DIR)/scripts/run-cdhit.sh -v $(ROOT_DIR)/rr/amps.faa &> $(ROOT_DIR)/logs/11-redundancy_removal.log
	cat $(TSV) > $(ROOT_DIR)/AMPlify_results.tsv # need to remove headers

# run sable
sable: $(ROOT_DIR)/sable_output.tsv

$(ROOT_DIR)/sable/OUT_SABLE_graph $(ROOT_DIR)/sable/sable_output.tsv: $(ROOT_DIR)/rr/amps.nr.faa $(ROOT_DIR)/scripts/run-sable.sh
	$(ROOT_DIR)/scripts/run-sable.sh -o sable $(ROOT_DIR)/rr/amps.nr.faa &> $(ROOT_DIR)/logs/12-sable.log

# $(ROOT_DIR)/sable/sable_output.tsv: $(ROOT_DIR)/sable/OUT_SABLE_graph $(ROOT_DIR)/scripts/process-sable.sh 
#	$(ROOT_DIR)/scripts/process-sable.sh $(ROOT_DIR)/sable/OUT_SABLE_graph &>> $(ROOT_DIR)/logs/12-sable.log

# clean:
