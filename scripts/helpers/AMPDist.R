#!/usr/bin/env Rscript

suppressMessages(library(tidyverse))
suppressMessages(library(docopt))
suppressMessages(library(glue))

'AMP Distributions:

USAGE: 
  AMPDist.R --input_tsv=<file> [--reference] [--sensitivity] [--output_dir=<path>] [--amphibian_score=<float>] [--insect_score=<float>] [--length=<int>] [--charge=<int>] [--thresholds]

OPTIONS:
  -h --help                 Show this screen
  --input_tsv=<file>        AMPlify TSV of AMPs
  --output_dir=<path>       Output directory
  --sensitivity             BETA: Turn on sensitivity (sensitivity uses thresholds given by --thresholds)
  --thresholds              Show thresholds on plot
  --reference               AMPs provided in --input_tsv are REFERENCE AMPs (changes title of plot)
  --amphibian_score=<float> Amphibian AMPlify score thresold [default: 0.90]
  --insect_score=<float>    Insect AMPlify score threshold [default: 0.80]
  --length=<int>            Length threshold [default: 30]
  --charge=<int>            Charge threshold [default: 2]
' -> doc

arguments <- docopt(doc)

if(arguments$help == TRUE | arguments$h == TRUE) {
  print(doc)
  stop()
}

if(arguments$sensitivity == TRUE) {
  sens_on <- TRUE
} else {
  sens_on <- FALSE
}

if(arguments$reference == TRUE) {
  reference <- TRUE
} else {
  reference <- FALSE
}

if(arguments$thresholds == TRUE) {
  thresholds <- TRUE
} else {
  thresholds <- FALSE
}

if(sens_on == TRUE) {
  thresholds <- TRUE
}

if(is.null(arguments$input_tsv)) {
  stop("Required AMPlify TSV file not provided.")
} else {
  # check if it exists
  if(!file.exists(arguments$input_tsv)) {
    stop(glue("Given file {arguments$input_tsv} for --input_tsv does not exist."))
  }
  input_tsv <- normalizePath(arguments$input_tsv)
}

if(is.null(arguments$output_dir)) {
  output_dir <- dirname(normalizePath(input_tsv))
} else {
  if(!dir.exists(arguments$output_dir)) {
    message(glue("Given path {arguments$output_dir} for --output_dir does not exist. Using parent directory of AMPlify TSV."))
    output_dir <- dirname(normalizePath(input_tsv))
  } else {
    output_dir <- normalizePath(arguments$output_dir)
  }
}

if(is.null(arguments$amphibian_score)) {
  amphibian_score <- 0.90
  amphibian_score_str <- "0.90"
} else {
  if (as.numeric(arguments$amphibian_score) >= 0.5 && as.numeric(arguments$amphibian_score) <= 1) {
    amphibian_score <- as.numeric(arguments$amphibian_score)
    amphibian_score_str <- format(amphibian_score, digits = 4, nsmall = 2)
  } else {
    stop("Amphibian AMPlify score threshold must be between 0.5 and 1.0.")
  }
}

if(is.null(arguments$insect_score)) {
  insect_score <- 0.80
  insect_score_str <- "0.80"
} else {
  if (as.numeric(arguments$insect_score) >= 0.5 && as.numeric(arguments$insect_score) <= 1) {
    insect_score <- as.numeric(arguments$insect_score)
    insect_score_str <- format(insect_score, digits = 4, nsmall = 2)
  } else {
    stop("Insect AMPlify score threshold must be between 0.5 and 1.0.")
  }
}

if(is.null(arguments$length)) {
  length <- 30
  length_str <- "30"
} else {
  if (as.numeric(arguments$length) > 0) {
    length <- round(as.numeric(arguments$length))
    length_str <- as.character(length)
  } else {
    stop("Length threshold must be greater than 0.")
  }
}

if(is.null(arguments$charge)) {
  charge <- 2
  charge_str <- "2"
} else {
  charge <- round(as.numeric(arguments$charge))
  charge_str <- as.character(charge)
}


tsv <- read_tsv(input_tsv, col_types = cols()) %>%
  select(-c(Attention, Prediction))

