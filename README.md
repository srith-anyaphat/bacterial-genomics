# Bacterial Genomics Workflows

Reproducible workflows for comparative and population genomics of bacterial
pathogens, developed for whole-genome sequencing studies of bovine mastitis
pathogens (*Streptococcus* and *Staphylococcus*) on a shared HPC cluster.

## Analyses in this repository

### [`pipeline/`](pipeline/): from raw reads to genome-level characterisation

| Step | What it does | Tools |
|---|---|---|
| Read QC and trimming | Quality reports, adapter and quality trimming | FastQC, Trimmomatic |
| Assembly and assembly QC | De novo assembly, contiguity and completeness checks, filtering of poor assemblies | SPAdes, QUAST |
| Taxonomic and species confirmation | Read- and assembly-level classification; species confirmation by average nucleotide identity to a reference | Kraken2, FastANI |
| Annotation | Gene prediction and functional annotation | Prokka |
| Pangenome | Core and accessory genome, gene presence/absence matrix | Roary |
| Phylogeny | Core-genome alignment and maximum-likelihood tree | IQ-TREE |
| AMR and virulence | Screening for antimicrobial resistance and virulence factor genes | ABRicate (CARD, ResFinder, VFDB) |
| Mobile genetic elements | Detection and summary of MGEs and their gene content | MGE detection + custom Python summary |

### [`pangwas/`](pangwas/): linking accessory genes to phenotype

| Step | What it does | Tools |
|---|---|---|
| Pangenome construction | Gene presence/absence across isolates | Roary, PanTools |
| Association testing | Pangenome-wide association accounting for population structure | treeWAS, pyseer |
| Multiple testing | False discovery rate correction of association results | Python |
| Follow-up | Gene extraction for phylogenetic analysis; tree and synteny visualisation | Python, Easyfig |

## Other experience (code private until publication)

Ongoing projects, with manuscripts in preparation, use the following approaches.
Code is available on request.

- **Prophages and integrases:** prophage detection and boundary refinement,
  attachment-site discovery, integrase typing, phage taxonomy and phylogeny
  (vclust, taxMyPhage, ANI- and protein-based trees)
- **Between-species sharing of mobile elements:** BLASTn/tBLASTx homology searches
  against multi-species reference databases with normalised homology scoring
- **CRISPR–phage interactions:** CRISPR array detection, spacer–protospacer mapping
  and linking spacer targets to prophage modules (MinCED)
- **Cargo gene analysis:** functional, metabolic, AMR and virulence genes carried by
  mobile elements; defence systems such as abortive infection
- **Genotyping:** cgMLST/wgMLST schemes and minimum spanning trees (chewBBACA, GrapeTree)
- **Comparative datasets and statistics:** automated retrieval and curation of public
  genomes and metadata (NCBI Datasets, Entrez, PubMLST), deduplication, ecological
  and geographic comparisons (Wilcoxon tests), interactive visualisation (Microreact)
- **Functional enrichment:** KEGG pathway enrichment across experimental groups
  (eggNOG-mapper, TBtools)

## Design principles

- **Plain, stepwise scripts.** Each step is a short bash, Python or R script with
  timestamped logging, so it can be read, rerun and debugged on a shared cluster.
- **Offline by default.** Tools run locally; no sequences are uploaded to public servers.
- **One conda environment per tool group.**
- **No hard-coded paths.** Paths and thread counts are set in a config file.

## Quick start

```bash
git clone https://github.com/srith-anyaphat/bacterial-genomics.git
cd bacterial-genomics
cp config/config.example.sh config/config.sh     # edit paths here
bash pipeline/main_pipeline.sh
```

## Development notes

Parts of this code were developed with the assistance of an AI coding tool
(Claude, Anthropic). In all cases I designed the analyses, chose the methods and
thresholds, ran and debugged the code on our HPC cluster, validated the outputs,
and interpreted the results.

## Author

**Anyaphat Srithanasuwan** · ORCID [0000-0003-2837-7187](https://orcid.org/0000-0003-2837-7187)

- Infectious Disease Epidemiology, Wageningen University, Wageningen, The Netherlands
- SYNGEN Co., Ltd., Chiang Mai, Thailand

## License

MIT, see [`LICENSE`](LICENSE).
