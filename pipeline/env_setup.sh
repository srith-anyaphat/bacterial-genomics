#!/bin/bash
###############################################################################
#  env_setup.sh — Conda 环境配置
#  Japan S. chromogenes WGS 项目
#
#  使用方式：被各模块 source，不单独运行
#  更新工具环境：只改对应的 ENV_* 变量即可
###############################################################################

CONDA_BASE="${PROJECT_ROOT}/miniconda3"
CONDA_BIN="${CONDA_BASE}/bin/conda"

# ── 已确认的环境 ──────────────────────────────────────────────────────────────
ENV_FASTQC="${CONDA_BASE}/envs/fastqc"       # fastqc, (multiqc 待确认)
ENV_KRAKEN2="${CONDA_BASE}/envs/kraken2"     # kraken2, (bracken 待确认)
ENV_SPADES="${CONDA_BASE}/envs/fq2dna"       # spades.py ✓
ENV_PROKKA="${CONDA_BASE}/envs/prokka_env"   # prokka ✓
ENV_FASTANI="${CONDA_BASE}/envs/pantools"   # TODO: confirm env
# ── 待确认的环境（扫描后填入）────────────────────────────────────────────────
ENV_MULTIQC="${CONDA_BASE}/envs/fastqc"      # TODO: 确认 multiqc 所在环境
ENV_TRIM="${CONDA_BASE}/envs/pantools"   # trimmomatic
ENV_QUAST="${CONDA_BASE}/envs/pantools"       # TODO: quast.py 所在环境

# ── 核心调用函数 ──────────────────────────────────────────────────────────────
# 用法：run_in_env LABEL ENV_PATH COMMAND [ARGS...]
run_in_env() {
    local label="$1" env_path="$2"; shift 2
    if [[ ! -d "$env_path" ]]; then
        log_error "conda 环境不存在: $env_path  (模块: $label)"
        log_error "请在 config/env_setup.sh 中更新对应的 ENV_* 路径"
        return 1
    fi
    log_info "执行: $label  [env: $(basename "$env_path")]"
    log_info "命令: $*"
    if ! nice -n "${NICE_VALUE:-10}" \
            "$CONDA_BIN" run --no-capture-output -p "$env_path" \
            "$@" >> "${LOG_FILE:-/dev/stderr}" 2>&1; then
        log_error "$label 失败"
        return 1
    fi
    log_info "$label 完成"
}

# ── 环境+工具检查（启动时调用）───────────────────────────────────────────────
check_env_tool() {
    local label="$1" env_path="$2" tool="$3"
    if [[ ! -d "$env_path" ]]; then
        log_error "  ✗ [$label] env not found: $env_path"
        return 1
    fi
    if [[ ! -f "${env_path}/bin/${tool}" ]]; then
        log_error "  ✗ [$label] $tool not found in $(basename "$env_path")"
        return 1
    fi
    log_info "  ✓ [$label] $tool — OK"
}
ENV_PLASMID="${CONDA_BASE}/envs/plasmidfinder"
