#!/usr/bin/env python3
###############################################################################
#  summarize_mge.py
#  Summarize MGE results from PhiSpy, ISEScan, and PlasmidFinder
#
#  Usage: python3 summarize_mge.py
#  Output: ${PROJECT_ROOT}/japan/14_mge/mge_summary.tsv
###############################################################################

import os
import re
import csv

# ── Paths ─────────────────────────────────────────────────────────────────────
MGE_DIR   = "${PROJECT_ROOT}/japan/14_mge"
PASS_FILE = "${PROJECT_ROOT}/japan/10_fastani/samples_pass_hq.txt"
OUT_FILE  = f"{MGE_DIR}/mge_summary.tsv"

# ── Load HQ sample list ───────────────────────────────────────────────────────
with open(PASS_FILE) as f:
    samples = [s.strip() for s in f if s.strip()]

print(f"Summarizing MGE results for {len(samples)} HQ samples...")

results = []

for sample in samples:
    row = {"Sample": sample}

    # ── PhiSpy ────────────────────────────────────────────────────────────────
    phispy_dir = f"{MGE_DIR}/prophages/{sample}"
    coord_file = f"{phispy_dir}/prophage_coordinates.tsv"
    info_file  = f"{phispy_dir}/prophage_information.tsv"

    if os.path.exists(coord_file):
        with open(coord_file) as f:
            prophages = [l for l in f if l.strip() and not l.startswith("#")]
        n_prophage = len(prophages)
        total_len = 0
        for line in prophages:
            parts = line.strip().split("\t")
            try:
                total_len += int(parts[2]) - int(parts[1])
            except (IndexError, ValueError):
                pass
        row["Prophage_count"]      = n_prophage
        row["Prophage_total_bp"]   = total_len
    else:
        row["Prophage_count"]      = "NA"
        row["Prophage_total_bp"]   = "NA"

    # ── ISEScan ───────────────────────────────────────────────────────────────
    ise_dir = f"{MGE_DIR}/isescan/{sample}"
    # ISEScan outputs a summary CSV in the output dir
    ise_summary = None
    if os.path.exists(ise_dir):
        for f in os.listdir(ise_dir):
            if f.endswith(".sum"):
                ise_summary = f"{ise_dir}/{f}"
                break
        # Also check for .tsv or .csv
        if not ise_summary:
            for f in os.listdir(ise_dir):
                if "is.tsv" in f or "prediction" in f:
                    ise_summary = f"{ise_dir}/{f}"
                    break

    if ise_summary and os.path.exists(ise_summary):
        with open(ise_summary) as f:
            lines = [l for l in f if l.strip() and not l.startswith("#")]
        row["IS_count"] = len(lines)
        # Extract IS families
        families = set()
        for line in lines:
            parts = line.split("\t")
            if len(parts) > 2:
                families.add(parts[2] if parts[2] else "unknown")
        row["IS_families"] = ";".join(sorted(families)) if families else "none"
    else:
        # Try the prediction file directly
        pred_dir = f"{ise_dir}/prediction"
        if os.path.exists(pred_dir):
            is_files = [f for f in os.listdir(pred_dir) if f.endswith(".is")]
            row["IS_count"]    = len(is_files)
            row["IS_families"] = "see output"
        else:
            row["IS_count"]    = "NA"
            row["IS_families"] = "NA"

    # ── PlasmidFinder ─────────────────────────────────────────────────────────
    plas_dir    = f"{MGE_DIR}/plasmids/{sample}"
    plas_result = f"{plas_dir}/results_tab.tsv"

    if os.path.exists(plas_result):
        with open(plas_result) as f:
            reader = csv.DictReader(f, delimiter="\t")
            hits = []
            for r in reader:
                plasmid = r.get("Plasmid", r.get("plasmid", ""))
                identity = r.get("Identity", r.get("identity", ""))
                if plasmid:
                    hits.append(f"{plasmid}({identity}%)")
        row["Plasmid_count"]    = len(hits)
        row["Plasmid_replicons"] = ";".join(hits) if hits else "none"
    else:
        row["Plasmid_count"]    = "NA"
        row["Plasmid_replicons"] = "NA"

    results.append(row)
    print(f"  {sample}: prophages={row['Prophage_count']}  IS={row['IS_count']}  plasmids={row['Plasmid_count']}")

# ── Write summary TSV ─────────────────────────────────────────────────────────
fieldnames = [
    "Sample",
    "Prophage_count", "Prophage_total_bp",
    "IS_count", "IS_families",
    "Plasmid_count", "Plasmid_replicons"
]

with open(OUT_FILE, "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=fieldnames, delimiter="\t")
    writer.writeheader()
    writer.writerows(results)

print(f"\nSummary written to: {OUT_FILE}")

# ── Print quick stats ─────────────────────────────────────────────────────────
numeric = lambda x: isinstance(x, int) or (isinstance(x, str) and x.isdigit())

prophage_counts = [int(r["Prophage_count"]) for r in results if numeric(r["Prophage_count"])]
is_counts       = [int(r["IS_count"])       for r in results if numeric(r["IS_count"])]
plasmid_counts  = [int(r["Plasmid_count"])  for r in results if numeric(r["Plasmid_count"])]

print("\n════════════════════════════════════════")
print(f"Samples with ≥1 prophage:  {sum(1 for x in prophage_counts if x > 0)}/{len(prophage_counts)}")
print(f"Mean prophages per sample: {sum(prophage_counts)/len(prophage_counts):.1f}" if prophage_counts else "N/A")
print(f"Samples with ≥1 IS element:{sum(1 for x in is_counts if x > 0)}/{len(is_counts)}")
print(f"Mean IS elements per sample:{sum(is_counts)/len(is_counts):.1f}" if is_counts else "N/A")
print(f"Samples with ≥1 plasmid:   {sum(1 for x in plasmid_counts if x > 0)}/{len(plasmid_counts)}")
print("════════════════════════════════════════")
