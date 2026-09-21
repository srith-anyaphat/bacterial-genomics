#!/usr/bin/env python3
"""
FDR (False Discovery Rate) correction for pyseer results
Uses Benjamini-Hochberg method
Run with: python3 fdr_correction.py
"""

import pandas as pd
from statsmodels.stats.multitest import multipletests

print("=== FDR Correction Analysis ===\n")

# Read pyseer results
print("Reading gwas_covarite.txt...")
results = pd.read_csv('gwas_covarite.txt', sep='\t')

print(f"Total genes tested: {len(results)}\n")

# Apply FDR correction (Benjamini-Hochberg)
print("Applying FDR correction (Benjamini-Hochberg method)...")
fdr_results = multipletests(results['lrt-pvalue'], method='fdr_bh')
results['fdr_significant'] = fdr_results[0]
results['fdr_pvalue'] = fdr_results[1]

# Calculate Bonferroni for comparison
bonf_threshold = 0.05 / len(results)
results['bonf_significant'] = results['lrt-pvalue'] < bonf_threshold

# Count significant genes
n_fdr = results['fdr_significant'].sum()
n_bonf = results['bonf_significant'].sum()

print(f"\n=== Results Summary ===")
print(f"Bonferroni threshold: {bonf_threshold:.2e}")
print(f"Significant genes:")
print(f"  - Bonferroni (α=0.05): {n_bonf}")
print(f"  - FDR (q<0.05):        {n_fdr}")

# Save all results with corrections
results_sorted = results.sort_values('lrt-pvalue')
results_sorted.to_csv('gwas_with_fdr_and_bonferroni.txt', sep='\t', index=False)
print(f"\n✓ Saved: gwas_with_fdr_and_bonferroni.txt")

# Save only FDR-significant genes
if n_fdr > 0:
    fdr_sig = results_sorted[results_sorted['fdr_significant']].copy()
    fdr_sig.to_csv('significant_genes_fdr.txt', sep='\t', index=False)
    print(f"✓ Saved: significant_genes_fdr.txt ({n_fdr} genes)")
    
    print(f"\n=== Top 20 FDR-Significant Genes ===")
    print(fdr_sig[['variant', 'lrt-pvalue', 'fdr_pvalue']].head(20).to_string(index=False))
else:
    print("\n⚠️  No genes passed FDR correction (q<0.05)")
    print("Showing top 20 genes by p-value:")
    print(results_sorted[['variant', 'lrt-pvalue', 'fdr_pvalue']].head(20).to_string(index=False))

# Save only Bonferroni-significant genes
if n_bonf > 0:
    bonf_sig = results_sorted[results_sorted['bonf_significant']].copy()
    bonf_sig.to_csv('significant_genes_bonferroni.txt', sep='\t', index=False)
    print(f"\n✓ Saved: significant_genes_bonferroni.txt ({n_bonf} genes)")

# Additional statistics
print(f"\n=== P-value Distribution ===")
print(f"Minimum p-value: {results['lrt-pvalue'].min():.2e}")
print(f"Genes with p < 0.001: {(results['lrt-pvalue'] < 0.001).sum()}")
print(f"Genes with p < 0.01:  {(results['lrt-pvalue'] < 0.01).sum()}")
print(f"Genes with p < 0.05:  {(results['lrt-pvalue'] < 0.05).sum()}")

# Overlap between methods
if n_fdr > 0 and n_bonf > 0:
    overlap = (results['fdr_significant'] & results['bonf_significant']).sum()
    fdr_only = (results['fdr_significant'] & ~results['bonf_significant']).sum()
    print(f"\n=== Method Overlap ===")
    print(f"Significant by both methods: {overlap}")
    print(f"FDR only (not Bonferroni):   {fdr_only}")

print("\n=== Analysis Complete ===")
print("Use FDR results for publication (more appropriate for bacterial GWAS)")
print("Bonferroni results represent highest-confidence associations")
