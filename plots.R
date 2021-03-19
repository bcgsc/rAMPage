#!/usr/bin/env Rscript
options(bitmapType='cairo')
args <- commandArgs(trailingOnly = TRUE)

if (length(args) != 4) {
  stop("USAGE: DESeq2-plots.R <path to DESeq results (treatmentvscontrol.RDS)> <txi.salmon.RDS> <path to AMPlify_results.tsv> <data_name>")
}

Deseqres <- readRDS(as.character(args[1]))
specific_dir <- basename(str_remove(args[1], "\\.rds"))
outdir <- file.path(dirname(as.character(args[1])),"plots",specific_dir)
dir.create(outdir, recursive = TRUE, showWarnings = FALSE)

# read the amplify results and only pick with score > 0.99 and positively charged
amp_csv <- read.table(as.character(args[3]),sep = "\t",header=TRUE)
amp_csv <- as.data.frame(amp_csv)
amp_csv <- filter(amp_csv,amp_csv$Score>0.90 & amp_csv$Charge>2 & amp_csv$Length <= 30)

# Plotting MA Plots to visualize the difference between two groups
suppressPackageStartupMessages(require(ggplot2))
suppressPackageStartupMessages(require(scales))
suppressPackageStartupMessages(require(ggnewscale))

# first argument is the DESeq results object

deseq2ResDF <- as.data.frame(Deseqres)
deseq2ResDF <- deseq2ResDF %>% drop_na()

# Set a column for whether a gene is for AMP
pattern <- sapply(strsplit(as.character(amp_csv$Sequence_ID), split='.', fixed=TRUE), function(x) (x[1]))
deseq2ResDF$Type <- ifelse(deseq2ResDF$Transcript_ID %in% pattern,"AMP",NA)
# Set a boolean column for significance

data_name <- ifelse(unlist(strsplit(as.character(args[3]), split='/', fixed=TRUE))[7] == "skin-alkaloid","Alkaloid Exposure on Skin","") 
data_name <- paste(args[4],data_name,sep=": ")
condition <- basename(as.character(args[1]))

condition <- (unlist(strsplit(as.character(condition), split='.', fixed=TRUE)))[1]
condition <- paste((unlist(strsplit(as.character(condition), split='_', fixed=TRUE)))[1],paste((unlist(strsplit(as.character(condition), split='_', fixed=TRUE)))[2], 
                   (unlist(strsplit(as.character(condition), split='_', fixed=TRUE)))[3], 
                   (unlist(strsplit(as.character(condition), split='_', fixed=TRUE)))[4],sep=" "),sep=": ")

deseq2ResDF$Significance <- ifelse(deseq2ResDF$padj < .01, "padj < 0.01", ifelse(deseq2ResDF$padj < 0.05, "0.01 < padj < 0.05", "padj > 0.05"))
deseq2ResDF$Significance <- factor(deseq2ResDF$Significance, levels = c("padj < 0.01","0.01 < padj < 0.05","padj > 0.05"))

maplot <- ggplot(deseq2ResDF, aes(x=baseMean, y=log2FoldChange, colour=Significance)) + geom_point(size=1) + 
  scale_y_continuous(limits=c(-40, 40), oob=squish) + scale_x_log10() + # scale_x_log10() squishes the x axis values to fit properly
  labs(x="mean of normalized counts", y="log2foldchange",title=data_name,subtitle=condition) + 
  scale_color_manual(values = c("#6490ff","#ffa8a8","#b57edc")) + new_scale_colour() +
  geom_point(aes(x=baseMean, y=log2FoldChange,color=Type),deseq2ResDF %>% filter(Type=="AMP"),shape=21,show.legend = TRUE) + 
  scale_color_manual(values = c("AMP" = "#3bffb1")) +
  theme(plot.title = element_text(hjust = 0.5,face="bold"),plot.subtitle = element_text(hjust = 0.5)) +
  geom_hline(yintercept = 0, colour="darkorchid4", size=1, linetype="dashed")  # yintercept of 0 indicates no change between control and treatment group

ggsave(paste(outdir,"maplot.png",sep="/"), maplot, units="in", height=4, width=9, dpi=300)

# Plotting heatmaps

