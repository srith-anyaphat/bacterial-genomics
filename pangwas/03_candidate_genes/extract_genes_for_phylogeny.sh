#!/bin/bash

echo "Extracting individual genes for phylogenetic analysis..."
echo ""

python3 << 'PYEOF'
import os
from Bio import SeqIO
from collections import defaultdict
import re

gene_sequences = defaultdict(lambda: {'nucleotide': [], 'protein': []})

if not os.path.exists('easyfig_files'):
    print("Error: easyfig_files directory not found!")
    exit(1)

os.makedirs('phylogeny_genes', exist_ok=True)

print("Extracting genes from GenBank files...")
for gbk_file in sorted(os.listdir('easyfig_files')):
    if not gbk_file.endswith('.gbk'):
        continue
    
    sample = gbk_file.replace('.gbk', '')
    gbk_path = os.path.join('easyfig_files', gbk_file)
    
    for record in SeqIO.parse(gbk_path, 'genbank'):
        for feature in record.features:
            if feature.type == 'CDS':
                gene = feature.qualifiers.get('gene', [''])[0]
                product = feature.qualifiers.get('product', [''])[0]
                
                # Determine gene name
                if gene:
                    gene_name = gene.lower()
                else:
                    match = re.search(r'(esa[A-Za-z]|ess[A-Za-z]|esx[A-Za-z])', product, re.IGNORECASE)
                    if match:
                        gene_name = match.group(1).lower()
                    else:
                        continue
                
                # Extract sequences
                nuc_seq = feature.extract(record.seq)
                
                try:
                    prot_seq = nuc_seq.translate(to_stop=True)
                    
                    gene_sequences[gene_name]['nucleotide'].append({
                        'id': f"{sample}_{gene_name}",
                        'seq': str(nuc_seq),
                        'description': f"{sample} {product}"
                    })
                    
                    gene_sequences[gene_name]['protein'].append({
                        'id': f"{sample}_{gene_name}",
                        'seq': str(prot_seq),
                        'description': f"{sample} {product}"
                    })
                except:
                    pass

# Write FASTA files
print("\nWriting gene sequences:")
for gene_name, seqs in sorted(gene_sequences.items()):
    if seqs['nucleotide']:
        nuc_file = os.path.join('phylogeny_genes', f"{gene_name}_nucleotide.fna")
        with open(nuc_file, 'w') as f:
            for seq in seqs['nucleotide']:
                f.write(f">{seq['id']} {seq['description']}\n")
                f.write(f"{seq['seq']}\n")
        print(f"✓ {gene_name}: {len(seqs['nucleotide'])} nucleotide sequences")
    
    if seqs['protein']:
        prot_file = os.path.join('phylogeny_genes', f"{gene_name}_protein.faa")
        with open(prot_file, 'w') as f:
            for seq in seqs['protein']:
                f.write(f">{seq['id']} {seq['description']}\n")
                f.write(f"{seq['seq']}\n")

print(f"\nGene sequences saved to: phylogeny_genes/")
PYEOF

echo ""
echo "Building phylogenetic trees..."

cd phylogeny_genes

for gene_file in *_protein.faa; do
    gene_name=$(basename "$gene_file" _protein.faa)
    num_seqs=$(grep -c "^>" "$gene_file")
    
    if [ $num_seqs -lt 4 ]; then
        echo "Skipping $gene_name: only $num_seqs sequences"
        continue
    fi
    
    echo "Processing $gene_name ($num_seqs sequences)..."
    
    # Align with MAFFT
    mafft --auto --quiet "$gene_file" > "${gene_name}_aligned.faa" 2>/dev/null
    
    # Build tree with IQ-TREE
    iqtree2 -s "${gene_name}_aligned.faa" \
            -m MFP \
            -bb 1000 \
            -nt AUTO \
            -pre "${gene_name}" \
            --quiet >/dev/null 2>&1
    
    if [ -f "${gene_name}.treefile" ]; then
        echo "  ✓ Tree: ${gene_name}.treefile"
    fi
done

cd ..

echo ""
echo "Phylogenetic analysis complete!"
echo "Trees saved in: phylogeny_genes/"

