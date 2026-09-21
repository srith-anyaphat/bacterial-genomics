#!/bin/bash
###############################################################################
#  module_09_abricate.sh
#  Screen 62 S. chromogenes assemblies for AMR and virulence genes
#
#  Databases:
#    - CARD    — antimicrobial resistance genes
#    - VFDB    — virulence factor genes
#    - ResFinder — resistance genes (complementary to CARD)
#
#  Input:  contigs.fasta from SPAdes (06_assembly/)
#  Output: 13_abricate/ — per-sample and summary results
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/env_setup.sh"

mkdir -p "${DIR_LOGS}"
LOG_FILE="${DIR_LOGS}/09_abricate_$(date '+%Y%m%d_%H%M%S').log"

PASS_LIST="${PROJECT_ROOT}/japan/10_fastani/samples_pass.txt"
ASSEMBLY="${PROJECT_ROOT}/japan/06_assembly"
OUT_DIR="${PROJECT_ROOT}/japan/13_abricate"
ENV="${PROJECT_ROOT}/miniconda3/envs/abricate"
THREADS=8
MIN_COVERAGE=80   # minimum gene coverage %
MIN_IDENTITY=90   # minimum nucleotide identity %

# Databases to screen
DATABASES=(card vfdb resfinder)

main() {
    log_step "MODULE 09: ABRicate — AMR & virulence gene screening"
    log_info "Databases: ${DATABASES[*]}"
    log_info "Min coverage: ${MIN_COVERAGE}%  Min identity: ${MIN_IDENTITY}%"

    mkdir -p "$OUT_DIR"

    # Collect contig files
    local contigs=()
    while IFS= read -r sample; do
        local ctg="${ASSEMBLY}/${sample}/contigs.fasta"
        [[ -f "$ctg" ]] && contigs+=("$ctg") || log_warn "  No contigs: $sample"
    done < "$PASS_LIST"
    log_info "Assemblies found: ${#contigs[@]}"

    # Run each database
    for db in "${DATABASES[@]}"; do
        log_step "Screening: $db"
        local db_out="${OUT_DIR}/${db}"
        mkdir -p "$db_out"

        # Per-sample results
        local count=0
        for ctg in "${contigs[@]}"; do
            ((count++))
            local sample; sample=$(basename "$(dirname "$ctg")")
            local result="${db_out}/${sample}_${db}.tab"

            [[ -f "$result" ]] && { log_info "  SKIP $sample (done)"; continue; }

            run_in_env "ABRicate ${db} ${sample}" "$ENV" \
                abricate \
                    --db "$db" \
                    --minco "$MIN_COVERAGE" \
                    --minid "$MIN_IDENTITY" \
                    --threads "$THREADS" \
                    "$ctg" \
                > "$result" 2>> "$LOG_FILE" \
            && log_info "  [$count/${#contigs[@]}] $sample ✓" \
            || log_warn "  [$count/${#contigs[@]}] $sample FAIL"
        done

        # Summary table across all samples
        log_info "Generating ${db} summary..."
        run_in_env "ABRicate summary ${db}" "$ENV" \
            abricate --summary "${db_out}"/*.tab \
            > "${OUT_DIR}/${db}_summary.tab" 2>> "$LOG_FILE"

        local n_hits; n_hits=$(wc -l < "${OUT_DIR}/${db}_summary.tab")
        log_info "  ${db} summary: ${OUT_DIR}/${db}_summary.tab (${n_hits} lines)"
    done

    # Combined report
    log_step "Generating combined report"
    {
        echo "=== CARD (AMR) ==="
        cat "${OUT_DIR}/card_summary.tab" 2>/dev/null || echo "not found"
        echo ""
        echo "=== VFDB (Virulence) ==="
        cat "${OUT_DIR}/vfdb_summary.tab" 2>/dev/null || echo "not found"
        echo ""
        echo "=== ResFinder (AMR) ==="
        cat "${OUT_DIR}/resfinder_summary.tab" 2>/dev/null || echo "not found"
    } > "${OUT_DIR}/combined_report.txt"

    log_info "Combined report: ${OUT_DIR}/combined_report.txt"
    log_step "MODULE 09 complete ✓"
}

main "$@"
