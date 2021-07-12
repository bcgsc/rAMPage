suppressMessages(library(tidyverse))
suppressMessages(library(docopt))
suppressMessages(library(glue))

'Selecting AMPs for Synthesis

USAGE:
  SelectForSynthesis.R --one_each_cluster=<file> --three_each_cluster=<file> [--output_dir=<path>] [--species_count_threshold=<int>] [--num_insects=<int>] [--insect_score_threshold=<float>] [--insect_species_count_threshold=<int>] [--num_cluster_seqs=<int>] [--too_many_Rs=<int>]

OPTIONS:
  -h --help                               Show this screen
  --one_each_cluster=<file>               OneEachCluster TSV file
  --three_each_cluster=<file>             ThreeEachCluster TSV file
  --output_dir=<path>                     Output directory
  --species_count_threshold=<int>         Select sequences present in at least this number of species [default: 3]
  --num_insects=<int>                     Number of top-scoring insect sequences to select [default: 30]
  --insect_score_threshold=<float>        AMPlify score thresold for top-scoring insect sequences [default: 0.99]
  --insect_species_count_threshold=<int>  Select top-scoring insect sequences present in at most this number of species [default: 1]
  --num_cluster_seqs=<int>                Number of top-scoring 95% cluster sequences to select [default: 30]
  --too_many_Rs=<int>                     Number of arginines in a row that is too hard to synthesize [default: 5]
' -> doc

arguments <- docopt(doc)

if(arguments$help == TRUE | arguments$h == TRUE) {
  print(doc)
  stop()
}

if(is.null(arguments$one_each_cluster)) {
  stop("Required OneEachCluster TSV file not provided.")
} else {
  # check if it exists
  if(!file.exists(arguments$one_each_cluster)) {
    stop(glue("Given file {arguments$one_each_cluster} for --one_each_cluster does not exist."))
  }
  OneEachCluster <- arguments$one_each_cluster
}

if(is.null(arguments$three_each_cluster)) {
  stop("Required ThreeEachCluster TSV file not provided.")
} else {
  # check if it exists
  if(!file.exists(arguments$three_each_cluster)) {
    stop(glue("Given file {arguments$three_each_cluster} for --three_each_cluster does not exist."))
  }
  ThreeEachCluster <- arguments$three_each_cluster
}

if(is.null(arguments$num_insects)) {
  num_insects <- 30
} else {
  num_insects <- arguments$num_insects
}

if(is.null(arguments$species_count_threshold)) {
  species_count_threshold <- 3
} else {
  species_count_threshold <- arguments$species_count_threshold
}

if(is.null(arguments$too_many_Rs)) {
  too_many_Rs <- 5
} else {
  too_many_Rs <- arguments$too_many_Rs
}

if(is.null(arguments$num_cluster_seqs)) {
  num_cluster_seqs <- 30
} else {
  num_cluster_seqs <- arguments$num_cluster_seqs
}

if(is.null(arguments$insect_score_threshold)) {
  insect_score_threshold <- 0.99
} else {
  insect_score_threshold <- arguments$insect_score_threshold
}

if(is.null(arguments$insect_species_count_threshold)) {
  insect_species_count_threshold <- 1
} else {
  insect_species_count_threshold <- arguments$insect_species_count_threshold
}

if(is.null(arguments$output_dir)) {
  output_dir <- getwd()
} else {
  output_dir <- arguments$output_dir
}
output_file <- file.path(output_dir, "AMPsForSynthesis.tsv")

message(glue("Reading in {OneEachCluster}..."))
OneEachClusterTSV <- read_tsv(OneEachCluster, col_types = cols()) %>%
  select(Cluster, Sequence, Class, Score, Length, Charge, `Species Count`)

message(glue("Reading in {ThreeEachCluster}..."))
ThreeEachClusterTSV <- read_tsv(ThreeEachCluster, col_types = cols()) %>%
  select(Cluster, Sequence, Class, Score, Length, Charge, `Species Count`)

