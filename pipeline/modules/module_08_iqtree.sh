#!/bin/bash
###############################################################################
#  module_08_iqtree.sh
#  Build maximum likelihood phylogenetic tree from Roary core genome alignment
#
#  Input:  core_gene_alignment.aln from Roary (11_roary/)
#  Output: 12_phylogeny/ — ML tree, bootstrap support
###############################################################################

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/utils.sh"
source "${SCRIPT_DIR}/config.sh"
source "${SCRIPT_DIR}/env_setup.sh"

mkdir -p "${DIR_LOGS}"
LOG_FILE="${DIR_LOGS}/08_iqtree_$(date '+%Y%m%d_%H%M%S').log"

ROARY_DIR="${PROJECT_ROOT}/japan/11_roary"
OUT_DIR="${PROJECT_ROOT}/japan/12_phylogeny"
ENV="${PROJECT_ROOT}/miniconda3/envs/iqtree_env"
THREADS=16
BOOTSTRAP=1000  # ultrafast bootstrap replicates

main() {
    log_step "MODULE 08: IQ-TREE phylogenetic tree"

    local aln="${ROARY_DIR}/core_gene_alignment.aln"
    if [[ ! -f "$aln" ]]; then
        log_error "Core genome alignment not found: $aln"
        log_error "Please run module_07_roary.sh first"
        exit 1
    fi

    local n_seqs; n_seqs=$(grep -c "^>" "$aln")
    log_info "Sequences in alignment: $n_seqs"
    log_info "Bootstrap replicates: $BOOTSTRAP"

    mkdir -p "$OUT_DIR"

    # Run IQ-TREE with GTR+G model (standard for core genome alignments)
    # -B = ultrafast bootstrap, -alrt = SH-aLRT test, --redo = overwrite
    run_in_env "IQ-TREE" "$ENV" \
        iqtree \
            -s "$aln" \
            -m GTR+G \
            -B "$BOOTSTRAP" \
            -alrt 1000 \
            -T "$THREADS" \
            --prefix "${OUT_DIR}/S_chromogenes_japan" \
            --redo

    log_step "Phylogeny summary"
    log_info "Tree file:    ${OUT_DIR}/S_chromogenes_japan.treefile"
    log_info "Log file:     ${OUT_DIR}/S_chromogenes_japan.log"
    log_info "Model report: ${OUT_DIR}/S_chromogenes_japan.iqtree"
    log_info ""
    log_info "Visualize with: FigTree, iTOL, or GrapeTree"
    log_step "MODULE 08 complete ✓"
}

main "$@"
