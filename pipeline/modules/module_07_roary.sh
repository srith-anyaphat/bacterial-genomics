#!/bin/bash
###############################################################################
#  module_07_roary.sh
#  Pangenome analysis of 62 confirmed S. chromogenes using Roary
#
#  Input:  GFF files from Prokka (08_annotation/)
#  Output: 11_roary/ — pangenome results, core gene alignment
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/env_setup.sh"

mkdir -p "${DIR_LOGS}"
LOG_FILE="${DIR_LOGS}/07_roary_$(date '+%Y%m%d_%H%M%S').log"

PASS_LIST="${PROJECT_ROOT}/japan/10_fastani/samples_pass.txt"
ANNOTATION="${PROJECT_ROOT}/japan/08_annotation"
OUT_DIR="${PROJECT_ROOT}/japan/11_roary"
ENV="${PROJECT_ROOT}/miniconda3/envs/roary_env"
THREADS=16
IDENTITY=95     # minimum BLAST identity for core gene clustering

main() {
    log_step "MODULE 07: Roary pangenome analysis"
    log_info "Samples: $(wc -l < $PASS_LIST)"
    log_info "Identity threshold: ${IDENTITY}%"

    mkdir -p "$OUT_DIR"

    # Collect GFF files for all passing samples
    local gff_files=()
    while IFS= read -r sample; do
        local gff="${ANNOTATION}/${sample}/${sample}.gff"
        if [[ -f "$gff" ]]; then
            gff_files+=("$gff")
        else
            log_warn "  GFF not found: $sample — skipping"
        fi
    done < "$PASS_LIST"

    log_info "GFF files found: ${#gff_files[@]}"

    if [[ ${#gff_files[@]} -lt 3 ]]; then
        log_error "Need at least 3 samples for pangenome analysis"
        exit 1
    fi

    # Run Roary
    log_step "Running Roary..."
    run_in_env "Roary" "$ENV" \
        roary \
            -f "$OUT_DIR" \
            -e \
            -n \
            -i "$IDENTITY" \
            -p "$THREADS" \
            -r \
            -v \
            "${gff_files[@]}"

    # Summary stats
    log_step "Pangenome summary"
    if [[ -f "${OUT_DIR}/summary_statistics.txt" ]]; then
        cat "${OUT_DIR}/summary_statistics.txt" | tee -a "$LOG_FILE"
    fi

    log_info "Core genome alignment: ${OUT_DIR}/core_gene_alignment.aln"
    log_info "Gene presence/absence: ${OUT_DIR}/gene_presence_absence.csv"
    log_step "MODULE 07 complete ✓"
}

main "$@"
