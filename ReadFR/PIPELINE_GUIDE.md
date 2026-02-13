# 대규모 유전체 QC 및 Imputation 파이프라인
## 213개 FinalReport 파일 통합 분석 가이드

---

## 📋 개요

### 프로젝트 정보
- **총 파일 수**: 213개 FinalReport 파일
- **Chip Versions**: V1, V2 (2가지 버전)
- **MAP 파일**: V1, V2 모두 준비 완료
- **GENO Vector**: Chip version별 SNP position 자동 할당
- **Imputation Tool**: AlphaImpute2

### 파이프라인 구성
```
Phase 1: 개별 파일 QC (ReadFR 프로그램)
    ↓
Phase 2: GENO 파일 통합 및 검증
    ↓
Phase 3: 집단 수준 QC 분석
    ↓
Phase 4: AlphaImpute2 준비 및 실행
    ↓
Phase 5: 최종 검증 및 결과 생성
```

---

## 🔧 Phase 1: 개별 파일 QC 실행

### 1.1 디렉토리 구조 생성

```bash
cd /home/dhlee/DKBLUPF90/ReadFR
mkdir -p Pipeline/{Raw_Data,QC_Results,Merged_Data,Population_QC,Imputation,Final_Results}
cd Pipeline
```

### 1.2 FinalReport 파일 정리

```bash
# Chip Version별 디렉토리 준비
mkdir -p Raw_Data/{ChipV1,ChipV2}

# 파일 분류 (format 구조로 판별)
# 예시: V1은 62,163 SNPs, V2는 68,516 SNPs
for file in /path/to/finalreport/*.txt; do
    # SNP 개수로 버전 판별
    snp_count=$(grep -v "^\[" "$file" | tail -n +2 | wc -l)
    
    if [ $snp_count -gt 65000 ]; then
        cp "$file" Raw_Data/ChipV2/
    else
        cp "$file" Raw_Data/ChipV1/
    fi
done
```

### 1.3 Parameter 파일 준비

**parameter_v1** (Chip V1용):
```
COMMENT PED file
PEDFile
/home/dhlee/DKBLUPF90/ReadFR/check/PED_Total.txt

COMMENT SNP FinalReport
SNPFile
[DATA_PATH]/filename_v1.txt
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
```

**parameter_v2** (Chip V2용):
```
COMMENT PED file
PEDFile
/home/dhlee/DKBLUPF90/ReadFR/check/PED_Total.txt

COMMENT SNP FinalReport
SNPFile
[DATA_PATH]/filename_v2.txt
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
```

### 1.4 배치 처리 스크립트 작성

**batch_qc_v1.sh**:
```bash
#!/bin/bash
#
# Chip V1 FinalReport 파일 배치 QC 처리
#

PARAM_TEMPLATE="parameter_v1"
INPUT_DIR="Raw_Data/ChipV1"
OUTPUT_DIR="QC_Results/ChipV1"
LOG_DIR="QC_Results/ChipV1/logs"

mkdir -p ${OUTPUT_DIR} ${LOG_DIR}

# 파일 카운터
total_files=$(ls ${INPUT_DIR}/*.txt 2>/dev/null | wc -l)
current=0

echo "================================================================"
echo "Starting Chip V1 QC Processing"
echo "Total files: ${total_files}"
echo "================================================================"

for finalreport in ${INPUT_DIR}/*.txt; do
    current=$((current + 1))
    basename=$(basename ${finalreport} .txt)
    
    echo "[${current}/${total_files}] Processing: ${basename}"
    
    # Parameter 파일에 현재 파일 경로 설정
    sed "s|[DATA_PATH]/filename_v1.txt|${finalreport}|g" ${PARAM_TEMPLATE} > temp_param_${basename}.txt
    
    # ReadFR 실행
    ../../ReadFR temp_param_${basename}.txt > ${LOG_DIR}/${basename}.log 2>&1
    
    # QC_PASSED_GENO.txt 저장
    if [ -f QC_PASSED_GENO.txt ]; then
        mv QC_PASSED_GENO.txt ${OUTPUT_DIR}/${basename}_GENO.txt
        echo "  ✓ GENO file created: ${basename}_GENO.txt"
    else
        echo "  ✗ No GENO file generated for ${basename}"
    fi
    
    # 임시 파라미터 파일 삭제
    rm -f temp_param_${basename}.txt
done

echo "================================================================"
echo "Chip V1 QC Processing Completed"
echo "================================================================"
```

