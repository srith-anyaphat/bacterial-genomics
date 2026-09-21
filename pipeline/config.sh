#!/bin/bash
###############################################################################
#  config.sh — 全局配置文件
#  Japan S. chromogenes WGS 项目
#  修改路径和参数后其他脚本自动继承
###############################################################################

# ── 项目根目录 ────────────────────────────────────────────────────────────────
export PROJECT_ROOT="${PROJECT_ROOT}/japan"
export RAW_DATA_DIR="${PROJECT_ROOT}/raw_data"          # 原始压缩包所在目录

# ── 各阶段输出目录 ────────────────────────────────────────────────────────────
export DIR_EXTRACTED="${PROJECT_ROOT}/01_extracted"     # 解压后的 fastq
export DIR_CLASSIFIED="${PROJECT_ROOT}/02_classified"   # 按样本分类整理
export DIR_QC_RAW="${PROJECT_ROOT}/03_qc_raw"           # FastQC 原始质控报告
export DIR_TRIMMED="${PROJECT_ROOT}/04_trimmed"         # Trim Galore 后的 reads
export DIR_QC_TRIM="${PROJECT_ROOT}/05_qc_trimmed"      # FastQC 修剪后质控报告
export DIR_ASSEMBLY="${PROJECT_ROOT}/06_assembly"       # SPAdes 组装结果
export DIR_ASSEMBLY_QC="${PROJECT_ROOT}/07_assembly_qc" # QUAST 组装质控
export DIR_ANNOTATION="${PROJECT_ROOT}/08_annotation"   # Prokka 注释结果
export DIR_LOGS="${PROJECT_ROOT}/logs"                  # 所有日志

# ── 工具路径（如果不在 PATH 里则在此指定完整路径） ────────────────────────────
export FASTQC="fastqc"
export MULTIQC="multiqc"
export TRIM_GALORE="trim_galore"
export SPADES="spades.py"
export QUAST="quast.py"
export PROKKA="prokka"

# ── FastQC 参数 ───────────────────────────────────────────────────────────────
export FASTQC_THREADS=8

# ── Trim Galore 参数 ──────────────────────────────────────────────────────────
export TRIM_QUALITY=20          # --quality
export TRIM_LENGTH=50           # --length (丢弃短于此的 reads)
export TRIM_CORES=4             # --cores

# ── SPAdes 参数 ───────────────────────────────────────────────────────────────
export SPADES_THREADS=16
export SPADES_MEMORY=64         # GB
export SPADES_KMERS="21,33,55,77"   # -k

# ── QUAST 参数 ────────────────────────────────────────────────────────────────
export QUAST_THREADS=8
export QUAST_MIN_CONTIG=500     # --min-contig
# MU 970 参考基因组（bovine mastitis 经典株，~2.34 Mb）
export QUAST_REFERENCE="${PROJECT_ROOT}/japan/Analysis/Chromogenes_MU970_reference_genome.fna"

# ── Kraken2 参数 ──────────────────────────────────────────────────────────────
export KRAKEN2_DB="${PROJECT_ROOT}/PhD_Yang/kraken2"   # hash.k2d 所在目录
export KRAKEN2_THREADS=8
export KRAKEN2_CONFIDENCE=0.05  # 置信度阈值（lite db 推荐适当放宽，0.0~0.1）
export DIR_KRAKEN2_RAW="${PROJECT_ROOT}/02b_kraken2_raw"    # 第1次：原始 reads（QC 前）
export DIR_KRAKEN2_ASSM="${PROJECT_ROOT}/09_kraken2_assm"   # 第2次：assembly contigs

# ── Prokka 参数 ───────────────────────────────────────────────────────────────
export PROKKA_GENUS="Staphylococcus"
export PROKKA_SPECIES="chromogenes"
export PROKKA_KINGDOM="Bacteria"
export PROKKA_THREADS=8
export PROKKA_PREFIX="S_chromogenes"  # 输出文件前缀

# ── 解压/分类规则 ─────────────────────────────────────────────────────────────
# 支持的压缩格式（自动识别）
export SUPPORTED_EXTS="tar.gz tgz tar.bz2 tbz2 tar.xz zip gz bz2"

# 样本名解析：从文件名提取样本 ID 的 sed 正则
# 示例：SRR12345_1.fastq.gz → SRR12345
# 根据实际命名规则调整
export SAMPLE_REGEX='s/_[12]\.fastq\.gz$//; s/\.fastq\.gz$//'

# ── nice 值（服务器礼貌使用） ─────────────────────────────────────────────────
export NICE_VALUE=10

export FASTANI_REF="${PROJECT_ROOT}/japan/Analysis/Chromogenes_MU970_reference_genome.fna"
export DIR_FASTANI="${PROJECT_ROOT}/10_fastani"