# loading the required packages
suppressPackageStartupMessages(require(pheatmap))
suppressPackageStartupMessages(require(edgeR))
suppressPackageStartupMessages(require(dplyr))

# data matrix from the txi imports
txi.imports <- readRDS(as.character(args[2]))
TPM <- txi.imports$abundance

TPM <- data.frame(TPM, row.names = 1)
log2tpm <- log2(TPM+0.25)
tpm_data <- as.data.frame(log2tpm)

# Only plot the genes that are AMPs (as determined by score > 0.99 and positively charged)
tpmdata_amp <- filter(tpm_data,rownames(tpm_data)%in% pattern)

# Create pheatmap and save as a png
setwd(outdir)
getwd()
png(filename="pheatmap.png",width=4000, height=3000, pointsize=3000, units="px")
pheatmap(data.matrix(tpmdata_amp),fontsize=40,width=2,angle="45",show_rownames = FALSE,cluster_cols = FALSE)
dev.off()

# Plotting volcano plots 

# add -log(pvalue) column, and padj category
lfc_val <-2
lfc <- c(-lfc_val, lfc_val)

df_log <- mutate(deseq2ResDF, logp=-log10(pvalue)) 

upreg <- df_log %>% filter(padj<0.05 &  (log2FoldChange > 2) ) %>% nrow()
upreg_amp <- df_log %>% filter(padj<0.05 &  (log2FoldChange > 2) & Type =="AMP") %>% nrow()
dnreg <- df_log %>% filter(padj<0.05 &  (log2FoldChange < -2) ) %>% nrow()
dnreg_amp <- df_log %>% filter(padj<0.05 &  (log2FoldChange < -2) & Type =="AMP") %>% nrow()
same_amp <- df_log %>% filter(Type=="AMP" &  (log2FoldChange < 2 & log2FoldChange > -2) ) %>% nrow() 
same <- df_log %>% filter(log2FoldChange < 2 & log2FoldChange > -2) %>% nrow()


volcano_plot <- ggplot(df_log) + geom_point(aes(x=log2FoldChange,y=logp,color=Significance)) + 
  geom_vline(xintercept=lfc,linetype="dotted") + labs(title=data_name,subtitle=condition) + 
  scale_color_manual(values = c("#6490ff","#ffa8a8","#b57edc"))+
  ylab("-log(p-value)") + xlab("log2FoldChange") + new_scale_colour() +
  geom_point(aes(x=log2FoldChange,y=logp,color=Type),df_log %>% filter(Type=="AMP"),shape=21,show.legend = TRUE) + 
  scale_color_manual(values = c("AMP" = "#3bffb1")) + 
  theme(plot.title = element_text(hjust = 0.5,face="bold"),plot.subtitle = element_text(hjust = 0.5)) 

ylim = max(df_log$logp)
volcano_plot <- volcano_plot + geom_text(x=10,y=200,label=paste("Total: ", upreg))
volcano_plot <- volcano_plot + geom_text(x=10,y=150,label=paste("AMP: ", upreg_amp))
volcano_plot <- volcano_plot + geom_text(x=-10,y=200,label=paste("Total: ", dnreg))
volcano_plot <- volcano_plot + geom_text(x=-10,y=150,label=paste("AMP: ", dnreg_amp))

ggsave(paste(outdir,"volcano_plot.png",sep="/"), volcano_plot, units="in", height=4, width=9, dpi=300)


# To plot according to charge 
amp_results <- read.table(as.character(args[3]),sep = "\t",header=TRUE)
amp_results <- as.data.frame(amp_results)
max <- max(amp_results$Charge)
amp_results$Charge_Range <- ifelse(amp_results$Charge < 0, "-vely charged", ifelse(amp_results$Charge < 5, "0 < Charge < 5", 
                            ifelse(amp_results$Charge < 15, "5 < Charge < 15", paste("15 < Charge <",max,sep=" "))))
pattern_amp <- sapply(strsplit(as.character(amp_results$Sequence_ID), split='.', fixed=TRUE), function(x) (x[1]))
deseq2ResDF$Charge_Range <- ifelse(deseq2ResDF$Transcript_ID %in% pattern_amp,amp_results$Charge_Range,NA)
deseq2ResDF$Charge_Range <- factor(deseq2ResDF$Charge_Range, levels = c(paste("15 < Charge <",max,sep=" "),"5 < Charge < 15","0 < Charge < 5","-vely charged"))
df_log <- mutate(deseq2ResDF, logp=-log10(pvalue)) 

