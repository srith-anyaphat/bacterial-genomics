#!/bin/bash
###############################################################################
#  module_06b_fastani.sh
#  功能：用 FastANI 对 SPAdes 组装 contigs 进行物种确认
#        对比参考基因组：S. chromogenes MU 970
#        阈值：ANI ≥ 95% = 确认为 S. chromogenes（物种边界标准）
#
#  输入：$DIR_ASSEMBLY   — SPAdes contigs.fasta（module_03 输出）
#        $FASTANI_REF    — MU 970 参考基因组（config.sh 中配置）
#  输出：$DIR_FASTANI    — FastANI 结果 + 汇总表 + 通过/失败样本列表
#
#  单独运行：bash module_06b_fastani.sh
#  单样本：  bash module_06b_fastani.sh --sample SAMPLE_NAME
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/env_setup.sh"

mkdir -p "${DIR_LOGS}"
LOG_FILE="${DIR_LOGS}/06b_fastani_$(date '+%Y%m%d_%H%M%S').log"

TARGET_SAMPLE=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --sample) TARGET_SAMPLE="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# ── ANI 阈值 ──────────────────────────────────────────────────────────────────
ANI_THRESHOLD=95.0   # S. chromogenes 物种边界

main() {
    log_step "MODULE 06b: FastANI — 物种确认"
    log_info "参考基因组: $(basename "${FASTANI_REF}") (MU 970)"
    log_info "ANI 阈值: ≥ ${ANI_THRESHOLD}% = S. chromogenes 确认"

    check_env_tool "fastani" "$ENV_FASTANI" "fastANI" || exit 1

    if [[ ! -f "$FASTANI_REF" ]]; then
        log_error "参考基因组不存在: $FASTANI_REF"
        exit 1
    fi

    make_dirs "$DIR_FASTANI"

    # 汇总表
    local summary_tsv="${DIR_FASTANI}/fastani_summary.tsv"
    echo -e "Sample\tANI(%)\tMapped_fragments\tTotal_fragments\tFragment_coverage(%)\tStatus" \
        > "$summary_tsv"

    # 通过/失败列表（供后续模块筛选用）
    local pass_list="${DIR_FASTANI}/samples_confirmed_chromogenes.txt"
    local fail_list="${DIR_FASTANI}/samples_failed_ani.txt"
    > "$pass_list"
    > "$fail_list"

    if [[ -n "$TARGET_SAMPLE" ]]; then
        run_fastani_sample "$TARGET_SAMPLE" "$summary_tsv" "$pass_list" "$fail_list"
    else
        # 收集所有 contigs
        mapfile -t CONTIGS < <(find "$DIR_ASSEMBLY" -name "contigs.fasta" | sort)
        log_info "找到 ${#CONTIGS[@]} 个组装结果"

        local count=0 ok=0 fail=0
        for ctg in "${CONTIGS[@]}"; do
            ((count++))
            local sample; sample=$(basename "$(dirname "$ctg")")
            log_info "── [$count/${#CONTIGS[@]}] $sample"
            run_fastani_sample "$sample" "$summary_tsv" "$pass_list" "$fail_list" \
                && ((ok++)) || ((fail++))
        done
        log_info "处理完成: $ok 成功  $fail 跳过"
    fi

    # 汇总报告
    log_step "FastANI 物种确认汇总"
    local n_pass n_fail
    n_pass=$(wc -l < "$pass_list")
    n_fail=$(wc -l < "$fail_list")

    log_info "────────────────────────────────────"
    log_info "确认为 S. chromogenes (ANI ≥ ${ANI_THRESHOLD}%): $n_pass 个样本"
    log_info "未达标 (ANI < ${ANI_THRESHOLD}%):                $n_fail 个样本"
    log_info "────────────────────────────────────"

    if [[ $n_fail -gt 0 ]]; then
        log_warn "未达标样本:"
        while IFS= read -r s; do
            local ani; ani=$(awk -F'\t' -v samp="$s" '$1==samp{print $2}' "$summary_tsv")
            log_warn "  $s  ANI=${ani}%"
        done < "$fail_list"
    fi

    log_info ""
    log_info "汇总表:         $summary_tsv"
    log_info "通过样本列表:   $pass_list"
    log_info "失败样本列表:   $fail_list"

    column -t "$summary_tsv"
    log_step "MODULE 06b 完成 ✓"
}

run_fastani_sample() {
    local sample="$1"
    local summary_tsv="$2"
    local pass_list="$3"
    local fail_list="$4"

    local ctg="${DIR_ASSEMBLY}/${sample}/contigs.fasta"
    local out_dir="${DIR_FASTANI}/${sample}"
    local result_file="${out_dir}/${sample}.ani"

    if [[ ! -f "$ctg" ]]; then
        log_warn "  $sample: contigs.fasta 不存在，跳过"
        return 1
    fi

    mkdir -p "$out_dir"

    run_in_env "FastANI $sample" "$ENV_FASTANI" \
        fastANI \
            --query   "$ctg" \
            --ref     "$FASTANI_REF" \
            --output  "$result_file" \
            --fragLen 3000 \
            --minFraction 0.2 \
    || { log_warn "  $sample: FastANI 运行失败"; return 1; }

    # 解析结果
    if [[ ! -s "$result_file" ]]; then
        # 无输出 = ANI 太低，无法比对
        log_warn "  $sample: 无 ANI 结果（与 MU 970 相似度极低）"
        echo -e "${sample}\t<70\t0\t0\t0\t❌ FAIL — no alignment" >> "$summary_tsv"
        echo "$sample" >> "$fail_list"
        return 0
    fi

    # FastANI 输出格式: query ref ANI mapped_frags total_frags
    local ani mapped total frag_cov status
    ani=$(    awk '{printf "%.2f", $3}' "$result_file")
    mapped=$( awk '{print $4}' "$result_file")
    total=$(  awk '{print $5}' "$result_file")
    frag_cov=$(awk '{printf "%.1f", ($4/$5)*100}' "$result_file")

    if awk "BEGIN{exit !($ani >= $ANI_THRESHOLD)}"; then
        status="✓ PASS — S. chromogenes"
        echo "$sample" >> "$pass_list"
        log_info "  ✓ $sample: ANI=${ani}%  coverage=${frag_cov}%"
    else
        status="❌ FAIL — ANI below threshold"
        echo "$sample" >> "$fail_list"
        log_warn "  ✗ $sample: ANI=${ani}% < ${ANI_THRESHOLD}%"
    fi

    echo -e "${sample}\t${ani}\t${mapped}\t${total}\t${frag_cov}\t${status}" >> "$summary_tsv"
}

main "$@"
