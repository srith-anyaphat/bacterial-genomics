#!/bin/bash

# Complete workflow for Ess operon extraction and analysis
# Usage: ./run_complete_workflow.sh

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║     Ess Operon Extraction and Analysis - Complete Workflow    ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# File paths
GFF_LIST="gff99.txt"
FNA_LIST="genome99.txt"

# Check if files exist
if [ ! -f "$GFF_LIST" ]; then
    echo "Error: GFF list not found at $GFF_LIST"
    exit 1
fi

if [ ! -f "$FNA_LIST" ]; then
    echo "Error: FNA list not found at $FNA_LIST"
    exit 1
fi

echo "Found file lists:"
echo "  GFF list: $GFF_LIST ($(wc -l < $GFF_LIST) files)"
echo "  FNA list: $FNA_LIST ($(wc -l < $FNA_LIST) files)"
echo ""

# Step 1: Extract Ess operons
echo "════════════════════════════════════════════════════════════════"
echo "STEP 1: Extracting Ess operons from all samples"
echo "════════════════════════════════════════════════════════════════"
python3 extract_ess_paired_lists.py "$GFF_LIST" "$FNA_LIST"

if [ ! -d "easyfig_files" ]; then
    echo ""
    echo "Error: Extraction failed! No easyfig_files directory created."
    exit 1
fi

echo ""

# Step 2: Prepare for EasyFig
echo "════════════════════════════════════════════════════════════════"
echo "STEP 2: Preparing BLAST databases for EasyFig"
echo "════════════════════════════════════════════════════════════════"
./prepare_for_easyfig.sh

echo ""

# Step 3: Extract genes and build phylogenies
echo "════════════════════════════════════════════════════════════════"
echo "STEP 3: Extracting genes and building phylogenies"
echo "════════════════════════════════════════════════════════════════"
./extract_genes_for_phylogeny.sh

echo ""

# Step 4: Summary
echo "════════════════════════════════════════════════════════════════"
echo "STEP 4: Summary of Results"
echo "════════════════════════════════════════════════════════════════"

gbk_count=$(ls -1 easyfig_files/*.gbk 2>/dev/null | wc -l)
tree_count=$(ls -1 phylogeny_genes/*.treefile 2>/dev/null | wc -l)

echo ""
echo "RESULTS:"
echo "--------"
echo "✓ GenBank files created: $gbk_count"
echo "✓ Phylogenetic trees: $tree_count"
echo ""
echo "OUTPUT DIRECTORIES:"
echo "-------------------"
echo "  easyfig_files/      - GenBank files ready for EasyFig"
echo "  phylogeny_genes/    - Gene sequences and phylogenetic trees"
echo ""
echo "DOWNLOAD FILES:"
echo "---------------"
echo "  easyfig_files.tar.gz    - Compressed archive for Windows"
echo "  easyfig_files.zip       - ZIP archive for Windows"
echo ""

# Display extraction summary
if [ -f "easyfig_files/EXTRACTION_SUMMARY.txt" ]; then
    echo "EXTRACTION SUMMARY:"
    echo "-------------------"
    head -20 easyfig_files/EXTRACTION_SUMMARY.txt
    echo ""
    echo "Full summary: easyfig_files/EXTRACTION_SUMMARY.txt"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    WORKFLOW COMPLETE!                          ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "NEXT STEPS:"
echo "-----------"
echo "1. Download: easyfig_files.tar.gz or easyfig_files.zip"
echo "2. Transfer to Windows computer"
echo "3. Extract the archive"
echo "4. Open EasyFig and load .gbk files"
echo "5. Follow instructions in EASYFIG_INSTRUCTIONS.txt"
echo ""

