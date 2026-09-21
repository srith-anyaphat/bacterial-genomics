#!/bin/bash
###############################################################################
#  module_10_mge.sh
#  Mobile genetic element (MGE) detection
#  Tools: PhiSpy (prophages), ISEScan (IS elements), PlasmidFinder (plasmids)
#
#  Usage:
#    bash module_10_mge.sh              # run all 3 tools on all HQ samples
#    bash module_10_mge.sh --phispy     # run PhiSpy only
#    bash module_10_mge.sh --isescan    # run ISEScan only
#    bash module_10_mge.sh --plasmid    # run PlasmidFinder only
###############################################################################

# ── Paths ─────────────────────────────────────────────────────────────────────
ASSEMBLY="${PROJECT_ROOT}/japan/06_assembly"
ANNOTATION="${PROJECT_ROOT}/japan/08_annotation"
OUT="${PROJECT_ROOT}/japan/14_mge"
PASS="${PROJECT_ROOT}/japan/10_fastani/samples_pass_hq.txt"
LOG="${PROJECT_ROOT}/japan/logs/10_mge_$(date '+%Y%m%d_%H%M%S').log"

# ── Conda environments ────────────────────────────────────────────────────────
CONDA="${PROJECT_ROOT}/miniconda3/bin/conda"
ENV_PHISPY="${PROJECT_ROOT}/miniconda3/envs/phispy"
ENV_ISESCAN="${PROJECT_ROOT}/miniconda3/envs/isescan"
ENV_PLASMID="${PROJECT_ROOT}/miniconda3/envs/plasmidfinder"

# ── Tool settings ─────────────────────────────────────────────────────────────
THREADS=8
PLASMID_DB="gram_positive"
PLASMID_MIN_COV=0.60
PLASMID_MIN_ID=0.90

# ── Parse arguments ───────────────────────────────────────────────────────────
RUN_PHISPY=1
RUN_ISESCAN=1
RUN_PLASMID=1

if [[ $# -gt 0 ]]; then
    RUN_PHISPY=0; RUN_ISESCAN=0; RUN_PLASMID=0
    for arg in "$@"; do
        case "$arg" in
            --phispy)  RUN_PHISPY=1 ;;
            --isescan) RUN_ISESCAN=1 ;;
            --plasmid) RUN_PLASMID=1 ;;
            *) echo "Unknown option: $arg"; exit 1 ;;
        esac
    done
fi

# ── Setup ─────────────────────────────────────────────────────────────────────
mkdir -p "${OUT}/prophages" "${OUT}/isescan" "${OUT}/plasmids" \
         "$(dirname "$LOG")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG"; }

log "════════════════════════════════════════"
log "MODULE 10: MGE detection"
log "Samples: $(wc -l < "$PASS")"
log "PhiSpy:        $([ $RUN_PHISPY  -eq 1 ] && echo ON || echo OFF)"
log "ISEScan:       $([ $RUN_ISESCAN -eq 1 ] && echo ON || echo OFF)"
log "PlasmidFinder: $([ $RUN_PLASMID -eq 1 ] && echo ON || echo OFF)"
log "Log: $LOG"
log "════════════════════════════════════════"

ok=0; fail=0; skip=0

while IFS= read -r sample; do
    log "── $sample ──"

    # ── PhiSpy ────────────────────────────────────────────────────────────────
    if [[ $RUN_PHISPY -eq 1 ]]; then
        gbk="${ANNOTATION}/${sample}/${sample}.gbk"
        out_dir="${OUT}/prophages/${sample}"

        if [[ -d "$out_dir" ]]; then
            log "  PhiSpy SKIP (already done)"; ((skip++))
        elif [[ ! -f "$gbk" ]]; then
            log "  PhiSpy SKIP (no GBK file)"; ((skip++))
        else
            log "  PhiSpy running..."
            mkdir -p "$out_dir"
            "$CONDA" run -p "$ENV_PHISPY" \
                phispy "$gbk" -o "$out_dir" \
                    --output_choice 13 --threads "$THREADS" \
                >> "$LOG" 2>&1 \
            && { log "  PhiSpy DONE"; ((ok++)); } \
            || { log "  PhiSpy FAIL"; ((fail++)); rm -rf "$out_dir"; }
        fi
    fi

    # ── ISEScan ───────────────────────────────────────────────────────────────
    if [[ $RUN_ISESCAN -eq 1 ]]; then
        ctg="${ASSEMBLY}/${sample}/contigs.fasta"
        out_dir="${OUT}/isescan/${sample}"

        if [[ -d "$out_dir" ]]; then
            log "  ISEScan SKIP (already done)"; ((skip++))
        elif [[ ! -f "$ctg" ]]; then
            log "  ISEScan SKIP (no contigs)"; ((skip++))
        else
            log "  ISEScan running..."
            mkdir -p "$out_dir"
            "$CONDA" run -p "$ENV_ISESCAN" \
                isescan.py --seqfile "$ctg" \
                    --output "$out_dir" --nthread "$THREADS" \
                >> "$LOG" 2>&1 \
            && { log "  ISEScan DONE"; ((ok++)); } \
            || { log "  ISEScan FAIL"; ((fail++)); }
        fi
    fi

    # ── PlasmidFinder ─────────────────────────────────────────────────────────
    if [[ $RUN_PLASMID -eq 1 ]]; then
        ctg="${ASSEMBLY}/${sample}/contigs.fasta"
        out_dir="${OUT}/plasmids/${sample}"

        if [[ -d "$out_dir" ]]; then
            log "  PlasmidFinder SKIP (already done)"; ((skip++))
        elif [[ ! -f "$ctg" ]]; then
            log "  PlasmidFinder SKIP (no contigs)"; ((skip++))
        else
            log "  PlasmidFinder running..."
            mkdir -p "$out_dir"
            "$CONDA" run -p "$ENV_PLASMID" \
                plasmidfinder.py -i "$ctg" -o "$out_dir" \
                    -p ${PROJECT_ROOT}/miniconda3/envs/plasmidfinder/share/plasmidfinder-2.1.6/database -l "$PLASMID_MIN_COV" -t "$PLASMID_MIN_ID" \
                >> "$LOG" 2>&1 || true
            log "  PlasmidFinder DONE"; ((ok++))
        fi
    fi

done < "$PASS"

# ── Summary ───────────────────────────────────────────────────────────────────
log "════════════════════════════════════════"
log "Done:    $ok"
log "Failed:  $fail"
log "Skipped: $skip"
log "Log:     $LOG"
log "MODULE 10 complete ✓"