**batch_qc_v2.sh** (유사하게 작성, V2용):
```bash
#!/bin/bash
# (V1과 동일한 구조, parameter_v2 및 ChipV2 디렉토리 사용)
```

### 1.5 병렬 QC 실행

```bash
# 두 버전 동시 실행
chmod +x batch_qc_v1.sh batch_qc_v2.sh

# 백그라운드로 병렬 실행
./batch_qc_v1.sh > qc_v1.out 2>&1 &
PID_V1=$!

./batch_qc_v2.sh > qc_v2.out 2>&1 &
PID_V2=$!

# 완료 대기
wait $PID_V1
wait $PID_V2

echo "All QC processing completed!"
```

### 1.6 QC 결과 요약

```bash
# QC 통계 수집
cat > summarize_qc.sh << 'EOF'
#!/bin/bash

echo "=== QC Processing Summary ===" > QC_Summary.txt
echo "" >> QC_Summary.txt

# Chip V1 통계
echo "Chip V1 Results:" >> QC_Summary.txt
v1_files=$(ls QC_Results/ChipV1/*_GENO.txt 2>/dev/null | wc -l)
echo "  GENO files generated: ${v1_files}" >> QC_Summary.txt

v1_animals=0
if [ $v1_files -gt 0 ]; then
    for geno in QC_Results/ChipV1/*_GENO.txt; do
        count=$(tail -n +2 "$geno" | wc -l)
        v1_animals=$((v1_animals + count))
    done
fi
echo "  Total animals passed QC: ${v1_animals}" >> QC_Summary.txt
echo "" >> QC_Summary.txt

# Chip V2 통계
echo "Chip V2 Results:" >> QC_Summary.txt
v2_files=$(ls QC_Results/ChipV2/*_GENO.txt 2>/dev/null | wc -l)
echo "  GENO files generated: ${v2_files}" >> QC_Summary.txt

v2_animals=0
if [ $v2_files -gt 0 ]; then
    for geno in QC_Results/ChipV2/*_GENO.txt; do
        count=$(tail -n +2 "$geno" | wc -l)
        v2_animals=$((v2_animals + count))
    done
fi
echo "  Total animals passed QC: ${v2_animals}" >> QC_Summary.txt
echo "" >> QC_Summary.txt

# 전체 통계
echo "Overall Summary:" >> QC_Summary.txt
echo "  Total GENO files: $((v1_files + v2_files))" >> QC_Summary.txt
echo "  Total animals: $((v1_animals + v2_animals))" >> QC_Summary.txt

cat QC_Summary.txt
EOF

chmod +x summarize_qc.sh
./summarize_qc.sh
```

---

## 📊 Phase 2: GENO 파일 통합

### 2.1 MAP 파일 기반 SNP 위치 확인

```bash
# MAP V1 및 V2의 SNP 정보 확인
cd Merged_Data

# V1 SNP ID 추출
awk '{print $1, $2, $3}' ../../check/MAP_V1.txt | sort -k1,1n -k3,3n > snp_v1_sorted.txt

# V2 SNP ID 추출
awk '{print $1, $2, $3}' ../../check/MAP_V2.txt | sort -k1,1n -k3,3n > snp_v2_sorted.txt

# 통계 출력
echo "Chip V1 Total SNPs: $(wc -l < snp_v1_sorted.txt)"
echo "Chip V2 Total SNPs: $(wc -l < snp_v2_sorted.txt)"
```

### 2.2 GENO 파일 통합 스크립트