tsv_long <- tsv %>%
  pivot_longer(cols = c("Length", "Score", "Charge"), names_to = "Property") %>%
  mutate(Property = fct_relevel(Property, "Score", "Length", "Charge"))

num_classes <- tsv_long %>%
  select(Class) %>%
  unique() %>%
  nrow()

if(num_classes == 1) {
  single_class <- tsv_long %>%
    pull(Class) %>%
    unique()
  if(single_class == "Amphibia") {
    tsv_long <- tsv_long %>%
      mutate(Class = fct_recode(Class, Amphibians = "Amphibia"))
  } else if(single_class == "Insecta") {
    tsv_long <- tsv_long %>%
      mutate(Class = fct_recode(Class, Insects = "Insecta"))
  } else {
    stop("This script currently only supports amphibian and insect datasets.")
  }
} else {
  tsv_long <- tsv_long %>%
    mutate(Class = fct_recode(Class, Amphibians = "Amphibia", Insects = "Insecta"))
}
  

if (sens_on == TRUE) {
  message("Calculating sensitivty...")
  amphibian_score_sensitivity <- paste0(format(nrow(filter(tsv, Score >= amphibian_score, Class == "Amphibia")) / nrow(filter(tsv, Class == "Amphibia")) * 100 ,digits = 4, nsmall = 2),"%")
  insect_score_sensitivity <- paste0(format(nrow(filter(tsv, Score >= insect_score, Class == "Insecta")) / nrow(filter(tsv, Class == "Insecta")) * 100 ,digits = 4, nsmall = 2),"%")
  amphibian_length_sensitivity <- paste0(format(nrow(filter(tsv, Length <= length, Class == "Amphibia")) / nrow(filter(tsv, Class == "Amphibia")) * 100 ,digits = 4, nsmall = 2),"%")
  insect_length_sensitivity <- paste0(format(nrow(filter(tsv, Length <= length, Class == "Insecta")) / nrow(filter(tsv, Class == "Insecta")) * 100 ,digits = 4, nsmall = 2),"%")
  amphibian_charge_sensitivity <- paste0(format(nrow(filter(tsv, Charge >= charge, Class == "Amphibia")) / nrow(filter(tsv, Class == "Amphibia")) * 100 ,digits = 4, nsmall = 2),"%")
  insect_charge_sensitivity <- paste0(format(nrow(filter(tsv, Charge >= charge, Class == "Insecta")) / nrow(filter(tsv, Class == "Insecta")) * 100 ,digits = 4, nsmall = 2),"%")
  
  score_sensitivity <- paste0(format(nrow(filter(tsv, if_else(Class == "Amphibia", Score >= amphibian_score, Score >= insect_score))) / nrow(tsv) * 100 ,digits = 4, nsmall = 2),"%")
  length_sensitivity <- paste0(format(nrow(filter(tsv, Length <= length)) / nrow(tsv) * 100 ,digits = 4, nsmall = 2),"%")
  charge_sensitivity <- paste0(format(nrow(filter(tsv, Charge >= charge)) / nrow(tsv) * 100 ,digits = 4, nsmall = 2),"%")
  
  amphibian_score_length_sensitivity <- paste0(format(nrow(filter(tsv, Score >= amphibian_score, Length <= length, Class == "Amphibia")) / nrow(filter(tsv, Class == "Amphibia")) * 100 ,digits = 4, nsmall = 2),"%")
  insect_score_length_sensitivity <- paste0(format(nrow(filter(tsv, Score >= insect_score, Length <= length, Class == "Insecta")) / nrow(filter(tsv, Class == "Insecta")) * 100 ,digits = 4, nsmall = 2),"%")
  amphibian_score_charge_sensitivity <- paste0(format(nrow(filter(tsv, Score >= amphibian_score, Charge >= charge, Class == "Amphibia")) / nrow(filter(tsv, Class == "Amphibia")) * 100 ,digits = 4, nsmall = 2),"%")
  insect_score_charge_sensitivity <- paste0(format(nrow(filter(tsv, Score >= insect_score, Charge >= charge, Class == "Insecta")) / nrow(filter(tsv, Class == "Insecta")) * 100 ,digits = 4, nsmall = 2),"%")
  
  score_length_sensitivity <- paste0(format(nrow(filter(tsv, if_else(Class == "Amphibia", Score >= amphibian_score, Score >= insect_score), Length <= length)) / nrow(tsv) * 100 ,digits = 4, nsmall = 2),"%")
  score_charge_sensitivity <- paste0(format(nrow(filter(tsv, if_else(Class == "Amphibia", Score >= amphibian_score, Score >= insect_score), Charge >= charge)) / nrow(tsv) * 100 ,digits = 4, nsmall = 2),"%")
  length_charge_sensitivity <- paste0(format(nrow(filter(tsv, Length <= length, Charge >= charge)) / nrow(tsv) * 100 ,digits = 4, nsmall = 2),"%")
  
  amphibian_length_charge_sensitivity <- paste0(format(nrow(filter(tsv, Length <= length, Charge >= charge, Class == "Amphibia")) / nrow(filter(tsv, Class == "Amphibia")) * 100 ,digits = 4, nsmall = 2),"%")
  insect_length_charge_sensitivity <- paste0(format(nrow(filter(tsv, Length <= length, Charge >= charge, Class == "Insecta")) / nrow(filter(tsv, Class == "Insecta")) * 100 ,digits = 4, nsmall = 2),"%")
  
  amphibian_score_length_charge_sensitivity <- paste0(format(nrow(filter(tsv, Score >= amphibian_score, Length <= length, Charge >= charge, Class == "Amphibia")) / nrow(filter(tsv, Class == "Amphibia")) * 100 ,digits = 4, nsmall = 2),"%")
  insect_score_length_charge_sensitivity <- paste0(format(nrow(filter(tsv, Score >= insect_score, Length <= length, Charge >= charge, Class == "Insecta")) / nrow(filter(tsv, Class == "Insecta")) * 100 ,digits = 4, nsmall = 2),"%")
  
  score_length_charge_sensitivity <- paste0(format(nrow(filter(tsv, if_else(Class == "Amphibia", Score >= amphibian_score, Score >= insect_score), Length <= length, Charge >= charge)) / nrow(tsv) * 100 ,digits = 4, nsmall = 2),"%")
  
  sensitivity_df <- tibble(
    "# Filters" = c(rep(1,3), rep(2,3), 3),
    "Filter Combinations" = c("Score", "Length", "Charge", "Score & Length", "Score & Charge", "Length & Charge", "Score, Length, & Charge"),
    "Amphibians" = c(amphibian_score_sensitivity, amphibian_length_sensitivity, amphibian_charge_sensitivity, amphibian_score_length_sensitivity, amphibian_score_charge_sensitivity, amphibian_length_charge_sensitivity, amphibian_score_length_charge_sensitivity),
    "Insects" = c(insect_score_sensitivity, insect_length_sensitivity, insect_charge_sensitivity, insect_score_length_sensitivity,insect_score_charge_sensitivity, insect_length_charge_sensitivity, insect_score_length_charge_sensitivity),
    "Overall" = c(score_sensitivity, length_sensitivity, charge_sensitivity, score_length_sensitivity, score_charge_sensitivity, length_charge_sensitivity, score_length_charge_sensitivity)
  )
  
  ann_text <- tibble(
    Property = rep(c("Score", "Length", "Charge"), each = 2, times = 1),
    Class = rep(c("Amphibians", "Insects"),3),
    Label = c(amphibian_score_str, insect_score_str, rep(length_str, 2), rep(charge_str, 2)),
    x = c(amphibian_score, insect_score, rep(length,2), rep(charge,2)),
    y = rep(c(1500,125),3), 
    xmin = c(amphibian_score, insect_score ,rep(0,2), rep(charge,2)),
    xmax = c(1,1,rep(length,2),rep(length/2,2)),
    ymin = rep(0,6),
    ymax = rep(c(2771,234),3),
    vjust = c(rep(-0.5,2), rep(1.5,2), rep(-0.5,2)),
    x_sens = c(amphibian_score, amphibian_score-1, rep(length/2,2), rep(4,2)),
    # x_sens = c(0.90, 0.80,rep(30,2), rep(2,2)),
    y_sens = rep(c(2850,240),3),
    # vjust_sens = c(rep(0.5,6)),
    # hjust_sens = c(rep(-1.1,2), rep(1,2), rep(-1,2)),
    Sensitivity = c(amphibian_score_sensitivity, 
                    insect_score_sensitivity, 
                    amphibian_length_sensitivity,
                    insect_length_sensitivity,
                    amphibian_charge_sensitivity,
                    insect_charge_sensitivity
    )
  ) %>%
    mutate(Class = fct_relevel(Class, "Amphibians", "Insects"),
           Property = fct_relevel(Property, "Score", "Length", "Charge"))
}
labels <- tibble(
  Property = rep(c("Score", "Length", "Charge"), each = 2, times = 1),
  Class = rep(c("Amphibians", "Insects"),3),
  Label = c(amphibian_score_str, insect_score_str, rep(length_str, 2), rep(charge_str, 2)),
  x = c(amphibian_score, insect_score, rep(length,2), rep(charge,2)),
  y = rep(c(1500,200),3),
  vjust = c(rep(-0.5,2), rep(1.5,2), rep(-0.5,2)),
) %>%
  mutate(Class = fct_relevel(Class, "Amphibians", "Insects"),
         Property = fct_relevel(Property, "Score", "Length", "Charge"))

