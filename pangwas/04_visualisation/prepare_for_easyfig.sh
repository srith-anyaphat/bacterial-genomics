#!/bin/bash

echo "Preparing files for EasyFig..."
echo ""

cd easyfig_files

# Count files
gbk_count=$(ls -1 *.gbk 2>/dev/null | wc -l)

if [ $gbk_count -eq 0 ]; then
    echo "Error: No GenBank files found!"
    exit 1
fi

echo "Found $gbk_count GenBank files"
echo ""

# Extract FASTA and create BLAST databases
echo "Creating FASTA files and BLAST databases..."

for gbk in *.gbk; do
    base=$(basename "$gbk" .gbk)
    echo "  Processing $base..."
    
    # Convert GenBank to FASTA
    python3 << PYEND
from Bio import SeqIO
try:
    SeqIO.convert("$gbk", "genbank", "${base}.fna", "fasta")
    print("    ✓ Created FASTA")
except Exception as e:
    print(f"    ❌ Error: {e}")
PYEND
    
    # Create BLAST database
    if [ -f "${base}.fna" ]; then
        makeblastdb -in ${base}.fna -dbtype nucl -out ${base} -parse_seqids > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "    ✓ Created BLAST database"
        fi
    fi
done

echo ""
echo "Creating instructions file..."

# Create instructions
cat > EASYFIG_INSTRUCTIONS.txt << 'INSTRUCTIONS'
================================================================================
                    EASYFIG VISUALIZATION INSTRUCTIONS
================================================================================

FILES IN THIS FOLDER:
---------------------
✓ .gbk files - GenBank format with complete Ess operon sequences
✓ .fna files - FASTA nucleotide sequences  
✓ BLAST database files (.nhr, .nin, .nsq)
✓ EXTRACTION_SUMMARY.txt - Detailed extraction report

STEPS TO CREATE YOUR FIGURE IN EASYFIG:
----------------------------------------

1. OPEN EASYFIG on Windows

2. ADD SEQUENCES:
   - Click "Add" button
   - Select .gbk files in the order you want (top to bottom)
   - Start with 4-6 samples to test
   - You can always add more later

3. RUN BLAST COMPARISONS:
   For each pair of adjacent sequences:
   - Click the "BLAST" button between them
   - Browse to select the corresponding .fna file
   - Set minimum % identity (start with 70%)
   - Click "Run BLAST"

4. CUSTOMIZE APPEARANCE:
   
   Colors for genes (to match your reference):
   - esaA, esaB → Green
   - essB, essC → Green
   - esxA, esxB → Green  
   - Hypothetical → Purple/Gray
   - Others → As appropriate
   
   Layout:
   - Adjust arrow sizes
   - Add/remove gene labels
   - Set uniform scale
   - Adjust spacing

5. EXPORT:
   - File → Export
   - Format: PNG (for presentations) or SVG/EPS (for publication)
   - Resolution: 600 dpi minimum

TIPS:
-----
- Load samples in phylogenetic or logical order
- Use consistent colors for orthologous genes
- Show % identity in shaded regions
- Label key genes clearly
- Include scale bar

TROUBLESHOOTING:
----------------
- If BLAST fails: Check that .fna files are in same folder
- If genes don't appear: Verify .gbk has CDS features
- Low similarity: Reduce minimum identity threshold (try 50-60%)

For questions, check EXTRACTION_SUMMARY.txt for details about each sample.

================================================================================
INSTRUCTIONS

echo "✓ Created EASYFIG_INSTRUCTIONS.txt"

cd ..

# Create archive
echo ""
echo "Creating compressed archive..."
tar -czf easyfig_files.tar.gz easyfig_files/
echo "✓ Created easyfig_files.tar.gz"

# Also create zip for Windows
if command -v zip &> /dev/null; then
    zip -q -r easyfig_files.zip easyfig_files/
    echo "✓ Created easyfig_files.zip"
fi

echo ""
echo "Files ready for transfer to Windows:"
echo "  - easyfig_files.tar.gz (download this)"
echo "  - easyfig_files.zip (or this for Windows)"
echo "  - OR the easyfig_files/ folder directly"