**merge_geno_files.sh**:
```bash
#!/bin/bash
#
# GENO 파일 통합 (Header 유지, 중복 제거)
#

OUTPUT="ALL_INDIVIDUALS_GENO.txt"
TEMP_HEADER="temp_header.txt"
TEMP_DATA="temp_data.txt"

echo "Starting GENO file merging..."

# Header 추출 (첫 번째 파일에서)
first_file=$(ls ../QC_Results/ChipV1/*_GENO.txt 2>/dev/null | head -1)
if [ -z "$first_file" ]; then
    first_file=$(ls ../QC_Results/ChipV2/*_GENO.txt 2>/dev/null | head -1)
fi

head -1 "$first_file" > ${TEMP_HEADER}

# 모든 GENO 파일의 데이터 병합 (header 제외)
> ${TEMP_DATA}

# Chip V1 파일들
for geno in ../QC_Results/ChipV1/*_GENO.txt; do
    tail -n +2 "$geno" >> ${TEMP_DATA}
done

# Chip V2 파일들
for geno in ../QC_Results/ChipV2/*_GENO.txt; do
    tail -n +2 "$geno" >> ${TEMP_DATA}
done

# Header + Data 결합
cat ${TEMP_HEADER} ${TEMP_DATA} > ${OUTPUT}

# 중복 개체 확인 (Animal_ID 기준)
echo ""
echo "Checking for duplicates..."
awk 'NR>1 {print $1}' ${OUTPUT} | sort | uniq -d > duplicates.txt

if [ -s duplicates.txt ]; then
    echo "Warning: Found duplicate Animal IDs:"
    cat duplicates.txt
    echo "Please review and remove duplicates manually."
else
    echo "No duplicates found."
    rm duplicates.txt
fi

# 통계
total_individuals=$(tail -n +2 ${OUTPUT} | wc -l)
echo ""
echo "=== Merge Summary ==="
echo "Total individuals in merged file: ${total_individuals}"
echo "Output file: ${OUTPUT}"

# 정리
rm -f ${TEMP_HEADER} ${TEMP_DATA}

echo "Merge completed successfully!"
```

### 2.3 GENO 형식 검증

```bash
# GENO 파일 무결성 검사
cat > validate_geno.sh << 'EOF'
#!/bin/bash

GENO_FILE="ALL_INDIVIDUALS_GENO.txt"

echo "=== GENO File Validation ==="

# 1. 파일 존재 확인
if [ ! -f ${GENO_FILE} ]; then
    echo "Error: ${GENO_FILE} not found!"
    exit 1
fi

# 2. Header 확인
header=$(head -1 ${GENO_FILE})
echo "Header: ${header}"

# 3. 개체 수 확인
n_individuals=$(tail -n +2 ${GENO_FILE} | wc -l)
echo "Total individuals: ${n_individuals}"

# 4. GENO vector 길이 확인 (첫 10개체)
echo ""
echo "Sample GENO vector lengths (first 10 individuals):"
tail -n +2 ${GENO_FILE} | head -10 | while read line; do
    animal_id=$(echo $line | awk '{print $1}')
    # GENO는 8번째 필드부터 (Animal_ID BREED SIRE DAM SEX BDate LOC GENO...)
    geno=$(echo $line | cut -d' ' -f8-)
    geno_len=${#geno}
    echo "  ${animal_id}: ${geno_len} characters"
done

echo ""
echo "Validation completed."
EOF

chmod +x validate_geno.sh
./validate_geno.sh
```

---

## 🔬 Phase 3: 집단 수준 QC 분석

### 3.1 Fortran 기반 집단 QC 프로그램 작성

**PopulationQC.f90** (신규 작성 필요):
```fortran
program PopulationQC
  use M_Kinds
  implicit none
  
  ! ================================================
  ! 집단 수준 QC 지표 계산
  ! - SNP Call Rate (SNP별 genotyping 성공률)
  ! - Allele Frequency (대립유전자 빈도)
  ! - Hardy-Weinberg Equilibrium (HWE)
  ! ================================================
  
  character(len=256) :: geno_file
  integer :: n_individuals, n_snps
  integer, allocatable :: geno(:,:)  ! (n_individuals, n_snps)
  
  ! QC 지표
  real, allocatable :: snp_call_rate(:)
  real, allocatable :: allele_freq(:)
  real, allocatable :: hwe_pvalue(:)
  
  ! Threshold
  real, parameter :: MIN_CALL_RATE = 0.90
  real, parameter :: MIN_MAF = 0.01
  real, parameter :: HWE_THRESHOLD = 1.0e-6
  
  call getarg(1, geno_file)
  
  ! 1. GENO 파일 읽기
  call read_geno_file(geno_file, geno, n_individuals, n_snps)
  
  ! 2. SNP Call Rate 계산
  allocate(snp_call_rate(n_snps))
  call calculate_snp_call_rate(geno, snp_call_rate, n_individuals, n_snps)
  
  ! 3. Allele Frequency 계산
  allocate(allele_freq(n_snps))
  call calculate_allele_frequency(geno, allele_freq, n_individuals, n_snps)
  
  ! 4. HWE 검정
  allocate(hwe_pvalue(n_snps))
  call test_hardy_weinberg(geno, hwe_pvalue, n_individuals, n_snps)
  
  ! 5. QC 필터링 및 리포트
  call filter_and_report(snp_call_rate, allele_freq, hwe_pvalue, n_snps, &
                         MIN_CALL_RATE, MIN_MAF, HWE_THRESHOLD)
  
  ! 6. QC passed SNP 리스트 저장
  call save_qc_passed_snps(snp_call_rate, allele_freq, hwe_pvalue, n_snps)
  
contains

  subroutine calculate_snp_call_rate(geno, call_rate, n_ind, n_snp)
    integer, intent(in) :: geno(:,:), n_ind, n_snp
    real, intent(out) :: call_rate(:)
    integer :: i, j, valid_count
    
    do j = 1, n_snp
      valid_count = 0
      do i = 1, n_ind
        if (geno(i,j) /= 9) valid_count = valid_count + 1
      end do
      call_rate(j) = real(valid_count) / real(n_ind)
    end do
  end subroutine
  
  ! (기타 subroutine 생략)
  
end program PopulationQC
```

