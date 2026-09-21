#!/bin/bash
###############################################################################
#  utils.sh — 公共工具函数
#  被所有模块 source 引用，不单独运行
###############################################################################

# ── 日志函数 ──────────────────────────────────────────────────────────────────
LOG_FILE=""  # 由各模块在调用前设置

log_info()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [INFO]  $*" | tee -a "${LOG_FILE:-/dev/stderr}"; }
log_warn()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN]  $*" | tee -a "${LOG_FILE:-/dev/stderr}" >&2; }
log_error() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] $*" | tee -a "${LOG_FILE:-/dev/stderr}" >&2; }
log_step()  { echo "" | tee -a "${LOG_FILE:-/dev/stderr}"
              echo "════════════════════════════════════════" | tee -a "${LOG_FILE:-/dev/stderr}"
              echo "[$(date '+%Y-%m-%d %H:%M:%S')] ▶  $*"   | tee -a "${LOG_FILE:-/dev/stderr}"
              echo "════════════════════════════════════════" | tee -a "${LOG_FILE:-/dev/stderr}"; }

# ── 检查命令是否可用 ──────────────────────────────────────────────────────────
check_tool() {
    local tool="$1"
    if ! command -v "$tool" &>/dev/null; then
        log_error "工具未找到: $tool — 请激活对应 conda 环境或检查 PATH"
        return 1
    fi
    log_info "  ✓ $tool $(${tool} --version 2>&1 | head -1)"
    return 0
}

check_all_tools() {
    local failed=0
    for tool in fastqc trim_galore multiqc spades.py quast.py prokka; do
        check_tool "$tool" || ((failed++))
    done
    return $failed
}

# ── 创建目录（幂等） ──────────────────────────────────────────────────────────
make_dirs() {
    for d in "$@"; do
        mkdir -p "$d" && log_info "  目录就绪: $d"
    done
}

# ── 检查文件是否存在且非空 ────────────────────────────────────────────────────
require_file() {
    if [[ ! -s "$1" ]]; then
        log_error "文件不存在或为空: $1"
        return 1
    fi
}

# ── 获取样本列表（从 classified 目录） ───────────────────────────────────────
get_sample_list() {
    local base_dir="${1:-$DIR_CLASSIFIED}"
    find "$base_dir" -maxdepth 1 -mindepth 1 -type d | sort | xargs -I{} basename {}
}

# ── 判断 reads 是否为 paired-end ─────────────────────────────────────────────
is_paired() {
    local sample_dir="$1"
    local r1 r2
    r1=$(find "$sample_dir" -name "*_1.fastq.gz" -o -name "*_R1*.fastq.gz" 2>/dev/null | head -1)
    r2=$(find "$sample_dir" -name "*_2.fastq.gz" -o -name "*_R2*.fastq.gz" 2>/dev/null | head -1)
    [[ -n "$r1" && -n "$r2" ]]
}

# ── 获取样本的 R1/R2 路径 ─────────────────────────────────────────────────────
get_reads() {
    local sample_dir="$1"
    R1=$(find "$sample_dir" \( -name "*_1.fastq.gz" -o -name "*_R1*.fastq.gz" \) 2>/dev/null | sort | head -1)
    R2=$(find "$sample_dir" \( -name "*_2.fastq.gz" -o -name "*_R2*.fastq.gz" \) 2>/dev/null | sort | head -1)
}

# ── 进度条 ────────────────────────────────────────────────────────────────────
progress() {
    local current="$1" total="$2" sample="$3"
    local pct=$(( current * 100 / total ))
    printf "\r  进度: [%3d%%] %d/%d  %s" "$pct" "$current" "$total" "$sample"
}

# ── 运行命令并记录，出错则退出 ───────────────────────────────────────────────
run_cmd() {
    local label="$1"; shift
    log_info "执行: $label"
    log_info "命令: $*"
    if ! nice -n "${NICE_VALUE:-10}" "$@" >> "${LOG_FILE:-/dev/stderr}" 2>&1; then
        log_error "$label 失败 (exit $?)"
        return 1
    fi
    log_info "$label 完成"
}

# ── 汇总统计行（追加到 TSV） ─────────────────────────────────────────────────
append_stat() {
    local tsv="$1"; shift
    echo -e "$*" >> "$tsv"
}