# Prioritize by SpeciesCount ----
message(glue("Selecting AMPs present in at least {species_count_threshold} species..."), appendLF = FALSE)
SpeciesCountPrioritization <- OneEachClusterTSV %>%
  # Filter for species_count >= 3, filter OUT sequences with TooManyRs in a row
  filter(`Species Count` >= species_count_threshold, !str_detect(Sequence, paste(rep("R", too_many_Rs), collapse = ""))) %>%
  # Arrange by descending species_count
  arrange(desc(`Species Count`)) %>%
  # add a column "Prioritization Method" with "SpeciesCount" as the value
  mutate(`Prioritization Method` = "SpeciesCount")
n <- nrow(SpeciesCountPrioritization)
message(glue("{n} AMPs selected."))

# Prioritize by TopInsect ----
message(glue("Selecting {num_insects} insect AMPs present in at most {insect_species_count_threshold} species with an AMPlify score > {insect_score_threshold}."))
TopInsectPrioritization <- OneEachClusterTSV %>%
  # Filter for taxonomic class = insects, species_count = 1, and score > 0.99
  # Filter out sequences with too many Rs in a row
  filter(Class == "Insecta", `Species Count` == insect_species_count_threshold, Score > insect_score_threshold, !str_detect(Sequence, paste(rep("R", too_many_Rs), collapse = ""))) %>%
  arrange(desc(Score)) %>%
  # take only the first X (30) insect sequences
  # some of these sequences could potentially be lost if they were also chosen in SpeciesCount
  # so the total of TopInsect could be lower than specified number of 30 
  head(n = num_insects) %>%
  mutate(`Prioritization Method` = "TopInsect")

cumsum <- ThreeEachClusterTSV %>%
  # remove sequences with TooManyRs
  filter(!str_detect(Sequence, paste(rep("R", too_many_Rs), collapse = ""))) %>%
  arrange(desc(Score)) %>%
  # Select only the Cluster column
  select(Cluster) %>%
  group_by(Cluster) %>%
  # Create a new column called 'members' indicating how many sequences are in that cluster
  mutate(members = n()) %>%
  # Remove duplicates
  unique() %>%
  # Ungroup because our cumulative sum shouldn't be per Cluster group
  ungroup() %>%
  # Create a new column for cumsum
  mutate(cumsum = cumsum(members))

ThreeEachClusterCumSum <- left_join(ThreeEachClusterTSV, cumsum, by = "Cluster") %>%
  arrange(desc(Score))

# Prioritize by top AMPlify score clusters ----
message(glue("Selecting {num_cluster_seqs} AMPs from top-scoring clusters."))
TopClusteredAMPlifyPrioritization <- ThreeEachClusterCumSum %>%
  # Pull out only the clusters that will make up the 30 top AMPlify score clusters
  filter(cumsum <= num_cluster_seqs) %>%
  # Remove members and cumsum columns since they've already been used for their purpose
  select(-c(members,cumsum)) %>%
  # Left join these top clusters of 30 total sequences with original dataframe
  # (essentially a column bind but safer)
  left_join(ThreeEachClusterTSV, by = c("Cluster", "Sequence", "Class", "Score", "Length", "Charge", "Species Count")) %>%
  # add column for Prioritization method
  mutate(`Prioritization Method` = "TopClusteredAMPlify")

CombinedTbl <- bind_rows(SpeciesCountPrioritization, TopInsectPrioritization, TopClusteredAMPlifyPrioritization) %>%
  # setting an order for our categories 1. SpeciesCount 2. TopInsect 3. TopClusteredAMPlify
  mutate(`Prioritization Method` = fct_relevel(`Prioritization Method`, "SpeciesCount", "TopInsect", "TopClusteredAMPlify")) %>%
  # Group by sequence, and arrange in prioritization method
  # e.g. if a sequence is chosen by SpeciesCount and TopInsect, the Prioritization Method will say "SpeciesCount"
  group_by(Sequence) %>%
  arrange(`Prioritization Method`) %>%
  # pick out the first instance for that duplicate sequence
  filter(row_number() == 1)

message(glue("Output: {output_file}"))
write_tsv(CombinedTbl, file = output_file)