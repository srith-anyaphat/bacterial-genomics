#!/bin/bash
###############################################################################
#  module_05_annotation.sh
#  功能：用 Prokka 对组装 contigs 进行基因组注释
#
#  输入：$DIR_ASSEMBLY    — SPAdes contigs
#  输出：$DIR_ANNOTATION  — 每样本 Prokka 注释结果（gff/gbk/faa/ffn 等）
#
#  单独运行：bash module_05_annotation.sh
#  单样本：  bash module_05_annotation.sh --sample SAMPLE_NAME
#  重跑：    bash module_05_annotation.sh --force
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

mkdir -p "${DIR_LOGS}"
LOG_FILE="${DIR_LOGS}/05_annotation_$(date '+%Y%m%d_%H%M%S').log"

TARGET_SAMPLE=""
FORCE=0
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sample) TARGET_SAMPLE="$2"; shift 2 ;;
        --force)  FORCE=1; shift ;;
        *) shift ;;
    esac
done

annotate_sample() {
    local sample="$1"
    local ctg="${DIR_ASSEMBLY}/${sample}/contigs.fasta"
    local out_dir="${DIR_ANNOTATION}/${sample}"

    if [[ ! -f "$ctg" ]]; then
        log_warn "  $sample：contigs.fasta 不存在，跳过"
        return 1
    fi

    # 跳过已完成（除非 --force）
    if [[ -f "${out_dir}/${sample}.gff" && "$FORCE" -eq 0 ]]; then
        log_info "  $sample：已注释，跳过（--force 可重跑）"
        return 0
    fi

    # 若 --force，清除旧结果
    [[ "$FORCE" -eq 1 && -d "$out_dir" ]] && rm -rf "$out_dir"
    mkdir -p "$out_dir"

    run_cmd "Prokka $sample" \
        prokka \
            --outdir   "$out_dir" \
            --prefix   "$sample" \
            --genus    "${PROKKA_GENUS}" \
            --species  "${PROKKA_SPECIES}" \
            --kingdom  "${PROKKA_KINGDOM}" \
            --cpus     "${PROKKA_THREADS}" \
            --force \
            "$ctg" \
    || return 1

    # 简要统计
    local n_cds n_rna
    n_cds=$(grep -c "CDS" "${out_dir}/${sample}.gff" 2>/dev/null || echo "?")
    n_rna=$(grep -c "rRNA\|tRNA" "${out_dir}/${sample}.gff" 2>/dev/null || echo "?")
    log_info "  $sample：$n_cds CDS，$n_rna RNA 特征"
}

main() {
    log_step "MODULE 05: Prokka 基因组注释"
    check_tool prokka || exit 1
    make_dirs "$DIR_ANNOTATION"

    if [[ -n "$TARGET_SAMPLE" ]]; then
        log_info "单样本模式: $TARGET_SAMPLE"
        annotate_sample "$TARGET_SAMPLE"
    else
        mapfile -t CONTIGS < <(find "$DIR_ASSEMBLY" -name "contigs.fasta" | sort)
        log_info "找到 ${#CONTIGS[@]} 个组装结果"

        local count=0 ok=0 fail=0
        for ctg in "${CONTIGS[@]}"; do
            ((count++))
            local sample; sample=$(basename "$(dirname "$ctg")")
            log_info "── [$count/${#CONTIGS[@]}] $sample"
            annotate_sample "$sample" && ((ok++)) || ((fail++))
        done

        # 汇总：CDS 数统计
        local sum_tsv="${DIR_ANNOTATION}/annotation_summary.tsv"
        echo -e "Sample\tCDS\ttRNA\trRNA\tGFF" > "$sum_tsv"
        for ctg in "${CONTIGS[@]}"; do
            local s; s=$(basename "$(dirname "$ctg")")
            local gff="${DIR_ANNOTATION}/${s}/${s}.gff"
            if [[ -f "$gff" ]]; then
                local cds trna rrna
                cds=$(grep -c "CDS"  "$gff" 2>/dev/null || echo 0)
                trna=$(grep -c "tRNA" "$gff" 2>/dev/null || echo 0)
                rrna=$(grep -c "rRNA" "$gff" 2>/dev/null || echo 0)
                echo -e "$s\t$cds\t$trna\t$rrna\t$gff" >> "$sum_tsv"
            fi
        done
        log_info "注释汇总: $sum_tsv"
        log_info "成功: $ok  失败: $fail"
    fi

    log_step "MODULE 05 完成 ✓"
}

main "$@"