### 3.2 집단 QC 실행

```bash
cd ../Population_QC

# Fortran 컴파일
gfortran -O2 -o PopulationQC PopulationQC.f90 \
    -I../../include -L../../lib -ldkblupf90

# 실행
./PopulationQC ../Merged_Data/ALL_INDIVIDUALS_GENO.txt > population_qc.log

# 결과 파일 생성:
# - snp_call_rate.txt
# - allele_frequency.txt
# - hwe_test.txt
# - qc_passed_snps.txt
```

### 3.3 집단 QC 리포트

```bash
cat > generate_pop_qc_report.sh << 'EOF'
#!/bin/bash

REPORT="Population_QC_Report.txt"

echo "=========================================" > ${REPORT}
echo "   Population-Level QC Summary" >> ${REPORT}
echo "=========================================" >> ${REPORT}
echo "" >> ${REPORT}

# SNP Call Rate 통계
if [ -f snp_call_rate.txt ]; then
    echo "SNP Call Rate Statistics:" >> ${REPORT}
    awk '{sum+=$2; if($2<min || NR==1){min=$2} if($2>max || NR==1){max=$2}} 
         END{print "  Mean: "sum/NR; print "  Min: "min; print "  Max: "max}' \
         snp_call_rate.txt >> ${REPORT}
    
    n_low_call=$(awk '$2 < 0.90 {count++} END{print count+0}' snp_call_rate.txt)
    echo "  SNPs with Call Rate < 90%: ${n_low_call}" >> ${REPORT}
    echo "" >> ${REPORT}
fi

# Allele Frequency 통계
if [ -f allele_frequency.txt ]; then
    echo "Minor Allele Frequency (MAF) Statistics:" >> ${REPORT}
    n_rare=$(awk '$2 < 0.01 {count++} END{print count+0}' allele_frequency.txt)
    n_common=$(awk '$2 >= 0.05 {count++} END{print count+0}' allele_frequency.txt)
    echo "  Rare SNPs (MAF < 1%): ${n_rare}" >> ${REPORT}
    echo "  Common SNPs (MAF ≥ 5%): ${n_common}" >> ${REPORT}
    echo "" >> ${REPORT}
fi

# HWE 검정 결과
if [ -f hwe_test.txt ]; then
    echo "Hardy-Weinberg Equilibrium Test:" >> ${REPORT}
    n_hwe_fail=$(awk '$2 < 1e-6 {count++} END{print count+0}' hwe_test.txt)
    echo "  SNPs failing HWE (p < 1e-6): ${n_hwe_fail}" >> ${REPORT}
    echo "" >> ${REPORT}
fi

# QC Passed SNPs
if [ -f qc_passed_snps.txt ]; then
    n_passed=$(wc -l < qc_passed_snps.txt)
    echo "Final QC Passed SNPs: ${n_passed}" >> ${REPORT}
    echo "" >> ${REPORT}
fi

cat ${REPORT}
EOF

chmod +x generate_pop_qc_report.sh
./generate_pop_qc_report.sh
```

---

## 🧬 Phase 4: AlphaImpute2 실행

### 4.1 AlphaImpute2 Input 파일 준비

AlphaImpute2는 다음 파일들이 필요합니다:
1. **Pedigree File** (PedigreeFile.txt)
2. **Genotype File** (GenotypeFile.txt)
3. **Specification File** (AlphaImputeSpec.txt)

### 4.2 Pedigree 파일 생성

