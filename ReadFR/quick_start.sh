#!/bin/bash
#
# Quick Start Script for Genome QC Pipeline
# 213 FinalReport Files Processing with AlphaImpute2
#
# Usage: ./quick_start.sh
#

set -e

PIPELINE_ROOT="/home/dhlee/DKBLUPF90/ReadFR/Pipeline"

echo "========================================="
echo "  Genome QC Pipeline - Quick Start"
echo "========================================="
echo ""

# 디렉토리 구조 생성
echo "Step 1: Creating directory structure..."
mkdir -p ${PIPELINE_ROOT}/{Raw_Data/{ChipV1,ChipV2},QC_Results/{ChipV1,ChipV2},Merged_Data,Population_QC,Imputation,Final_Results}

echo "✓ Directory structure created"
echo ""

# Parameter 파일 템플릿 생성
echo "Step 2: Creating parameter file templates..."

cat > ${PIPELINE_ROOT}/parameter_v1 << 'EOF'
COMMENT PED file
PEDFile
/home/dhlee/DKBLUPF90/ReadFR/check/PED_Total.txt

COMMENT SNP FinalReport
SNPFile
[FINALREPORT_FILE]
ANIMAL-ARN 2
SNP_Name 1
Chr 10
Position 11
Allele1-AB 13
Allele2-AB 14
GC_Score 27
R-Intensity 25
GT_Score 29
Cluster_Sep 30

COMMENT MAP V1
MAPFile
/home/dhlee/DKBLUPF90/ReadFR/check/MAP_V1.txt
EOF

cat > ${PIPELINE_ROOT}/parameter_v2 << 'EOF'
COMMENT PED file
PEDFile
/home/dhlee/DKBLUPF90/ReadFR/check/PED_Total.txt

COMMENT SNP FinalReport
SNPFile
[FINALREPORT_FILE]
ANIMAL-ARN 2
SNP_Name 1
Chr 10
Position 11
Allele1-AB 13
Allele2-AB 14
GC_Score 27
R-Intensity 25
GT_Score 29
Cluster_Sep 30

COMMENT MAP V2
MAPFile
/home/dhlee/DKBLUPF90/ReadFR/check/MAP_V2.txt
EOF

echo "✓ Parameter templates created"
echo ""

# Batch 처리 스크립트 생성
echo "Step 3: Creating batch processing scripts..."

cat > ${PIPELINE_ROOT}/batch_qc_v1.sh << 'EOFBASH'
#!/bin/bash
# Chip V1 QC Processing

PARAM_TEMPLATE="../parameter_v1"
INPUT_DIR="Raw_Data/ChipV1"
OUTPUT_DIR="QC_Results/ChipV1"
LOG_DIR="QC_Results/ChipV1/logs"
READFR="/home/dhlee/DKBLUPF90/ReadFR/ReadFR"

mkdir -p ${OUTPUT_DIR} ${LOG_DIR}

total_files=$(ls ${INPUT_DIR}/*.txt 2>/dev/null | wc -l)
current=0

echo "Processing Chip V1 files (Total: ${total_files})"

for finalreport in ${INPUT_DIR}/*.txt; do
    current=$((current + 1))
    basename=$(basename ${finalreport} .txt)
    
    echo "[${current}/${total_files}] ${basename}"
    
    # Create temporary parameter file
    sed "s|\[FINALREPORT_FILE\]|${finalreport}|g" ${PARAM_TEMPLATE} > temp_param.txt
    
    # Run QC
    ${READFR} temp_param.txt > ${LOG_DIR}/${basename}.log 2>&1
    
    # Save GENO file
    if [ -f QC_PASSED_GENO.txt ]; then
        mv QC_PASSED_GENO.txt ${OUTPUT_DIR}/${basename}_GENO.txt
        echo "  ✓ GENO created"
    else
        echo "  ✗ No GENO output"
    fi
    
    rm -f temp_param.txt
done

echo "Chip V1 QC completed!"
EOFBASH

# V2 스크립트도 동일하게 생성 (V1과 경로만 다름)
sed 's/V1/V2/g; s/v1/v2/g' ${PIPELINE_ROOT}/batch_qc_v1.sh > ${PIPELINE_ROOT}/batch_qc_v2.sh

chmod +x ${PIPELINE_ROOT}/batch_qc_*.sh

echo "✓ Batch processing scripts created"
echo ""

# 통합 스크립트 생성
cat > ${PIPELINE_ROOT}/merge_geno_files.sh << 'EOFMERGE'
#!/bin/bash
# Merge all GENO files

cd Merged_Data

OUTPUT="ALL_INDIVIDUALS_GENO.txt"

# Get header from first file
first_file=$(find ../QC_Results -name "*_GENO.txt" | head -1)
head -1 "$first_file" > ${OUTPUT}

# Merge all data (skip headers)
find ../QC_Results -name "*_GENO.txt" -exec tail -n +2 {} \; >> ${OUTPUT}

total=$(tail -n +2 ${OUTPUT} | wc -l)
echo "Merged ${total} individuals into ${OUTPUT}"

# Check duplicates
awk 'NR>1 {print $1}' ${OUTPUT} | sort | uniq -d > duplicates.txt
if [ -s duplicates.txt ]; then
    echo "Warning: Found $(wc -l < duplicates.txt) duplicate IDs"
else
    echo "No duplicates found"
    rm duplicates.txt
fi
EOFMERGE

chmod +x ${PIPELINE_ROOT}/merge_geno_files.sh

echo "✓ Merge script created"
echo ""

echo "========================================="
echo "  Setup completed successfully!"
echo "========================================="
echo ""
echo "Next Steps:"
echo ""
echo "1. Copy your FinalReport files to:"
echo "   - ${PIPELINE_ROOT}/Raw_Data/ChipV1/"
echo "   - ${PIPELINE_ROOT}/Raw_Data/ChipV2/"
echo ""
echo "2. Run QC processing:"
echo "   cd ${PIPELINE_ROOT}"
echo "   ./batch_qc_v1.sh &"
echo "   ./batch_qc_v2.sh &"
echo ""
echo "3. Merge GENO files:"
echo "   cd ${PIPELINE_ROOT}"
echo "   ./merge_geno_files.sh"
echo ""
echo "4. See full documentation:"
echo "   /home/dhlee/DKBLUPF90/ReadFR/GenomeQC_Pipeline_Guide.pdf"
echo ""
