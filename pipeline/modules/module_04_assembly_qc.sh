#!/bin/bash
###############################################################################
#  module_04_assembly_qc.sh
#  功能：用 QUAST 对组装结果进行质量评估，生成汇总报告
#        参考基因组：S. chromogenes MU 970（bovine mastitis 经典株，~2.34 Mb）
#
#  输入：$DIR_ASSEMBLY     — SPAdes 各样本组装结果
#        $QUAST_REFERENCE  — MU 970 参考基因组 .fna（config.sh 中配置）
#  输出：$DIR_ASSEMBLY_QC  — QUAST 各样本报告 + 全局汇总 TSV
#
#  单独运行：bash module_04_assembly_qc.sh
#  无参模式：bash module_04_assembly_qc.sh --no-ref
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

mkdir -p "${DIR_LOGS}"
LOG_FILE="${DIR_LOGS}/04_assembly_qc_$(date '+%Y%m%d_%H%M%S').log"

USE_REF=1
while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-ref) USE_REF=0; shift ;;
        *) shift ;;
    esac
done

main() {
    log_step "MODULE 04: QUAST 组装质控"
    check_tool quast.py || exit 1
    make_dirs "$DIR_ASSEMBLY_QC"

    # 参考基因组检查
    local ref_args=()
    if [[ "$USE_REF" -eq 1 ]]; then
        if [[ -f "${QUAST_REFERENCE}" ]]; then
            ref_args+=( --reference "${QUAST_REFERENCE}" )
            log_info "参考基因组: $(basename "${QUAST_REFERENCE}") (MU 970, ~2.34 Mb)"
        else
            log_warn "参考基因组未找到: ${QUAST_REFERENCE}"
            log_warn "将以无参模式运行（仅通用统计）。可用 --no-ref 跳过此警告"
        fi
    else
        log_info "无参模式（--no-ref）"
    fi

    # 收集所有 contigs.fasta
    mapfile -t CONTIGS < <(find "$DIR_ASSEMBLY" -name "contigs.fasta" | sort)

    if [[ ${#CONTIGS[@]} -eq 0 ]]; then
        log_error "未找到任何 contigs.fasta，请先运行 module_03_assembly.sh"
        exit 1
    fi
    log_info "找到 ${#CONTIGS[@]} 个组装结果"

    # 1. 各样本单独 QUAST（用于细看）
    local count=0
    for ctg in "${CONTIGS[@]}"; do
        ((count++))
        local sample; sample=$(basename "$(dirname "$ctg")")
        local out_dir="${DIR_ASSEMBLY_QC}/per_sample/${sample}"
        mkdir -p "$out_dir"

        progress "$count" "${#CONTIGS[@]}" "$sample"
        run_cmd "QUAST $sample" \
            quast.py "$ctg" \
                "${ref_args[@]}" \
                --threads       "${QUAST_THREADS}" \
                --min-contig    "${QUAST_MIN_CONTIG}" \
                --output-dir    "$out_dir" \
                --no-html \
            || log_warn "QUAST 失败: $sample"
    done
    echo ""

    # 2. 全部样本合并 QUAST（一张总表）
    log_step "QUAST 全局汇总"
    local combined_out="${DIR_ASSEMBLY_QC}/combined_report"
    mkdir -p "$combined_out"

    run_cmd "QUAST combined" \
        quast.py "${CONTIGS[@]}" \
            "${ref_args[@]}" \
            --threads    "${QUAST_THREADS}" \
            --min-contig "${QUAST_MIN_CONTIG}" \
            --output-dir "$combined_out" \
            --labels     "$(printf '%s,' "${CONTIGS[@]}" | sed 's|/contigs.fasta||g; s|.*/||g; s/,$//')" \
        || log_warn "Combined QUAST 失败，但各样本报告仍可用"

    # 3. 提取关键指标到简明 TSV
    # 有参模式额外输出 Genome_fraction(%) 和 Misassemblies
    local summary_tsv="${DIR_ASSEMBLY_QC}/assembly_summary.tsv"
    if [[ ${#ref_args[@]} -gt 0 ]]; then
        echo -e "Sample\tContigs\tTotal_length(bp)\tN50\tLargest_contig\tGC(%)\tGenome_fraction(%)\tMisassemblies" > "$summary_tsv"
    else
        echo -e "Sample\tContigs\tTotal_length(bp)\tN50\tLargest_contig\tGC(%)" > "$summary_tsv"
    fi

    for ctg in "${CONTIGS[@]}"; do
        local sample; sample=$(basename "$(dirname "$ctg")")
        local report="${DIR_ASSEMBLY_QC}/per_sample/${sample}/report.tsv"
        if [[ -f "$report" ]]; then
            local n_ctg total n50 largest gc
            n_ctg=$(   awk -F'\t' '$1=="# contigs"{print $2}'       "$report")
            total=$(   awk -F'\t' '$1=="Total length"{print $2}'     "$report")
            n50=$(     awk -F'\t' '$1=="N50"{print $2}'              "$report")
            largest=$( awk -F'\t' '$1=="Largest contig"{print $2}'   "$report")
            gc=$(      awk -F'\t' '$1=="GC (%)"{print $2}'           "$report")
            if [[ ${#ref_args[@]} -gt 0 ]]; then
                local gf misasm
                gf=$(     awk -F'\t' '$1=="Genome fraction (%)"{print $2}' "$report")
                misasm=$( awk -F'\t' '$1=="# misassemblies"{print $2}'     "$report")
                echo -e "${sample}\t${n_ctg}\t${total}\t${n50}\t${largest}\t${gc}\t${gf}\t${misasm}" >> "$summary_tsv"
            else
                echo -e "${sample}\t${n_ctg}\t${total}\t${n50}\t${largest}\t${gc}" >> "$summary_tsv"
            fi
        fi
    done

    log_info "汇总表: $summary_tsv"
    column -t "$summary_tsv" | head -20   # 终端预览

    log_step "MODULE 04 完成 ✓"
}

main "$@"