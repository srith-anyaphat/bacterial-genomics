#!/bin/bash
###############################################################################
#  module_06_kraken2_assembly.sh
#  功能：在 SPAdes 组装后对 contigs 运行 Kraken2
#        目的：① 验证组装质量  ② 检测非目标物种 contig（宿主/污染）
#             ③ 与 module_01b 原始 reads 结果对比，评估组装纯度
#
#  输入：$DIR_ASSEMBLY      — SPAdes contigs.fasta（module_03 输出）
#        $KRAKEN2_DB        — Kraken2 lite 数据库
#  输出：$DIR_KRAKEN2_ASSM  — 每样本报告 + kraken2_assembly_summary.tsv
#                             + 比较表（与原始 reads 结果对比）
#
#  单独运行：bash module_06_kraken2_assembly.sh
#  单样本：  bash module_06_kraken2_assembly.sh --sample SAMPLE_NAME
#
#  流程位置：... → 03_assembly → [06_kraken2_assembly] → 04_quast → 05_prokka
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/kraken2_lib.sh"
source "${SCRIPT_DIR}/config.sh"

mkdir -p "${DIR_LOGS}"
LOG_FILE="${DIR_LOGS}/06_kraken2_assembly_$(date '+%Y%m%d_%H%M%S').log"

TARGET_SAMPLE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sample) TARGET_SAMPLE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# ── 对比原始 reads 与组装结果的 S.chromogenes 占比 ───────────────────────────
compare_with_raw() {
    local sample="$1"
    local raw_tsv="${DIR_KRAKEN2_RAW}/kraken2_raw_summary.tsv"
    local assm_report="${DIR_KRAKEN2_ASSM}/${sample}/${sample}.kraken2.report"
    local diff_tsv="${DIR_KRAKEN2_ASSM}/comparison_raw_vs_assembly.tsv"

    # 初始化对比表头（第一次调用时）
    if [[ ! -f "$diff_tsv" ]]; then
        echo -e "Sample\tRaw_S.chromogenes(%)\tAssembly_S.chromogenes(%)\tDiff(%)\tFlag" \
            > "$diff_tsv"
    fi

    # 从原始汇总表取值
    local raw_pct
    raw_pct=$(awk -F'\t' -v s="$sample" '$1==s{print $5}' "$raw_tsv" 2>/dev/null || echo "N/A")

    # 从组装 report 取值
    local assm_pct
    assm_pct=$(awk '$4=="S" && $0~/Staphylococcus chromogenes/{printf "%.2f", $1}' \
               "$assm_report" 2>/dev/null || echo "0")

    # 计算差值并判断
    local diff flag
    if [[ "$raw_pct" == "N/A" ]]; then
        diff="N/A"; flag="⚠️  无原始数据对比"
    else
        diff=$(awk -v r="$raw_pct" -v a="$assm_pct" 'BEGIN{printf "%.2f", a-r}')
        local diff_abs; diff_abs=$(awk -v d="$diff" 'BEGIN{printf "%.1f", (d<0)?-d:d}')
        if   awk -v d="$diff_abs" 'BEGIN{exit !(d+0 > 15)}'; then
            flag="🔴 差异显著（>${diff_abs}%）— 建议检查"
        elif awk -v d="$diff_abs" 'BEGIN{exit !(d+0 > 5)}'; then
            flag="🟡 差异中等（${diff_abs}%）"
        else
            flag="🟢 一致"
        fi
    fi

    echo -e "${sample}\t${raw_pct}\t${assm_pct}\t${diff}\t${flag}" >> "$diff_tsv"
    log_info "  $sample：原始=${raw_pct}%  组装=${assm_pct}%  差异=${diff}%  ${flag}"
}

main() {
    log_step "MODULE 06: Kraken2 — 组装 contigs 物种验证"
    log_info "目的：验证 SPAdes 组装纯度，检测非目标 contig"
    check_tool kraken2 || exit 1
    kraken2_check_db   || exit 1
    make_dirs "$DIR_KRAKEN2_ASSM"

    local summary_tsv="${DIR_KRAKEN2_ASSM}/kraken2_assembly_summary.tsv"
    echo -e "Sample\tUnclassified(%)\tClassified(%)\tStaphylococcus(%)\tS.chromogenes(%)\tTop_species" \
        > "$summary_tsv"

    # 检查 01b 原始结果是否存在（用于对比）
    local has_raw_data=0
    [[ -f "${DIR_KRAKEN2_RAW}/kraken2_raw_summary.tsv" ]] && has_raw_data=1
    [[ $has_raw_data -eq 0 ]] && \
        log_warn "未找到 module_01b 的原始 reads 结果，将跳过对比分析"

    if [[ -n "$TARGET_SAMPLE" ]]; then
        log_info "单样本模式: $TARGET_SAMPLE"
        local ctg="${DIR_ASSEMBLY}/${TARGET_SAMPLE}/contigs.fasta"
        local out_dir="${DIR_KRAKEN2_ASSM}/${TARGET_SAMPLE}"

        if kraken2_run_contigs "$TARGET_SAMPLE" "$ctg" "$out_dir"; then
            kraken2_parse_report "${out_dir}/${TARGET_SAMPLE}.kraken2.report" \
                                 "$TARGET_SAMPLE" "$summary_tsv"
            [[ $has_raw_data -eq 1 ]] && compare_with_raw "$TARGET_SAMPLE"
        fi
    else
        mapfile -t CONTIGS < <(find "$DIR_ASSEMBLY" -name "contigs.fasta" | sort)
        log_info "找到 ${#CONTIGS[@]} 个组装结果"

        local count=0 ok=0 fail=0
        for ctg in "${CONTIGS[@]}"; do
            ((count++))
            local sample; sample=$(basename "$(dirname "$ctg")")
            log_info "── [$count/${#CONTIGS[@]}] $sample"
            local out_dir="${DIR_KRAKEN2_ASSM}/${sample}"

            if kraken2_run_contigs "$sample" "$ctg" "$out_dir"; then
                kraken2_parse_report "${out_dir}/${sample}.kraken2.report" \
                                     "$sample" "$summary_tsv"
                [[ $has_raw_data -eq 1 ]] && compare_with_raw "$sample"
                ((ok++))
            else
                ((fail++))
            fi
        done
        log_info "成功: $ok  失败: $fail"
    fi

    log_step "汇总（组装 contigs）"
    column -t "$summary_tsv"

    # 对比表预览
    local diff_tsv="${DIR_KRAKEN2_ASSM}/comparison_raw_vs_assembly.tsv"
    if [[ -f "$diff_tsv" ]]; then
        log_step "原始 reads vs 组装对比"
        column -t "$diff_tsv"
    fi

    # MultiQC 整合
    if command -v multiqc &>/dev/null; then
        run_cmd "MultiQC kraken2_assembly" \
            multiqc "$DIR_KRAKEN2_ASSM" \
                    --outdir "${DIR_KRAKEN2_ASSM}/multiqc_report" \
                    --filename "multiqc_kraken2_assembly" \
                    --force
        log_info "MultiQC: ${DIR_KRAKEN2_ASSM}/multiqc_report/multiqc_kraken2_assembly.html"
    fi

    log_info "汇总表: $summary_tsv"
    log_step "MODULE 06 完成 ✓"
}

main "$@"
