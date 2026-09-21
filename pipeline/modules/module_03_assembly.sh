#!/bin/bash
###############################################################################
#  module_03_assembly.sh
#  功能：用 SPAdes 对每个样本进行基因组从头组装
#
#  输入：$DIR_TRIMMED   — Trim Galore 修剪后 reads
#  输出：$DIR_ASSEMBLY  — 每个样本的 SPAdes 组装结果
#
#  单独运行：bash module_03_assembly.sh
#  调试单个样本：bash module_03_assembly.sh --sample SAMPLE_NAME
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

mkdir -p "${DIR_LOGS}"
LOG_FILE="${DIR_LOGS}/03_assembly_$(date '+%Y%m%d_%H%M%S').log"

# ── 参数解析：支持 --sample 单独运行某个样本 ────────────────────────────────
TARGET_SAMPLE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sample) TARGET_SAMPLE="$2"; shift 2 ;;
        *) log_warn "未知参数: $1"; shift ;;
    esac
done

# ── 组装单个样本 ──────────────────────────────────────────────────────────────
assemble_sample() {
    local sample="$1"
    local sample_dir="${DIR_TRIMMED}/${sample}"
    local out_dir="${DIR_ASSEMBLY}/${sample}"

    # 跳过已完成的
    if [[ -f "${out_dir}/contigs.fasta" ]]; then
        log_info "  $sample：已存在 contigs.fasta，跳过（删除目录可重跑）"
        return 0
    fi

    # 找修剪后的 reads（Trim Galore 输出命名规则）
    local R1 R2
    R1=$(find "$sample_dir" \( -name "*_1_paired.fastq.gz" \) 2>/dev/null | head -1)
    R2=$(find "$sample_dir" \( -name "*_2_paired.fastq.gz" \) 2>/dev/null | head -1)

    if [[ -z "$R1" ]]; then
        log_warn "  $sample：未找到 trimmed reads，跳过"
        return 1
    fi

    mkdir -p "$out_dir"
    local spades_args=(
        --threads "${SPADES_THREADS}"
        --memory  "${SPADES_MEMORY}"
        -k        "${SPADES_KMERS}"
        -o        "$out_dir"
    )

    if [[ -n "$R2" ]]; then
        log_info "  $sample：Paired-end 组装"
        spades_args+=( -1 "$R1" -2 "$R2" )
    else
        log_info "  $sample：Single-end 组装"
        spades_args+=( -s "$R1" )
    fi

    run_cmd "SPAdes $sample" spades.py "${spades_args[@]}" || return 1

    # 简单统计
    if [[ -f "${out_dir}/contigs.fasta" ]]; then
        local n_contigs; n_contigs=$(grep -c "^>" "${out_dir}/contigs.fasta")
        log_info "  $sample：$n_contigs contigs 生成"
    fi
}

main() {
    log_step "MODULE 03: SPAdes 基因组组装"
    check_tool spades.py || exit 1
    make_dirs "$DIR_ASSEMBLY"

    if [[ -n "$TARGET_SAMPLE" ]]; then
        # 单样本模式（调试用）
        log_info "单样本模式: $TARGET_SAMPLE"
        assemble_sample "$TARGET_SAMPLE"
    else
        # 全量模式
        mapfile -t SAMPLES < <(get_sample_list "$DIR_TRIMMED")
        log_info "样本数: ${#SAMPLES[@]}"

        local count=0 ok=0 fail=0
        for sample in "${SAMPLES[@]}"; do
            ((count++))
            log_info "── [$count/${#SAMPLES[@]}] $sample"
            assemble_sample "$sample" && ((ok++)) || ((fail++))
        done

        log_info "────────────────────────────"
        log_info "成功: $ok  失败: $fail  总计: ${#SAMPLES[@]}"
    fi

    log_step "MODULE 03 完成 ✓"
}

main "$@"
