#!/bin/bash
###############################################################################
#  main_pipeline.sh — 主控脚本
#  Japan S. chromogenes WGS 分析流程
#
#  完整流程（含两次 Kraken2）：
#    00  解压 & 分类
#    01b Kraken2（原始 reads）— QC 前物种确认
#    01  FastQC 原始质控
#    02  Trim Galore
#    03  SPAdes 组装
#    06  Kraken2（contigs）— 组装纯度验证
#    04  QUAST 组装质控（MU 970 参考）
#    05  Prokka 注释
#
#  用法：
#    bash main_pipeline.sh              # 全流程
#    bash main_pipeline.sh --from 03    # 从第3步（组装）继续
#    bash main_pipeline.sh --only 01b   # 只跑第一次 Kraken2
#    bash main_pipeline.sh --skip 06    # 跳过某步（可多次指定）
#    bash main_pipeline.sh --dry-run    # 预览流程，不实际执行
###############################################################################

set -euo pipefail

PIPELINE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="${PIPELINE_DIR}"
CONFIG="${PIPELINE_DIR}/config.sh"

source "${PIPELINE_DIR}/utils.sh"
source "$CONFIG"

mkdir -p "${DIR_LOGS}"
MASTER_LOG="${DIR_LOGS}/pipeline_$(date '+%Y%m%d_%H%M%S').log"
LOG_FILE="$MASTER_LOG"

# ── 模块注册表（执行顺序即数组顺序）────────────────────────────────────────
declare -A MODULE_NAME=(
    [00]="解压 & 分类"
    [01b]="Kraken2 — 原始 reads 物种鉴定（QC 前）"
    [01]="FastQC 原始质控"
    [02]="Trim Galore 修剪"
    [03]="SPAdes 基因组组装"
    [06]="Kraken2 — 组装 contigs 纯度验证"
    [06b]="FastANI — 物种确认 (ANI ≥ 95%)"
    [04]="QUAST 组装质控（参考：MU 970）"
    [05]="Prokka 基因组注释"
)
MODULE_ORDER=(00 01b 01 02 03 06 06b 04 05)

# ── 参数解析 ──────────────────────────────────────────────────────────────────
FROM_STEP="00"
ONLY_STEP=""
SKIP_STEPS=()
DRY_RUN=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --from)    FROM_STEP="$2";          shift 2 ;;
        --only)    ONLY_STEP="$2";          shift 2 ;;
        --skip)    SKIP_STEPS+=("$2");      shift 2 ;;
        --dry-run) DRY_RUN=1;              shift   ;;
        --help|-h)
            echo "用法: bash main_pipeline.sh [选项]"
            echo ""
            echo "  --from  N    从第 N 步开始 (默认 00)"
            echo "  --only  N    只运行第 N 步"
            echo "  --skip  N    跳过第 N 步 (可多次指定)"
            echo "  --dry-run    仅打印将执行的步骤，不实际运行"
            echo ""
            echo "模块列表:"
            for m in "${MODULE_ORDER[@]}"; do
                echo "  $m  ${MODULE_NAME[$m]}"
            done
            exit 0 ;;
        *) log_warn "未知参数: $1"; shift ;;
    esac
done

# ── 判断是否跳过某步 ─────────────────────────────────────────────────────────
should_run() {
    local step="$1"
    # --only 模式
    [[ -n "$ONLY_STEP" ]] && [[ "$step" != "$ONLY_STEP" ]] && return 1
    # --from 模式
    [[ "$step" < "$FROM_STEP" ]] && return 1
    # --skip 检查
    for s in "${SKIP_STEPS[@]:-}"; do
        [[ "$step" == "$s" ]] && return 1
    done
    return 0
}

# ── 运行单个模块 ─────────────────────────────────────────────────────────────
run_module() {
    local step="$1"
    local script="${MODULES_DIR}/module_${step}_*.sh"
    local script_path
    script_path=$(ls ${script} 2>/dev/null | head -1)

    if [[ -z "$script_path" ]]; then
        log_error "模块脚本未找到: module_${step}_*.sh"
        return 1
    fi

    log_step "STEP ${step}: ${MODULE_NAME[$step]}"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        log_info "  [DRY RUN] 将执行: $script_path"
        return 0
    fi

    local start_ts; start_ts=$(date +%s)
    bash "$script_path" 2>&1 | tee -a "$MASTER_LOG"
    local exit_code=${PIPESTATUS[0]}
    local end_ts; end_ts=$(date +%s)
    local elapsed=$(( end_ts - start_ts ))

    if [[ $exit_code -eq 0 ]]; then
        log_info "✓ STEP ${step} 完成 (用时 ${elapsed}s)"
    else
        log_error "✗ STEP ${step} 失败 (exit $exit_code)"
        return $exit_code
    fi
}

# ── 主流程 ────────────────────────────────────────────────────────────────────
main() {
    log_step "Japan S. chromogenes WGS Pipeline 启动"
    log_info "配置文件: $CONFIG"
    log_info "主日志:   $MASTER_LOG"
    log_info ""

    # 打印将执行的步骤
    log_info "执行计划:"
    for step in "${MODULE_ORDER[@]}"; do
        if should_run "$step"; then
            log_info "  ✓ $step  ${MODULE_NAME[$step]}"
        else
            log_info "  — $step  ${MODULE_NAME[$step]}  [跳过]"
        fi
    done

    [[ "$DRY_RUN" -eq 1 ]] && { log_info "DRY RUN 结束"; exit 0; }

    echo ""
    local pipeline_start; pipeline_start=$(date +%s)
    local failed_steps=()

    for step in "${MODULE_ORDER[@]}"; do
        if should_run "$step"; then
            run_module "$step" || {
                log_error "流程在 STEP ${step} 中断"
                failed_steps+=("$step")
                # 继续还是中止？默认中止
                break
            }
        fi
    done

    local pipeline_end; pipeline_end=$(date +%s)
    local total=$(( pipeline_end - pipeline_start ))

    echo ""
    log_step "流程结束"
    log_info "总用时: $(( total / 3600 ))h $(( (total % 3600) / 60 ))m $(( total % 60 ))s"

    if [[ ${#failed_steps[@]} -eq 0 ]]; then
        log_info "所有步骤成功完成 🎉"
    else
        log_error "失败步骤: ${failed_steps[*]}"
        exit 1
    fi

    log_info "主日志: $MASTER_LOG"
}

main "$@"