volcano_charge_plot <- ggplot(df_log) + geom_point(aes(x=log2FoldChange,y=logp,color=Significance)) + 
  geom_vline(xintercept=lfc,linetype="dotted") + labs(title=data_name,subtitle=condition) + 
  scale_color_manual(values = c("#c1d5e0","#455a64","#1c313a")) +
  ylab("-log(p-value)") + xlab("log2FoldChange") + new_scale_colour() +
  geom_point(aes(x=log2FoldChange,y=logp,color=Charge_Range),df_log %>% filter(Charge_Range !="NA"),shape=21,show.legend = TRUE) + 
  scale_color_manual(values = c("#70fc83","#fce835","#fc704d","#b4041a")) + 
  theme(plot.title = element_text(hjust = 0.5,face="bold"),plot.subtitle = element_text(hjust = 0.5)) 

ggsave(paste(outdir,"volcano_charge_plot.png",sep="/"), volcano_charge_plot, units="in", height=4, width=9, dpi=300)


# To plot according to AMPlify score 

amp_results$AMPlify_Score <- ifelse(amp_results$Score < 0.5, "score < 0.5", ifelse(amp_results$Score < 0.7, "0.5 < score < 0.7", 
                             ifelse(amp_results$Score < 0.8, "0.7 < score < 0.8", ifelse(amp_results$Score < 0.9, "0.8 < score < 0.9",
                             ifelse(amp_results$Score < 0.99, "0.9 < score < 0.99","0.99 < score < 1")))))
df_log$AMPlify_Score <- ifelse(df_log$Transcript_ID %in% pattern_amp,amp_results$AMPlify_Score,NA)
df_log$AMPlify_Score <- factor(df_log$AMPlify_Score , levels = c("0.99 < score < 1","0.9 < score < 0.99","0.8 < score < 0.9","0.7 < score < 0.8", "0.5 < score < 0.7","score < 0.5"))

volcano_score_plot <- ggplot(df_log) + geom_point(aes(x=log2FoldChange,y=logp,color=Significance)) + 
  geom_vline(xintercept=lfc,linetype="dotted") + labs(title=data_name,subtitle=condition) + 
  scale_color_manual(values = c("#c1d5e0","#455a64","#1c313a")) +
  ylab("-log(p-value)") + xlab("log2FoldChange") + new_scale_colour() +
  geom_point(aes(x=log2FoldChange,y=logp,color=AMPlify_Score),df_log %>% filter(AMPlify_Score !="NA"),shape=21,show.legend = TRUE) + 
  scale_color_manual(values = c("#c795ff","#ff96b9","#fc704d","#ff64ce","#e267ff","#8c00cb")) + 
  theme(plot.title = element_text(hjust = 0.5,face="bold"),plot.subtitle = element_text(hjust = 0.5)) 

ggsave(paste(outdir,"volcano_score_plot.png",sep="/"), volcano_score_plot, units="in", height=4, width=9, dpi=300)

# To generate files with upregulated and downregulated AMPs

upamp <- deseq2ResDF %>% filter(Type == "AMP" & log2FoldChange > 2 & padj < 0.05)
amp_csv$upreg <- ifelse(pattern %in% upamp$Transcript_ID,"upreg",NA)
upreg <- amp_csv %>% filter(upreg == "upreg")

downamp <- deseq2ResDF %>% filter(Type == "AMP" & log2FoldChange < -2 & padj < 0.05)
amp_csv$downreg <- ifelse(pattern %in% downamp$Transcript_ID,"downreg",NA)
downreg <- amp_csv %>% filter(downreg == "downreg")

suppressPackageStartupMessages(require("seqRFLP"))

upnames <- upreg$Sequence_ID
upsequences<-upreg$Sequence
df <- data.frame(upnames,upsequences)
df.fasta = dataframe2fas(df,paste(outdir,"upregulated_amps.faa",sep="/"))

downnames <- upreg$Sequence_ID
downsequences<-upreg$Sequence
df2 <- data.frame(downnames,downsequences)
df2.fasta = dataframe2fas(df2paste(outdir,"downregulated_amps.faa",sep="/"))

