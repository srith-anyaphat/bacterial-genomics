#!/bin/bash
#=============================================================
# PanTools Pan-genome Analysis — September run
# Set 1: persist        (strains A F J V Y — event-persistent)
# Set 2: transient      (strains A F J V Y — event-transient)
# Set 3: real_transient (strains B E G K M — transient strains)
#
# Parameters:
#   --relaxation=4       (standard for intraspecies bacterial)
#   --core-threshold=95  (conservative for n=5; ≥5/5 genomes)
#=============================================================

set -eo pipefail


# ── Conda environment ────────────────────────────────────────
set +u
source "${PROJECT_ROOT}/miniconda3/etc/profile.d/conda.sh"
conda activate pantools
set -u

# ── Paths ────────────────────────────────────────────────────
FNA_SRC="${PROJECT_ROOT}/sequences/prokka/fna"
GFF_SRC="${PROJECT_ROOT}/sequences/prokka/gff"
WORKDIR="${PROJECT_ROOT}/paper3/pantools_Sep"

# ── Genome arrays ────────────────────────────────────────────
SET1_GENOMES=(genome_126 genome_46 genome_51 genome_103 genome_113)  # strains A F J V Y
SET2_GENOMES=(genome_13  genome_14  genome_27  genome_106  genome_87)  # strains A F J V Y (event-transient)
SET3_GENOMES=(genome_42  genome_40  genome_22  genome_29  genome_142)  # strains B E G K M

SET1_TYPE="persistent"
SET2_TYPE="transient"
SET3_TYPE="real_transient"

#=============================================================
# Helper: สร้าง input files สำหรับ 1 set
#=============================================================
make_inputs() {
    local SET_DIR="$1"
    local PHENO_TYPE="$2"
    shift 2
    local GENOMES=("$@")

    local GENOME_LIST="${SET_DIR}/genome_list.txt"
    local ANNOT_LIST="${SET_DIR}/annotation_list.txt"
    local PHENOTYPE="${SET_DIR}/phenotypes.csv"

    # genome_list.txt — path .fna เท่านั้น ไม่มีเลข
    > "${GENOME_LIST}"
    for g in "${GENOMES[@]}"; do
        echo "${FNA_SRC}/${g}.fna" >> "${GENOME_LIST}"
    done

    # annotation_list.txt — เลข genome นำหน้า (tab-separated)
    > "${ANNOT_LIST}"
    local i=1
    for g in "${GENOMES[@]}"; do
        printf "%d\t%s\n" "${i}" "${GFF_SRC}/${g}.gff" >> "${ANNOT_LIST}"
        ((i++))
    done

    # phenotypes.csv — column "Type"
    echo "genome,Type" > "${PHENOTYPE}"
    local j=1
    for g in "${GENOMES[@]}"; do
        echo "${j},${PHENO_TYPE}" >> "${PHENOTYPE}"
        ((j++))
    done

    echo "  Input files created in ${SET_DIR}"
}

