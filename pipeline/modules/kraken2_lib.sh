#!/bin/bash
###############################################################################
#  kraken2_lib.sh — Kraken2 公共函数库
#  被 module_01b 和 module_06 共同 source，不单独运行
#  依赖：utils.sh 和 env_setup.sh 已被调用方 source
###############################################################################

# ── 数据库检查 ────────────────────────────────────────────────────────────────
kraken2_check_db() {
    for f in hash.k2d opts.k2d taxo.k2d; do
        if [[ ! -f "${KRAKEN2_DB}/${f}" ]]; then
            log_error "Kraken2 数据库文件缺失: ${KRAKEN2_DB}/${f}"
            return 1
        fi
    done
    local db_size; db_size=$(du -sh "${KRAKEN2_DB}" | cut -f1)
    log_info "  ✓ Kraken2 DB: ${KRAKEN2_DB}  (${db_size})"
}

# ── 对 reads（fastq.gz）运行 Kraken2 ─────────────────────────────────────────
kraken2_run_reads() {
    local sample="$1" input_dir="$2" out_dir="$3"
    mkdir -p "$out_dir"

    local R1 R2
    R1=$(find "$input_dir" \( -name "*_1.fastq.gz" -o -name "*_R1*.fastq.gz" -o -name "*_val_1.fq.gz" -o -name "*_1_trimmed.fastq.gz" \) 2>/dev/null | sort | head -1)
    R2=$(find "$input_dir" \( -name "*_2.fastq.gz" -o -name "*_R2*.fastq.gz" -o -name "*_val_2.fq.gz" -o -name "*_2_trimmed.fastq.gz" \) 2>/dev/null | sort | head -1)

    if [[ -z "$R1" ]]; then
        log_warn "  $sample：未找到 fastq.gz reads，跳过"
        return 1
    fi

    local report="${out_dir}/${sample}.kraken2.report"
    local output="${out_dir}/${sample}.kraken2.out"

    local kraken_args=(
        --db             "${KRAKEN2_DB}"
        --threads        "${KRAKEN2_THREADS}"
        --confidence     "${KRAKEN2_CONFIDENCE}"
        --report         "$report"
        --output         "$output"
        --gzip-compressed
        --report-minimizer-data
    )

    if [[ -n "$R2" ]]; then
        kraken_args+=(
            --paired
            --classified-out   "${out_dir}/${sample}_classified#.fastq"
            --unclassified-out "${out_dir}/${sample}_unclassified#.fastq"
            "$R1" "$R2"
        )
        log_info "  $sample：PE reads → Kraken2"
    else
        kraken_args+=(
            --classified-out   "${out_dir}/${sample}_classified.fastq"
            --unclassified-out "${out_dir}/${sample}_unclassified.fastq"
            "$R1"
        )
        log_info "  $sample：SE reads → Kraken2"
    fi

    run_in_env "Kraken2 reads $sample" "$ENV_KRAKEN2" \
        kraken2 "${kraken_args[@]}" || return 1

    # 压缩 classified/unclassified（节省空间）
    find "$out_dir" -name "*.fastq" ! -name "*.gz" | \
        xargs -P4 -I{} gzip -f {} 2>/dev/null || true

    log_info "  $sample：报告 → $report"
}

# ── 对 contigs（fasta）运行 Kraken2 ──────────────────────────────────────────
kraken2_run_contigs() {
    local sample="$1" contigs="$2" out_dir="$3"
    mkdir -p "$out_dir"

    if [[ ! -f "$contigs" ]]; then
        log_warn "  $sample：contigs.fasta 不存在，跳过"
        return 1
    fi

    local report="${out_dir}/${sample}.kraken2.report"
    local output="${out_dir}/${sample}.kraken2.out"

    run_in_env "Kraken2 contigs $sample" "$ENV_KRAKEN2" \
        kraken2 \
            --db          "${KRAKEN2_DB}" \
            --threads     "${KRAKEN2_THREADS}" \
            --confidence  "${KRAKEN2_CONFIDENCE}" \
            --report      "$report" \
            --output      "$output" \
            --report-minimizer-data \
            "$contigs" \
    || return 1

    log_info "  $sample：报告 → $report"
}

# ── 解析 report → 追加到汇总 TSV ─────────────────────────────────────────────
kraken2_parse_report() {
    local report="$1" sample="$2" tsv="$3"
    local warn_threshold="${4:-70}"

    if [[ ! -f "$report" ]]; then
        log_warn "  $sample：报告不存在，跳过解析"
        return
    fi

    local unclassified_pct classified_pct staph_pct chromogenes_pct top_species

    unclassified_pct=$(awk -F'\t' '{gsub(/^ +/,"",$1)} $6=="U"{printf "%.2f",$1}' "$report")
    classified_pct=$(  awk -F'\t' '{gsub(/^ +/,"",$1)} $6=="R"{printf "%.2f",$1; exit}' "$report")
    staph_pct=$(       awk -F'\t' '{gsub(/^ +/,"",$1)} $6=="G" && $NF~/Staphylococcus$/{printf "%.2f",$1}' "$report" | head -1)
    chromogenes_pct=$( awk -F'\t' '{gsub(/^ +/,"",$1)} $6=="S" && $0~/Staphylococcus chromogenes/{printf "%.2f",$1}' "$report" | head -1)
    top_species=$(     awk -F'\t' '{gsub(/^ +/,"",$1)} $6=="S" && $1+0>0.1{printf "%s(%.1f%%)|",$NF,$1}' "$report" | sed 's/|$//' | cut -c1-200)

    echo -e "${sample}\t${unclassified_pct:-0}\t${classified_pct:-0}\t${staph_pct:-0}\t${chromogenes_pct:-0}\t${top_species:-N/A}" \
        >> "$tsv"

    local chrom_int; chrom_int=$(printf "%.0f" "${chromogenes_pct:-0}")
    if (( chrom_int < warn_threshold )); then
        log_warn "  ⚠️  $sample：S. chromogenes ${chromogenes_pct:-0}% < ${warn_threshold}% — 疑似污染或物种错误"
    else
        log_info "  ✓  $sample：S. chromogenes ${chromogenes_pct:-0}%"
    fi
}

# ── Bracken 丰度重估（可选）─────────────────────────────────────────────────
kraken2_run_bracken() {
    local sample="$1" report="$2" out_dir="$3"

    # 检查 bracken 是否在 kraken2 环境里
    "$CONDA_BIN" run -p "$ENV_KRAKEN2" which bracken &>/dev/null || return 0
    [[ -f "$report" ]] || return 0

    run_in_env "Bracken $sample" "$ENV_KRAKEN2" \
        bracken \
            -d "${KRAKEN2_DB}" \
            -i "$report" \
            -o "${out_dir}/${sample}.bracken" \
            -r 150 -l S -t 10 \
    && log_info "  Bracken: ${out_dir}/${sample}.bracken" \
    || log_warn "  Bracken 失败（不影响 Kraken2 结果）"
}