```bash
cd ../Imputation

# GENO 파일에서 혈통 정보 추출
cat > create_pedigree.sh << 'EOF'
#!/bin/bash

INPUT="../Merged_Data/ALL_INDIVIDUALS_GENO.txt"
OUTPUT="PedigreeFile.txt"

# AlphaImpute2 Pedigree 형식:
# Individual Sire Dam Sex

echo "Creating PedigreeFile for AlphaImpute2..."

tail -n +2 ${INPUT} | awk '{
    individual = $1
    sire = $3
    dam = $4
    sex = $5
    
    # 0은 unknown으로 변환
    if (sire == "0") sire = "0"
    if (dam == "0") dam = "0"
    
    print individual, sire, dam, sex
}' > ${OUTPUT}

echo "PedigreeFile created: ${OUTPUT}"
echo "Total individuals: $(wc -l < ${OUTPUT})"
EOF

chmod +x create_pedigree.sh
./create_pedigree.sh
```

### 4.3 Genotype 파일 생성 (AlphaImpute2 형식)

```bash
cat > create_genotype_file.sh << 'EOF'
#!/bin/bash

INPUT="../Merged_Data/ALL_INDIVIDUALS_GENO.txt"
QC_SNPS="../Population_QC/qc_passed_snps.txt"
OUTPUT="GenotypeFile.txt"

echo "Creating GenotypeFile for AlphaImpute2..."

# AlphaImpute2 Genotype 형식:
# Individual Chip SNP1 SNP2 SNP3 ...
# (0=AA, 1=AB, 2=BB, 9=missing)

# Header
echo -n "Individual Chip" > ${OUTPUT}

# SNP IDs 추가 (QC passed SNPs만)
if [ -f ${QC_SNPS} ]; then
    awk '{printf " "$1}' ${QC_SNPS} >> ${OUTPUT}
else
    echo "Warning: QC passed SNP list not found. Using all SNPs."
fi
echo "" >> ${OUTPUT}

# 각 개체의 genotype 추가
tail -n +2 ${INPUT} | while read line; do
    animal_id=$(echo $line | awk '{print $1}')
    
    # Chip version 판별 (메타데이터 또는 파일명 기반)
    # 여기서는 임시로 V1 또는 V2로 설정
    chip="V1"  # 실제로는 적절히 판별 필요
    
    # GENO vector 추출 (8번째 필드부터)
    geno=$(echo $line | cut -d' ' -f8-)
    
    # QC passed SNP 위치만 추출 (필요시)
    echo "${animal_id} ${chip} ${geno}" >> ${OUTPUT}
done

echo "GenotypeFile created: ${OUTPUT}"
echo "Total individuals: $(($(wc -l < ${OUTPUT}) - 1))"
EOF

chmod +x create_genotype_file.sh
./create_genotype_file.sh
```

### 4.4 AlphaImpute2 Specification 파일

**AlphaImputeSpec.txt**:
```
# -----------------------------------------------
# AlphaImpute2 Specification File
# -----------------------------------------------

# Input Files
PedigreeFile, PedigreeFile.txt
GenotypeFile, GenotypeFile.txt

# Output Options
OutputFolder, ./AlphaImpute2_Output
ReportFile, AlphaImputeReport.txt

# Imputation Settings
# 사용 가능한 칩 타입 정의
ChipDescriptorFile, ChipDescriptor.txt

# 고밀도 참조 패널 (있는 경우)
# ReferencePopulation, HighDensityAnimals.txt

# Phasing 및 Imputation 옵션
InternalIterations, 10
BurnInIterations, 3
EMIterations, 20

# 품질 관리
CoreAndTailLengths, 200,100
CoreLength, 200

# Haplotype Library 크기
MaxHapLibrarySize, 200

# 병렬 처리
NumberOfProcessors, 8

# 출력 형식
OutputAllGenotypes, yes
OutputImputationAccuracy, yes
OutputPhase, yes
```

**ChipDescriptor.txt** (Chip 타입 정의):
```
# Chip Name, Number of SNPs
V1, 62163
V2, 68516
```

### 4.5 AlphaImpute2 실행

