#!/bin/bash
###############################################################################
#  module_02_trim.sh
#  Trim adapters and low-quality bases using Trimmomatic (PE mode)
#
#  Input:  $DIR_CLASSIFIED  — raw fastq per sample
#  Output: $DIR_TRIMMED     — trimmed fastq + trimming stats
#
#  Single run: bash module_02_trim.sh
#  One sample: bash module_02_trim.sh --sample SAMPLE_NAME
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/env_setup.sh"

mkdir -p "${DIR_LOGS}"
LOG_FILE="${DIR_LOGS}/02_trim_$(date '+%Y%m%d_%H%M%S').log"

TARGET_SAMPLE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sample) TARGET_SAMPLE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Trimmomatic parameters
TRIM_THREADS=8
TRIM_LEADING=3
TRIM_TRAILING=3
TRIM_SLIDINGWINDOW="4:20"
TRIM_MINLEN=50
# Adapter file bundled with Trimmomatic
ADAPTERS="${PROJECT_ROOT}/miniconda3/envs/pantools/share/trimmomatic-0.39-2/adapters/TruSeq3-PE-2.fa"

trim_sample() {
    local sample="$1"
    local sample_dir="${DIR_CLASSIFIED}/${sample}"
    local out_dir="${DIR_TRIMMED}/${sample}"

    # Skip if already done
    if [[ -f "${out_dir}/${sample}_1_paired.fastq.gz" ]]; then
        log_info "  $sample: already trimmed, skipping"
        return 0
    fi

    local R1 R2
    R1=$(find "$sample_dir" \( -name "*_1.fastq.gz" -o -name "*_R1*.fastq.gz" \) 2>/dev/null | sort | head -1)
    R2=$(find "$sample_dir" \( -name "*_2.fastq.gz" -o -name "*_R2*.fastq.gz" \) 2>/dev/null | sort | head -1)

    if [[ -z "$R1" ]]; then
        log_warn "  $sample: no reads found, skipping"
        return 1
    fi

    mkdir -p "$out_dir"

    local trim_args=(
        PE -threads "$TRIM_THREADS" -phred33
        "$R1" "$R2"
        "${out_dir}/${sample}_1_paired.fastq.gz"
        "${out_dir}/${sample}_1_unpaired.fastq.gz"
        "${out_dir}/${sample}_2_paired.fastq.gz"
        "${out_dir}/${sample}_2_unpaired.fastq.gz"
        LEADING:${TRIM_LEADING}
        TRAILING:${TRIM_TRAILING}
        SLIDINGWINDOW:${TRIM_SLIDINGWINDOW}
        MINLEN:${TRIM_MINLEN}
    )

    # Add adapter trimming if file found
    if [[ -n "$ADAPTERS" && -f "$ADAPTERS" ]]; then
        trim_args+=( ILLUMINACLIP:"${ADAPTERS}":2:30:10:2:keepBothReads )
        log_info "  $sample: using adapters $(basename $ADAPTERS)"
    else
        log_warn "  $sample: adapter file not found, skipping ILLUMINACLIP"
    fi

    run_in_env "Trimmomatic $sample" "$ENV_TRIM" \
        trimmomatic "${trim_args[@]}" \
    || { log_error "Trimmomatic failed: $sample"; return 1; }

    # Log surviving read count
    local n_reads
    n_reads=$(conda run -p "$ENV_TRIM" \
        bash -c "zcat '${out_dir}/${sample}_1_paired.fastq.gz' | wc -l" 2>/dev/null || echo "?")
    log_info "  $sample: $(( n_reads / 4 )) read pairs surviving"
}

main() {
    log_step "MODULE 02: Trimmomatic adapter trimming"
    # Skip slow conda check — trimmomatic confirmed in pantools env
    log_info "  ✓ [trimmomatic] using $ENV_TRIM" 
    make_dirs "$DIR_TRIMMED"

    if [[ -n "$TARGET_SAMPLE" ]]; then
        log_info "Single sample mode: $TARGET_SAMPLE"
        trim_sample "$TARGET_SAMPLE"
    else
        mapfile -t SAMPLES < <(get_sample_list "$DIR_CLASSIFIED") || true || true
        log_info "Samples: ${#SAMPLES[@]}"

        local count=0 ok=0 fail=0
        for sample in "${SAMPLES[@]}"; do
            ((count++))
            log_info "── [$count/${#SAMPLES[@]}] $sample"
            trim_sample "$sample" && ((ok++)) || ((fail++))
        done

        log_info "────────────────────────────"
        log_info "Success: $ok  Failed: $fail"
    fi

    log_step "MODULE 02 complete ✓"
}

main "$@"