#=============================================================
# Helper: รัน full PanTools pipeline สำหรับ 1 set (sequential)
#=============================================================
run_pantools_set() {
    local LABEL="$1"
    local SET_DIR="$2"
    local PHENO_TYPE="$3"
    shift 3
    local GENOMES=("$@")

    local PANGENOME="${SET_DIR}/pangenome"
    local GENOME_LIST="${SET_DIR}/genome_list.txt"
    local ANNOT_LIST="${SET_DIR}/annotation_list.txt"
    local PHENOTYPE="${SET_DIR}/phenotypes.csv"
    local LOG="${SET_DIR}/pantools_${LABEL}.log"

    {
    echo "============================================"
    echo " START: ${LABEL}  $(date)"
    echo "============================================"

    # ── Step 1: build_pangenome ──────────────────────────────
    echo "[${LABEL}] Step 1/7: build_pangenome..."
    pantools build_pangenome \
        "${PANGENOME}" \
        "${GENOME_LIST}"
    echo "[${LABEL}] Step 1 done."

    # ── Step 2: add_annotations ──────────────────────────────
    echo "[${LABEL}] Step 2/7: add_annotations..."
    pantools add_annotations \
        --connect \
        "${PANGENOME}" \
        "${ANNOT_LIST}"
    echo "[${LABEL}] Step 2 done."

    # ── Step 3: busco_protein ────────────────────────────────
    echo "[${LABEL}] Step 3/7: busco_protein..."
    cd "${SET_DIR}"
    pantools busco_protein \
        --odb10=bacteria_odb10 \
        pangenome
    cd - > /dev/null
    echo "[${LABEL}] Step 3 done."

    # ── Step 4: group (homology) ─────────────────────────────
    echo "[${LABEL}] Step 4/7: group --relaxation=4..."
    pantools group \
        --relaxation=4 \
        "${PANGENOME}"
    echo "[${LABEL}] Step 4 done."

    # ── Step 5: add_phenotypes ───────────────────────────────
    echo "[${LABEL}] Step 5/7: add_phenotypes..."
    pantools add_phenotypes \
        "${PANGENOME}" \
        "${PHENOTYPE}"
    echo "[${LABEL}] Step 5 done."

    # ── Step 6: gene_classification ──────────────────────────
    echo "[${LABEL}] Step 6/7: gene_classification --core-threshold=95..."
    pantools gene_classification \
        --phenotype=Type \
        --core-threshold=95 \
        "${PANGENOME}"
    echo "[${LABEL}] Step 6 done."

    # ── Step 7: pangenome_structure + R scripts ───────────────
    echo "[${LABEL}] Step 7/7: pangenome_structure..."
    pantools pangenome_structure "${PANGENOME}"

    echo "[${LABEL}] Running R scripts..."
    RESULTS_DIR="${PANGENOME}/pangenome_structure"
    if [[ -d "${RESULTS_DIR}" ]]; then
        cd "${RESULTS_DIR}"
        Rscript pangenome_growth.R
        Rscript gains_losses_median_and_average.R
        Rscript heaps_law.R
        cd - > /dev/null
    else
        echo "[${LABEL}] WARNING: pangenome_structure output dir not found, skipping R scripts."
    fi
    echo "[${LABEL}] Step 7 done."

    echo "============================================"
    echo " DONE: ${LABEL}  $(date)"
    echo "============================================"

    } >> "${LOG}" 2>&1
}

#=============================================================
# 1. สร้าง folder structure + input files
#=============================================================
echo "[Setup] Creating directories and input files..."

mkdir -p "${WORKDIR}/set1_persist/pangenome"
mkdir -p "${WORKDIR}/set2_transient/pangenome"
mkdir -p "${WORKDIR}/set3_real_transient/pangenome"

make_inputs "${WORKDIR}/set1_persist"        "${SET1_TYPE}" "${SET1_GENOMES[@]}"
make_inputs "${WORKDIR}/set2_transient"      "${SET2_TYPE}" "${SET2_GENOMES[@]}"
make_inputs "${WORKDIR}/set3_real_transient" "${SET3_TYPE}" "${SET3_GENOMES[@]}"

echo "[Setup] Done."

#=============================================================
# 2. Launch all 3 sets in parallel (nohup background)
#=============================================================
echo ""
echo "[Run] Launching all 3 PanTools pipelines in background..."

nohup bash -c "$(declare -f run_pantools_set make_inputs); \
    run_pantools_set set1_persist \
    '${WORKDIR}/set1_persist' '${SET1_TYPE}' ${SET1_GENOMES[*]}" \
    > "${WORKDIR}/set1_persist/nohup_set1.log" 2>&1 &
PID1=$!
echo "  set1_persist       PID: ${PID1}"

nohup bash -c "$(declare -f run_pantools_set make_inputs); \
    run_pantools_set set2_transient \
    '${WORKDIR}/set2_transient' '${SET2_TYPE}' ${SET2_GENOMES[*]}" \
    > "${WORKDIR}/set2_transient/nohup_set2.log" 2>&1 &
PID2=$!
echo "  set2_transient     PID: ${PID2}"

nohup bash -c "$(declare -f run_pantools_set make_inputs); \
    run_pantools_set set3_real_transient \
    '${WORKDIR}/set3_real_transient' '${SET3_TYPE}' ${SET3_GENOMES[*]}" \
    > "${WORKDIR}/set3_real_transient/nohup_set3.log" 2>&1 &
PID3=$!
echo "  set3_real_transient PID: ${PID3}"

echo ""
echo "  All 3 pipelines launched. Waiting for completion..."
wait ${PID1} ${PID2} ${PID3}

echo ""
echo "================================================"
echo " PanTools pipeline complete!  $(date)"
echo " Results:"
echo "   Set 1 → ${WORKDIR}/set1_persist/pangenome/"
echo "   Set 2 → ${WORKDIR}/set2_transient/pangenome/"
echo "   Set 3 → ${WORKDIR}/set3_real_transient/pangenome/"
echo " Logs:"
echo "   ${WORKDIR}/set1_persist/pantools_set1_persist.log"
echo "   ${WORKDIR}/set2_transient/pantools_set2_transient.log"
echo "   ${WORKDIR}/set3_real_transient/pantools_set3_real_transient.log"
echo "================================================"