```bash
# AlphaImpute2 실행
cat > run_alphaimpute.sh << 'EOF'
#!/bin/bash

module load AlphaImpute2  # 시스템에 따라 다름

echo "========================================="
echo "Starting AlphaImpute2"
echo "========================================="
echo ""

# 출력 디렉토리 생성
mkdir -p AlphaImpute2_Output

# 실행
AlphaImpute2 AlphaImputeSpec.txt > alphaimpute2.log 2>&1

# 실행 상태 확인
if [ $? -eq 0 ]; then
    echo "AlphaImpute2 completed successfully!"
else
    echo "AlphaImpute2 failed. Check alphaimpute2.log for details."
    exit 1
fi

echo ""
echo "========================================="
echo "Output Files:"
echo "========================================="
ls -lh AlphaImpute2_Output/
EOF

chmod +x run_alphaimpute.sh
./run_alphaimpute.sh
```

### 4.6 Imputation Quality 평가

```bash
cat > evaluate_imputation.sh << 'EOF'
#!/bin/bash

OUTPUT_DIR="AlphaImpute2_Output"
REPORT="Imputation_Quality_Report.txt"

echo "=========================================" > ${REPORT}
echo "   AlphaImpute2 Quality Assessment" >> ${REPORT}
echo "=========================================" >> ${REPORT}
echo "" >> ${REPORT}

# AlphaImpute2 출력 파일 분석
if [ -f ${OUTPUT_DIR}/AlphaImputeReport.txt ]; then
    echo "=== Imputation Summary ===" >> ${REPORT}
    grep -A 20 "Imputation Summary" ${OUTPUT_DIR}/AlphaImputeReport.txt >> ${REPORT}
    echo "" >> ${REPORT}
fi

# Imputation Accuracy (있는 경우)
if [ -f ${OUTPUT_DIR}/ImputationAccuracy.txt ]; then
    echo "=== Imputation Accuracy ===" >> ${REPORT}
    awk '{sum+=$2; n++} END{print "  Average Accuracy: "sum/n}' \
        ${OUTPUT_DIR}/ImputationAccuracy.txt >> ${REPORT}
    echo "" >> ${REPORT}
fi

# Chromosome별 통계 (있는 경우)
for chr in {1..18}; do
    if [ -f ${OUTPUT_DIR}/Chr${chr}_ImputedGenotypes.txt ]; then
        n_snps=$(head -1 ${OUTPUT_DIR}/Chr${chr}_ImputedGenotypes.txt | wc -w)
        n_animals=$(tail -n +2 ${OUTPUT_DIR}/Chr${chr}_ImputedGenotypes.txt | wc -l)
        echo "Chr ${chr}: ${n_snps} SNPs, ${n_animals} animals" >> ${REPORT}
    fi
done
echo "" >> ${REPORT}

cat ${REPORT}
EOF

chmod +x evaluate_imputation.sh
./evaluate_imputation.sh
```

---

## ✅ Phase 5: 최종 검증 및 결과 생성

### 5.1 Imputed Genotype 형식 변환

```bash
cd ../Final_Results

# AlphaImpute2 출력을 GENO 형식으로 변환
cat > convert_imputed_to_geno.sh << 'EOF'
#!/bin/bash

IMPUTED_DIR="../Imputation/AlphaImpute2_Output"
OUTPUT="FINAL_IMPUTED_GENO.txt"

echo "Converting AlphaImpute2 output to GENO format..."

# AlphaImpute2의 ImputedGenotypes.txt 파일 사용
if [ -f ${IMPUTED_DIR}/ImputedGenotypes.txt ]; then
    # Header 생성
    echo "Animal_ID BREED SIRE DAM SEX BDate LOC GENO" > ${OUTPUT}
    
    # 혈통 정보와 병합
    # (구현 필요: PedigreeFile과 ImputedGenotypes 병합)
    
    echo "Conversion completed: ${OUTPUT}"
else
    echo "Error: ImputedGenotypes.txt not found in ${IMPUTED_DIR}"
    exit 1
fi
EOF

chmod +x convert_imputed_to_geno.sh
./convert_imputed_to_geno.sh
```

### 5.2 최종 QC 통계

