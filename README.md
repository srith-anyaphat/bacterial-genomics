# Bacterial Evolutionary Genomics Workflows

Reproducible workflows for comparative, population and evolutionary genomics of
bacterial pathogens: from raw reads to pangenomes, phylogenies, pangenome-wide
association, mobile genetic elements, and the gain and loss of antimicrobial
resistance (AMR) genes along bacterial phylogenies.

Developed for whole-genome sequencing studies of bovine mastitis pathogens
(*Streptococcus* and *Staphylococcus*) on a shared HPC cluster.

<!-- TODO: add docs/overview.png from amr_gain_loss/ (tree + AMR heatmap + gain/loss events) -->

## Contents

| Folder | What it does | Main tools |
|---|---|---|
| [`pipeline/`](pipeline/) | Modular WGS pipeline: read QC, trimming, assembly, assembly QC, species confirmation, annotation, pangenome, phylogeny, AMR/virulence screening, MGE detection | Trimmomatic, SPAdes, QUAST, Kraken2, FastANI, Prokka, Roary, IQ-TREE, ABRicate |
| [`pangwas/`](pangwas/) | Pangenome-wide association accounting for population structure, followed by multiple-testing correction and extraction of candidate genes for phylogenetic and synteny analysis | Roary, PanTools, treeWAS, pyseer, Easyfig |
| [`amr_gain_loss/`](amr_gain_loss/) | Case study on public *Streptococcus suis* genomes: reconstructs the gain and loss of AMR genes on a recombination-aware phylogeny and asks whether gained genes are carried by mobile elements | Panaroo, Gubbins, IQ-TREE, AMRFinderPlus, ancestral state reconstruction |

<!-- TODO: remove the amr_gain_loss row if it is not finished before the repo goes public -->

## Design principles

- **Plain, stepwise scripts.** Each step is a short bash, Python or R script with
  timestamped logging, so it can be read, rerun and debugged on a shared cluster.
- **Offline by default.** Tools run locally; no sequences are uploaded to public servers.
- **One conda environment per tool group**, listed in `envs/`.
- **No hard-coded paths.** Paths and thread counts are set in a config file.

## Quick start

```bash
git clone https://github.com/srith-anyaphat/bacterial-genomics.git
cd bacterial-genomics
cp config/config.example.sh config/config.sh     # edit paths here
bash pipeline/main_pipeline.sh
```

Each folder has its own README describing inputs, outputs and how to run it.

## Ongoing work

Code for ongoing projects on prophage integrase diversity, CRISPR–phage
interactions and between-species sharing of mobile elements in *Streptococcus*
(manuscripts in preparation) is kept private until publication and is available
on request.

## Development notes

<!-- TODO: adjust so it matches which parts you wrote yourself -->
The `pipeline/` modules were written by me. Later analyses were developed with the
assistance of an AI coding tool (Claude, Anthropic). In all cases I designed the
analyses, chose the methods and thresholds, ran and debugged the code on our HPC
cluster, validated the outputs, and interpreted the results.

## Author

<!-- TODO: name, affiliation, ORCID, contact -->

## License

MIT, see [`LICENSE`](LICENSE).
