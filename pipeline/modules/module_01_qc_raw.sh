#!/bin/bash
###############################################################################
#  module_01_qc_raw.sh
#  功能：对原始 reads 运行 FastQC + MultiQC 汇总
#
#  输入：$DIR_CLASSIFIED  — 各样本 fastq 目录
#  输出：$DIR_QC_RAW      — FastQC html/zip 报告 + MultiQC 汇总
#
#  conda 环境：ENV_FASTQC, ENV_MULTIQC（在 config/env_setup.sh 中定义）
#  单独运行：bash module_01_qc_raw.sh
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/env_setup.sh"

mkdir -p "${DIR_LOGS}"
LOG_FILE="${DIR_LOGS}/01_qc_raw_$(date '+%Y%m%d_%H%M%S').log"

main() {
    log_step "MODULE 01: FastQC (原始 reads)"
    check_env_tool "fastqc"  "$ENV_FASTQC"  "fastqc"  || exit 1
    check_env_tool "multiqc" "$ENV_MULTIQC" "multiqc" || exit 1
    make_dirs "$DIR_QC_RAW"

    mapfile -t SAMPLES < <(get_sample_list "$DIR_CLASSIFIED")
    log_info "样本数: ${#SAMPLES[@]}"

    local count=0
    for sample in "${SAMPLES[@]}"; do
        ((count++))
        local sample_dir="${DIR_CLASSIFIED}/${sample}"
        local out_dir="${DIR_QC_RAW}/${sample}"
        mkdir -p "$out_dir"

        progress "$count" "${#SAMPLES[@]}" "$sample"

        mapfile -t FQS < <(find "$sample_dir" -name "*.fastq.gz" | sort)
        if [[ ${#FQS[@]} -eq 0 ]]; then
            log_warn "  $sample：未找到 fastq.gz，跳过"
            continue
        fi

        run_in_env "FastQC $sample" "$ENV_FASTQC" \
            fastqc --threads "${FASTQC_THREADS}" \
                   --outdir  "$out_dir" \
                   "${FQS[@]}" \
            || { log_error "FastQC 失败: $sample"; continue; }
    done
    echo ""

    # MultiQC 汇总
    log_step "MultiQC 汇总"
    run_in_env "MultiQC raw" "$ENV_MULTIQC" \
        multiqc "$DIR_QC_RAW" \
                --outdir   "${DIR_QC_RAW}/multiqc_report" \
                --filename "multiqc_raw" \
                --force

    log_info "MultiQC 报告: ${DIR_QC_RAW}/multiqc_report/multiqc_raw.html"
    log_step "MODULE 01 完成 ✓"
}

main "$@"