```bash
cat > final_statistics.sh << 'EOF'
#!/bin/bash

FINAL_REPORT="FINAL_PIPELINE_REPORT.txt"

echo "================================================" > ${FINAL_REPORT}
echo "   Complete Pipeline Summary Report" >> ${FINAL_REPORT}
echo "================================================" >> ${FINAL_REPORT}
echo "" >> ${FINAL_REPORT}
echo "Generated: $(date)" >> ${FINAL_REPORT}
echo "" >> ${FINAL_REPORT}

# Phase 1 통계
echo "=== Phase 1: Individual QC ===" >> ${FINAL_REPORT}
cat ../Pipeline/QC_Summary.txt >> ${FINAL_REPORT}
echo "" >> ${FINAL_REPORT}

# Phase 2 통계
echo "=== Phase 2: Data Merging ===" >> ${FINAL_REPORT}
if [ -f ../Merged_Data/ALL_INDIVIDUALS_GENO.txt ]; then
    n_total=$(tail -n +2 ../Merged_Data/ALL_INDIVIDUALS_GENO.txt | wc -l)
    echo "Total individuals in merged dataset: ${n_total}" >> ${FINAL_REPORT}
fi
echo "" >> ${FINAL_REPORT}

# Phase 3 통계
echo "=== Phase 3: Population QC ===" >> ${FINAL_REPORT}
if [ -f ../Population_QC/Population_QC_Report.txt ]; then
    cat ../Population_QC/Population_QC_Report.txt >> ${FINAL_REPORT}
fi
echo "" >> ${FINAL_REPORT}

# Phase 4 통계
echo "=== Phase 4: Imputation ===" >> ${FINAL_REPORT}
if [ -f ../Imputation/Imputation_Quality_Report.txt ]; then
    cat ../Imputation/Imputation_Quality_Report.txt >> ${FINAL_REPORT}
fi
echo "" >> ${FINAL_REPORT}

# 최종 데이터셋 정보
echo "=== Final Dataset ===" >> ${FINAL_REPORT}
if [ -f FINAL_IMPUTED_GENO.txt ]; then
    n_final=$(tail -n +2 FINAL_IMPUTED_GENO.txt | wc -l)
    echo "Final imputed individuals: ${n_final}" >> ${FINAL_REPORT}
    # SNP 수 계산 (첫 번째 개체의 GENO 길이)
    first_geno=$(tail -n +2 FINAL_IMPUTED_GENO.txt | head -1 | cut -d' ' -f8-)
    n_snps=${#first_geno}
    echo "Total SNPs in final dataset: ${n_snps}" >> ${FINAL_REPORT}
fi
echo "" >> ${FINAL_REPORT}

echo "================================================" >> ${FINAL_REPORT}

cat ${FINAL_REPORT}
EOF

chmod +x final_statistics.sh
./final_statistics.sh
```

### 5.3 데이터 백업

```bash
# 최종 결과 압축 및 백업
tar -czf Pipeline_Results_$(date +%Y%m%d).tar.gz \
    ../Pipeline/QC_Results/ \
    ../Merged_Data/ \
    ../Population_QC/ \
    ../Imputation/AlphaImpute2_Output/ \
    ../Final_Results/

echo "Backup created: Pipeline_Results_$(date +%Y%m%d).tar.gz"
```

---

## 📂 최종 디렉토리 구조

```
/home/dhlee/DKBLUPF90/ReadFR/Pipeline/
│
├── Raw_Data/
│   ├── ChipV1/           # V1 FinalReport 파일들
│   └── ChipV2/           # V2 FinalReport 파일들
│
├── QC_Results/
│   ├── ChipV1/
│   │   ├── *_GENO.txt    # 개체별 QC passed genotypes
│   │   └── logs/         # QC 로그 파일들
│   └── ChipV2/
│       ├── *_GENO.txt
│       └── logs/
│
├── Merged_Data/
│   ├── ALL_INDIVIDUALS_GENO.txt  # 통합 GENO 파일
│   ├── snp_v1_sorted.txt
│   └── snp_v2_sorted.txt
│
├── Population_QC/
│   ├── PopulationQC              # 실행 프로그램
│   ├── snp_call_rate.txt
│   ├── allele_frequency.txt
│   ├── hwe_test.txt
│   ├── qc_passed_snps.txt
│   └── Population_QC_Report.txt
│
├── Imputation/
│   ├── PedigreeFile.txt
│   ├── GenotypeFile.txt
│   ├── AlphaImputeSpec.txt
│   ├── ChipDescriptor.txt
│   ├── alphaimpute2.log
│   └── AlphaImpute2_Output/
│       ├── ImputedGenotypes.txt
│       ├── AlphaImputeReport.txt
│       └── Chr*_ImputedGenotypes.txt
│
└── Final_Results/
    ├── FINAL_IMPUTED_GENO.txt
    ├── FINAL_PIPELINE_REPORT.txt
    └── Pipeline_Results_YYYYMMDD.tar.gz
```

