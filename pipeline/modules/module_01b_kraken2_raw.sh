#!/bin/bash
###############################################################################
#  module_01b_kraken2_raw.sh
#  功能：在 QC/Trim 之前对原始 reads 运行 Kraken2
#        目的：① 早期确认物种身份  ② 发现严重污染  ③ 决定样本是否值得继续
#
#  输入：$DIR_CLASSIFIED  — 解压分类后的原始 fastq（module_00 输出）
#        $KRAKEN2_DB      — Kraken2 lite 数据库
#  输出：$DIR_KRAKEN2_RAW — 每样本报告 + kraken2_raw_summary.tsv
#
#  conda 环境：ENV_KRAKEN2（在 config/env_setup.sh 中定义）
#  单独运行：bash module_01b_kraken2_raw.sh
#  单样本：  bash module_01b_kraken2_raw.sh --sample SAMPLE_NAME
###############################################################################

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/kraken2_lib.sh"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/env_setup.sh"

mkdir -p "${DIR_LOGS}"
LOG_FILE="${DIR_LOGS}/01b_kraken2_raw_$(date '+%Y%m%d_%H%M%S').log"

TARGET_SAMPLE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sample) TARGET_SAMPLE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

main() {
    log_step "MODULE 01b: Kraken2 — 原始 reads 物种鉴定"
    log_info "目的：QC 前早期确认样本物种，筛查严重污染"
    check_env_tool "kraken2" "$ENV_KRAKEN2" "kraken2" || exit 1
    kraken2_check_db || exit 1
    make_dirs "$DIR_KRAKEN2_RAW"

    local summary_tsv="${DIR_KRAKEN2_RAW}/kraken2_raw_summary.tsv"
    echo -e "Sample\tUnclassified(%)\tClassified(%)\tStaphylococcus(%)\tS.chromogenes(%)\tTop_species" \
        > "$summary_tsv"

    if [[ -n "$TARGET_SAMPLE" ]]; then
        log_info "单样本模式: $TARGET_SAMPLE"
        local out_dir="${DIR_KRAKEN2_RAW}/${TARGET_SAMPLE}"
        kraken2_run_reads   "$TARGET_SAMPLE" "${DIR_CLASSIFIED}/${TARGET_SAMPLE}" "$out_dir"
        kraken2_run_bracken "$TARGET_SAMPLE" "${out_dir}/${TARGET_SAMPLE}.kraken2.report" "$out_dir"
        kraken2_parse_report "${out_dir}/${TARGET_SAMPLE}.kraken2.report" "$TARGET_SAMPLE" "$summary_tsv"
    else
        mapfile -t SAMPLES < <(get_sample_list "$DIR_CLASSIFIED")
        log_info "样本数: ${#SAMPLES[@]}"

        local count=0 ok=0 fail=0
        for sample in "${SAMPLES[@]}"; do
            ((count++))
            log_info "── [$count/${#SAMPLES[@]}] $sample"
            local out_dir="${DIR_KRAKEN2_RAW}/${sample}"

            if kraken2_run_reads "$sample" "${DIR_CLASSIFIED}/${sample}" "$out_dir"; then
                kraken2_run_bracken  "$sample" "${out_dir}/${sample}.kraken2.report" "$out_dir"
                kraken2_parse_report "${out_dir}/${sample}.kraken2.report" "$sample" "$summary_tsv"
                ((ok++))
            else
                ((fail++))
            fi
        done
        log_info "成功: $ok  失败: $fail"
    fi

    log_step "汇总（原始 reads）"
    column -t "$summary_tsv"

    # MultiQC 整合（可选）
    if "$CONDA_BIN" run -p "$ENV_KRAKEN2" which multiqc &>/dev/null; then
        run_in_env "MultiQC kraken2_raw" "$ENV_KRAKEN2" \
            multiqc "$DIR_KRAKEN2_RAW" \
                    --outdir   "${DIR_KRAKEN2_RAW}/multiqc_report" \
                    --filename "multiqc_kraken2_raw" \
                    --force \
        && log_info "MultiQC: ${DIR_KRAKEN2_RAW}/multiqc_report/multiqc_kraken2_raw.html"
    else
        log_info "（multiqc 不在 kraken2 环境，跳过整合；后续可用 ENV_MULTIQC 环境单独运行）"
    fi

    log_info "汇总表: $summary_tsv"
    log_step "MODULE 01b 完成 ✓"
}

main "$@"