message("Plotting distribution...")
facet_ref <- ggplot(tsv_long) +
  geom_histogram(data = filter(tsv_long, Property == "Charge"), 
                 aes(x = value, fill = Class), binwidth = 1, colour = "black") +
  geom_histogram(data = filter(tsv_long, Property == "Length"), 
                 aes(x = value, fill = Class), bins = 30, colour = "black") +
  geom_histogram(data = filter(tsv_long, Property == "Score"), 
                 aes(x = value, fill = Class), bins = 30, colour = "black") +
  facet_grid(Class ~ Property, scales = "free", switch = "x") +
  theme_bw() +
  theme(text = element_text(size=16),
        axis.title.x = element_blank(),
        strip.placement = "outside",
        strip.background.x = element_blank(),
        strip.text.y = element_blank(),
        legend.position = "bottom")

if(thresholds == TRUE) {
  facet_ref <- facet_ref + 
    geom_vline(data = filter(tsv_long, Property == "Score", Class == "Amphibians"),
             aes(xintercept = amphibian_score), 
             linetype = "dashed") +
    geom_vline(data = filter(tsv_long, Property == "Score", Class == "Insects"),
             aes(xintercept = insect_score), 
             linetype = "dashed") +
    geom_vline(data = filter(tsv_long, Property == "Length"),
             aes(xintercept = length),
             linetype = "dashed") +
    geom_vline(data = filter(tsv_long, Property == "Charge"),
             aes(xintercept = charge),
             linetype = "dashed") +
    geom_text(data = labels,
              aes(label = Label, x = x, y = y, vjust = vjust), angle = 90)
}

if(sens_on == TRUE) {
  facet_ref <- facet_ref + 
    geom_rect(data = ann_text, 
            aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax), 
            fill = "green",
            alpha = 0.2) +
    geom_text(data = ann_text,
            aes(label = Sensitivity, x = x_sens, y = y_sens#, 
                # vjust = vjust_sens, hjust = hjust_sens
            ), fontface = 2, colour = "green", size = 3)
}

if(reference == TRUE) {
  facet_ref <- facet_ref + 
  labs(title = "Distribution of Reference AMPs")
  outfile <- file.path(output_dir, "ReferenceAMPDistribution.png")
} else {
  facet_ref <- facet_ref + 
    labs(title = "Distribution of AMPs")
  outfile <- file.path(output_dir, "AMPDistribution.png")
}

message(glue("Distribution plot saved to {outfile}."))
ggsave(filename = outfile, 
       plot = facet_ref, 
       width = 10, 
       height = 5, 
       units = "in")