---

## ⚙️ 전체 파이프라인 실행 스크립트

**master_pipeline.sh** (전체 자동 실행):
```bash
#!/bin/bash
#
# 마스터 파이프라인 스크립트
# 213개 FinalReport 파일 → Imputed Genotypes
#

set -e  # 오류 발생 시 중단

PIPELINE_DIR="/home/dhlee/DKBLUPF90/ReadFR/Pipeline"
cd ${PIPELINE_DIR}

echo "========================================="
echo "   Starting Complete Pipeline"
echo "========================================="
date
echo ""

# Phase 1: Individual QC
echo "=== Phase 1: Individual QC Processing ==="
./batch_qc_v1.sh &
./batch_qc_v2.sh &
wait
./summarize_qc.sh
echo ""

# Phase 2: Merging
echo "=== Phase 2: Merging GENO Files ==="
cd Merged_Data
./merge_geno_files.sh
./validate_geno.sh
cd ..
echo ""

# Phase 3: Population QC
echo "=== Phase 3: Population QC Analysis ==="
cd Population_QC
./PopulationQC ../Merged_Data/ALL_INDIVIDUALS_GENO.txt
./generate_pop_qc_report.sh
cd ..
echo ""

# Phase 4: AlphaImpute2
echo "=== Phase 4: Imputation with AlphaImpute2 ==="
cd Imputation
./create_pedigree.sh
./create_genotype_file.sh
./run_alphaimpute.sh
./evaluate_imputation.sh
cd ..
echo ""

# Phase 5: Final Results
echo "=== Phase 5: Generating Final Results ==="
cd Final_Results
./convert_imputed_to_geno.sh
./final_statistics.sh
echo ""

echo "========================================="
echo "   Pipeline Completed Successfully!"
echo "========================================="
date
```

---

## 🔍 모니터링 및 트러블슈팅

### 일반적인 문제 및 해결책

#### 1. **메모리 부족**
```bash
# 큰 파일 처리 시 청크 단위로 분할
split -l 1000000 large_file.txt chunk_
# 각 청크 개별 처리 후 병합
```

#### 2. **디스크 공간 부족**
```bash
# 중간 파일 정리
rm -rf temp_* *.tmp
# 로그 파일 압축
gzip *.log
```

#### 3. **처리 시간 지연**
```bash
# GNU Parallel 사용
ls *.txt | parallel -j 8 './process.sh {}'
```

#### 4. **AlphaImpute2 오류**
```bash
# 로그 파일 확인
tail -100 alphaimpute2.log
# 입력 파일 형식 재검증
head -20 PedigreeFile.txt
head -20 GenotypeFile.txt
```

### 로그 모니터링

```bash
# 실시간 진행 상황 모니터링
watch -n 10 'tail -20 *.log'

# 오류 메시지 추출
grep -i "error\|fail\|warning" *.log > errors_summary.txt
```

---

## 📊 예상 처리 시간 및 리소스

| Phase | 예상 시간 | CPU | Memory | Disk |
|-------|----------|-----|--------|------|
| Phase 1 (QC) | 2-4 hours | 8 cores | 4GB | 50GB |
| Phase 2 (Merge) | 10-20 min | 1 core | 8GB | 10GB |
| Phase 3 (Pop QC) | 30-60 min | 4 cores | 16GB | 5GB |
| Phase 4 (Impute) | 6-12 hours | 8 cores | 32GB | 100GB |
| Phase 5 (Final) | 10-20 min | 1 core | 4GB | 20GB |
| **Total** | **~10-18 hours** | **8 cores** | **32GB** | **185GB** |

---

## 📞 지원 및 참고 자료

### AlphaImpute2 관련
- **매뉴얼**: [AlphaGenes Documentation](http://www.alphagenes.roslin.ed.ac.uk/)
- **포럼**: AlphaGenes User Group

### 추가 도구
- **PLINK** (참고용): [PLINK 1.9](https://www.cog-genomics.org/plink/)
- **BCFtools** (파일 변환): [BCFtools](http://samtools.github.io/bcftools/)

### 기술 지원
- 이메일: [support@example.com]
- 위키: [Internal Wiki Link]

---

## 📝 변경 이력

| 날짜 | 버전 | 변경 내용 | 작성자 |
|------|------|----------|--------|
| 2026-02-12 | 1.0 | 초기 버전 작성 | - |

---

**문서 끝**
