#!/bin/bash
###############################################################################
#  scan_raw_data.sh — 运行前先扫描，了解数据情况
#  在正式跑流程之前，先执行这个脚本确认数据结构
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/utils/utils.sh"
source "${SCRIPT_DIR}/config/config.sh"

echo "════════════════════════════════════════════════════════"
echo "  Japan S. chromogenes — 数据扫描报告"
echo "  $(date)"
echo "════════════════════════════════════════════════════════"

echo ""
echo "【原始数据目录】"
echo "  $RAW_DATA_DIR"

if [[ ! -d "$RAW_DATA_DIR" ]]; then
    echo "  ⚠️  目录不存在！请检查 config.sh 中的 RAW_DATA_DIR"
    exit 1
fi

echo ""
echo "【压缩包列表】"
find "$RAW_DATA_DIR" -maxdepth 2 \
    \( -name "*.tar.gz" -o -name "*.tgz" -o -name "*.tar.bz2" \
       -o -name "*.tar.xz" -o -name "*.zip" -o -name "*.gz" -o -name "*.bz2" \) \
    | sort \
    | while read -r f; do
        local_size=$(du -sh "$f" 2>/dev/null | cut -f1)
        echo "  $local_size  $(basename "$f")"
      done

echo ""
echo "【压缩包数量】"
find "$RAW_DATA_DIR" -maxdepth 2 \
    \( -name "*.tar.gz" -o -name "*.tgz" -o -name "*.tar.bz2" \
       -o -name "*.tar.xz" -o -name "*.zip" -o -name "*.gz" -o -name "*.bz2" \) \
    | wc -l | xargs -I{} echo "  {} 个文件"

echo ""
echo "【磁盘使用】"
du -sh "$RAW_DATA_DIR" 2>/dev/null | xargs -I{} echo "  原始数据大小: {}"

echo ""
echo "【预估解压后大小（×3 估算）】"
raw_kb=$(du -sk "$RAW_DATA_DIR" | cut -f1)
estimated_kb=$(( raw_kb * 3 ))
echo "  约 $(( estimated_kb / 1024 / 1024 )) GB"

echo ""
echo "【目标输出目录（当前是否存在）】"
for d in "$DIR_EXTRACTED" "$DIR_CLASSIFIED" "$DIR_QC_RAW" "$DIR_TRIMMED" \
          "$DIR_QC_TRIM" "$DIR_ASSEMBLY" "$DIR_ASSEMBLY_QC" "$DIR_ANNOTATION"; do
    if [[ -d "$d" ]]; then
        echo "  ✓ $(basename "$d")  ($d)"
    else
        echo "  — $(basename "$d")  (待创建)"
    fi
done

echo ""
echo "════════════════════════════════════════════════════════"
echo "  确认无误后运行：bash main_pipeline.sh"
echo "  如需只预览步骤：bash main_pipeline.sh --dry-run"
echo "════════════════════════════════════════════════════════"
