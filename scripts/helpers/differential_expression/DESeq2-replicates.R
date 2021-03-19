#!/usr/bin/env Rscript

DESeq2_library <- "/home/saninta/R/replicate/"
.libPaths <- .libPaths(c(DESeq2_library, .libPaths()))
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(glue))
suppressPackageStartupMessages(library(docopt))

'Running DESeq2:

USAGE:
	DESeq2.R [--strict] [--interactive] [--output-dir <outdir>] [--reference <ref>] <metadata CSV>
	DESeq2.R --help

OPTIONS:
	--help                 Show this screen.
	--output-dir <outdir>  Specify output directory.
	--reference <ref>      Specify reference level.
	--interactive          Use interactive mode.
	--strict               Throw an error instead of using default DESeq2 reference levels.
' -> doc

args <- docopt(doc)
message("Library Paths:")
.libPaths()
# args <- commandArgs(trailingOnly = TRUE)

# if (length(args) != 1) {
#     stop("USAGE: DESeq2.R <metadata CSV file>")
# }
# first argument is the metadata file
metadata <- args$`metadata CSV`
interactive <- args$`--interactive`
strict <- args$`--strict`
# 
# metadata <- args[1]
# metadata <- "/projects/amp/rAMPage/amphibia/dauratus/skin-alkaloid/metadata.csv"

if (!file.exists(metadata)) {
    stop("Input file does not exist.")
}

if (!str_detect(metadata, "\\.csv")) {
	stop("Based on file extension, the input file is not a CSV file.")
}

if (is.null(args$`--output-dir`)) {
	specific_dir <- basename(str_remove(metadata, "\\.csv"))
	outdir <- file.path(dirname(metadata), "filtering", "DESeq2", specific_dir)
	message(glue("No output directory provided. Using default: {outdir}"))
} else {
	outdir <- args$`--output-dir`
}

dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

reference <- args$`--reference`

DESeq_output <- file.path(outdir,"DESeq2.rda")

# check if any vs files exist first
files <- list.files(outdir,pattern = "_vs_.+\\.rds", full.names = TRUE)

