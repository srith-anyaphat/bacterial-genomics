#!/bin/bash
###############################################################################
#  module_00_extract_classify.sh
#  功能：解压 raw_data/ 下所有压缩包，并按样本分类整理 fastq 文件
#
#  输入：$RAW_DATA_DIR   — 原始压缩包目录
#  输出：$DIR_EXTRACTED  — 解压后原始 fastq（临时中转）
#        $DIR_CLASSIFIED — 按样本整理好的 fastq（供后续模块使用）
#
#  单独运行：bash module_00_extract_classify.sh
#  主流程调用：由 main_pipeline.sh 自动调用
###############################################################################

set -euo pipefail

# ── 加载配置和工具函数 ────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"

# ── 日志 ──────────────────────────────────────────────────────────────────────
mkdir -p "${DIR_LOGS}"
LOG_FILE="${DIR_LOGS}/00_extract_classify_$(date '+%Y%m%d_%H%M%S').log"

# ── 主逻辑 ────────────────────────────────────────────────────────────────────
main() {
    log_step "MODULE 00: 解压 & 分类"
    make_dirs "$DIR_EXTRACTED" "$DIR_CLASSIFIED"

    # 1. 扫描所有压缩包
    log_info "扫描 $RAW_DATA_DIR ..."
    mapfile -t ARCHIVES < <(find "$RAW_DATA_DIR" -maxdepth 2 \
        \( -name "*.tar.gz" -o -name "*.tgz" -o -name "*.tar.bz2" \
           -o -name "*.tar.xz" -o -name "*.zip" -o -name "*.gz" \
           -o -name "*.bz2" \) | sort)

    if [[ ${#ARCHIVES[@]} -eq 0 ]]; then
        log_warn "未找到任何压缩包，请检查 RAW_DATA_DIR: $RAW_DATA_DIR"
        exit 0
    fi
    log_info "共找到 ${#ARCHIVES[@]} 个压缩包"

    # 2. 逐一解压
    local count=0
    for arc in "${ARCHIVES[@]}"; do
        ((count++))
        local bname; bname=$(basename "$arc")
        progress "$count" "${#ARCHIVES[@]}" "$bname"

        local tmp_dir="${DIR_EXTRACTED}/tmp_${bname%%.*}"
        mkdir -p "$tmp_dir"

        case "$arc" in
            *.tar.gz|*.tgz)   tar -xzf  "$arc" -C "$tmp_dir" ;;
            *.tar.bz2|*.tbz2) tar -xjf  "$arc" -C "$tmp_dir" ;;
            *.tar.xz)          tar -xJf  "$arc" -C "$tmp_dir" ;;
            *.zip)             unzip -q  "$arc" -d "$tmp_dir" ;;
            *.gz)
                # 单个 .fastq.gz 文件，不解压，直接软链接
                ln -sf "$arc" "$tmp_dir/$(basename "${arc%.gz}")" 2>/dev/null || cp "$arc" "$tmp_dir/"
                ;;
            *.bz2)
                bunzip2 -k -c "$arc" > "$tmp_dir/$(basename "${arc%.bz2}")"
                ;;
        esac
        log_info "  ✓ 解压: $bname"
    done
    echo ""  # 换行（清除进度条）

    # 3. 按样本分类
    log_step "按样本归类 fastq 文件"
    local classified=0

    # 找出所有 fastq/fastq.gz 文件（包括嵌套子目录）
    while IFS= read -r fq; do
        local fname; fname=$(basename "$fq")

        # 解析样本名：去掉 _1/_2/_R1/_R2 后缀和扩展名
        local sample
        sample=$(echo "$fname" | sed \
            -e 's/_R1\(_001\)\?\(\.fastq\)\?\(\.gz\)\?$//' \
            -e 's/_R2\(_001\)\?\(\.fastq\)\?\(\.gz\)\?$//' \
            -e 's/_1\(\.fastq\)\?\(\.gz\)\?$//' \
            -e 's/_2\(\.fastq\)\?\(\.gz\)\?$//' \
            -e 's/\.fastq\.gz$//' \
            -e 's/\.fastq$//' \
            -e 's/\.fq\.gz$//' \
            -e 's/\.fq$//')

        local dest="${DIR_CLASSIFIED}/${sample}"
        mkdir -p "$dest"

        # 压缩的直接软链接，未压缩的重新压缩
        if [[ "$fq" == *.gz ]]; then
            ln -sf "$fq" "${dest}/${fname}"
        else
            gzip -c "$fq" > "${dest}/${fname}.gz"
        fi
        ((classified++))

    done < <(find "$DIR_EXTRACTED" \
        \( -name "*.fastq.gz" -o -name "*.fastq" -o -name "*.fq.gz" -o -name "*.fq" \) | sort)

    log_info "共分类 $classified 个 fastq 文件"

    # 4. 打印样本汇总
    log_step "样本汇总"
    local sample_count=0
    while IFS= read -r sdir; do
        local sname; sname=$(basename "$sdir")
        local nfiles; nfiles=$(find "$sdir" -name "*.fastq.gz" | wc -l)
        log_info "  $sname : $nfiles 个文件"
        ((sample_count++))
    done < <(find "$DIR_CLASSIFIED" -maxdepth 1 -mindepth 1 -type d | sort)

    log_info "────────────────────────────"
    log_info "总样本数: $sample_count"
    log_info "日志: $LOG_FILE"
    log_step "MODULE 00 完成 ✓"
}

main "$@"