# if _vs_ files exist, then read them in and print for now (should be "do nothing")
if (length(files) >= 1) {
	message("Reading in existing comparison files...")
    for (i in files) {
        res <- readRDS(i)
        # print(res)
        print(summary(res))
    }
# if _vs_ files do not exist, check if there is a DESeq_output file
} else if (!file.exists(DESeq_output)) {
    suppressPackageStartupMessages(library(tximport))
    suppressPackageStartupMessages(library(DESeq2))
   	message("DESeq2 object does not exist. DESeq2 will be run...")	
    samples <- read_csv(metadata)
    paths <- samples$path
    names(paths) <- samples$sample
	
	if(!is.null(reference)) {
		if(!reference %in% samples$treatment) {
			if (interactive == FALSE) {
				if (strict == TRUE) {
					stop("Reference provided is not one of the treatments in the metadata CSV.")
				} else {
					message("Reference provided is not one of the treatments in the metadata CSV. By default, DESeq2 will use the first factor alphabetically as the reference level.")
					control <- sort(samples$treatment)[1]
				}
			} else {
				# ask to choose one
				controls <- toString(unique(samples$treatment))
				message(glue("Choose one of the following treatments to be used as the control: {controls}"))
				# control <- readline(prompt = "Response: ")
				cat("Response: ")
				control <- readLines(file("stdin"), n = 1L)
				while (!control %in% unique(samples$treatment)) {
					cat("Invalid response. Try again: ")
					control <- readLines(file("stdin"), n = 1L)
				}
			}
		} else {
			control <- reference
		}
	}

	txi_output <- file.path(outdir, "txi.salmon.rds")
	if (!file.exists(txi_output)) {
		message("Importing Salmon files using tximport...")
		txi.salmon <- tximport(paths, type="salmon", txOut = TRUE)
		txi.salmon$abundance <- as_tibble(txi.salmon$abundance, rownames = "Transcript_ID")
		message(glue("Saving tximport object to: {txi_output}"))
		saveRDS(txi.salmon, txi_output)   
	} else {
		txi.salmon <- readRDS(txi_output)
	}

	message("Creating the DESeq Data Set from imported Salmon files...")
    dds <- DESeqDataSetFromTximport(txi.salmon,samples, ~ treatment)

	if (is.null(reference)) {
		num_controls <- length(unique(dds$treatment[str_which(dds$treatment,'[Cc]ontrol')]))
		if (num_controls  == 1) {
			# only one control found, use it
			control <- unique(dds$treatment[str_which(dds$treatment,'[Cc]ontrol')])
			dds$treatment <- relevel(dds$treatment, ref = as.character(control))
		} else if (num_controls == 0) {
			if (interactive == TRUE) {
				# no controls found, use designated tissue by user
				controls <- toString(unique(dds$treatment))
				message(glue("Choose one of the following treatments to be used as the control: {controls}"))
				# control <- readline(prompt = "Response: ")
				cat("Response: ")
				control <- readLines(file("stdin"), n = 1L)
				while (!control %in% unique(dds$treatment)) {
					cat("Invalid response. Try again: ")
					control <- readLines(file("stdin"), n = 1L)
				}
				dds$treatment <- relevel(dds$treatment, ref = as.character(control))
			} else {
				if (strict == TRUE) {
					stop("No reference level provided. Since strict mode is enabled, no default will be used.")
				} else {
					message("No reference level provided. By default, DESeq2 will use the first factor alphabetically as the reference level.")
					control <- levels(dds$treatment)[1]
				}
			}
		} else {
			if (interactive == TRUE) {
				# multiple controls found, use user-selected control
				controls <- toString(unique(dds$treatment[str_which(dds$treatment,'[Cc]ontrol')]))
				message(glue("Choose one of the following treatments to be used as the control: {controls}"))
				# control <- readline(prompt = "Response: ")
				cat("Response: ")
				control <- readLines(file("stdin"), n = 1L)
				while (!control %in% unique(dds$treatment[str_which(dds$treatment,'[Cc]ontrol')])) {
					cat("Invalid response. Try again: ")
					control <- readLines(file("stdin"), n = 1L)
				}
				dds$treatment <- relevel(dds$treatment, ref = as.character(control))
			} else {
				if (strict == FALSE) {
					message("No reference level provided. By default, DESeq2 will use the first factor alphabetically as the reference level.")
					control <- levels(dds$treatment)[1]
				} else {
					stop("No reference level provided. Since strict mode is enabled, no default will be used.")
				}
			}
		}
	}
	final_control <- as.character(control)	
    message(glue("Running DESeq2 using '{final_control}' as the control..."))
    dds <- DESeq(dds)
    message(glue("Writing DESeq2 object to: {DESeq_output}"))
	save(dds, file = DESeq_output)
    # saveRDS(dds, DESeq_output)
   
	message("Getting DESeq2 comparisons...")
    comparisons <- resultsNames(dds)
    for (i in comparisons[-1]) {
            res <- as_tibble(results(dds, name=i), rownames = "Transcript_ID")
            results_output <- file.path(outdir, glue("{i}.rds"))
            message(glue("Writing DESeq2 comparison results to: {results_output}"))
            saveRDS(res, results_output)
            # print(res)
            print(summary(res))
        }
} else {
    suppressPackageStartupMessages(library(DESeq2))
	message(glue("Reading in RDS object: {DESeq_output}"))
	load(DESeq_output)
    # dds <- readRDS(DESeq_output)
    comparisons <- resultsNames(dds)
    for (i in comparisons[-1]) {
        res <- as_tibble(results(dds, name=i), rownames = "Transcript_ID")
        results_output <- file.path(outdir, glue("{i}.rds"))
        message(glue("Writing DESeq2 comparison results to: {results_output}"))
        saveRDS(res, results_output)
        # print(res)
        print(summary(res))
    }
}
