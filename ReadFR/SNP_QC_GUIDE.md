# GBLUP을 위한 SNP 품질 관리(QC) 가이드

## 📋 목차
1. [개요](#개요)
2. [FinalReport 파일 구조](#finalreport-파일-구조)
3. [개체 수준 품질 관리](#개체-수준-품질-관리)
4. [SNP 수준 품질 관리](#snp-수준-품질-관리)
5. [QC 기준 상세 설명](#qc-기준-상세-설명)
6. [권장 QC 워크플로우](#권장-qc-워크플로우)
7. [코드 구현 세부사항](#코드-구현-세부사항)

---

## 개요

유전체 SNP 데이터를 이용한 GBLUP(Genomic Best Linear Unbiased Prediction) 분석의 정확도는 **SNP 품질 관리(Quality Control, QC)**에 크게 의존합니다. FinalReport 파일에서 유효한 SNP을 선별하기 위해서는 다양한 품질 지표들을 종합적으로 고려해야 합니다.

### 주요 목적
- 유전자형 판정 오류 최소화
- 신뢰할 수 있는 SNP만 선별
- GBLUP 분석의 정확도 향상
- 거짓 양성(False Positive) 결과 방지

---

## FinalReport 파일 구조

### 주요 필드 및 설명

| 컬럼 | 필드명 | 설명 | 데이터 타입 | 사용 목적 |
|------|--------|------|-------------|-----------|
| 1 | Sample ID | 샘플 식별자 | 문자열 | 개체 식별 |
| 2 | Sample Name | 샘플 이름 | 문자열 | ARN/개체 ID |
| 5 | SNP Name | SNP 식별자 | 문자열 | SNP 매칭 |
| 9 | Chr | 염색체 번호 | 정수 | 위치 정보 |
| 10 | Position | 염색체 상 위치 | 정수 | 물리적 위치 |
| 11 | Allele1-AB | 첫번째 대립유전자(AB코드) | A/B | 유전자형 |
| 12 | Allele2-AB | 두번째 대립유전자(AB코드) | A/B | 유전자형 |
| 21 | X | X 형광 강도 | 실수 | 원시 신호 |
| 22 | Y | Y 형광 강도 | 실수 | 원시 신호 |
| 25 | **R** | **Intensity 합계 (X+Y)** | 실수 | **신호 강도** |
| 26 | Theta | 대립유전자 비율 | 실수 | 클러스터 위치 |
| 27 | **GC Score** | **GenCall Score** | 실수 | **가장 중요한 QC 지표** |
| 28 | Log R Ratio | 복제수변이 지표 | 실수 | CNV 탐지 |
| 29 | **GT Score** | **Genotype Score** | 실수 | **유전자형 신뢰도** |
| 30 | **Cluster Sep** | **클러스터 분리도** | 실수 | **판별력** |

### 파일 헤더 구조

```
[Header]
GSGT Version    2.0.3
Processing Date 4/19/2019 3:52 PM
Content         porcinesnp60v2_15031945_c.bpm
Num SNPs        61565
Total SNPs      61565
Num Samples     595
Total Samples   595
[Data]
Sample ID	Sample Name	Sample Index	...
```

---

## 개체 수준 품질 관리

### 1. Call Rate (호출률)

**정의:** 개체당 성공적으로 판정된 SNP의 비율

**계산식:**
```
Call Rate = (총 SNP 수 - 결측 SNP 수) / 총 SNP 수
```

**선별 기준:**
| 수준 | Call Rate | 판정 | 조치 |
|------|-----------|------|------|
| 우수 | ≥ 0.98 | 매우 좋음 | ✅ 사용 |
| 양호 | 0.95 - 0.97 | 좋음 | ✅ 사용 |
| 주의 | 0.90 - 0.94 | 보통 | ⚠️ 재검토 |
| 불량 | < 0.90 | 나쁨 | ❌ **제외** |

**코드 구현:**
```fortran
call_anim = 1.0_r4 - real(count_miss)/real(nSNP)
if(call_anim .lt. 0.95_r4) then
   animals_low_callrate = animals_low_callrate + 1
   cycle  ! 해당 개체 제외
end if
```

**제외 이유:**
- DNA 품질 불량
- 샘플 농도 부족
- 실험 과정 오류
- 교차 오염(Cross-contamination)

---

### 2. 성염색체 이형접합도 검사

**목적:** 성별 오류 및 샘플 오염 탐지

#### 2.1 수컷 (SEX = Male)

**X염색체 (Chr 20) 기대 패턴:**
- 대부분 동형접합(AA 또는 BB)
- 이형접합(AB) 비율 < 5%

**검증 기준:**
```fortran
! X염색체 SNP에서 유전자형 분포 확인
Heterozygosity_X = count_AB / (count_AA + count_AB + count_BB)
if(Heterozygosity_X > 0.05) then
   ! 의심스러운 개체 - 성별 확인 필요
end if
```

#### 2.2 암컷 (SEX = Female)

**X염색체 (Chr 20) 기대 패턴:**
- AA, AB, BB 모두 가능
- 정상적인 멘델 분리 비율

**Y염색체 (Chr 21) 기대 패턴:**
- 대부분 결측 (missing)
- 호출된 SNP가 있다면 오류 의심

**코드 구현:**
```fortran
if(MapInfo(j)%Chr == 20) then
   call check_Sex(genotype, countX)
elseif(MapInfo(j)%Chr == 21) then
   call check_Sex(genotype, countY)
end if
```

---

## SNP 수준 품질 관리

### 1. GC Score (GenCall Score) ⭐ **가장 중요**

**정의:** Illumina GenCall 알고리즘이 계산한 유전자형 판정의 신뢰도

**값의 범위:** 0.0 ~ 1.0

**선별 기준:**
| 등급 | GC Score | 신뢰도 | 판정 | 사용 여부 |
|------|----------|--------|------|-----------|
| 최우수 | ≥ 0.80 | 매우 높음 | Excellent | ✅ **적극 사용** |
| 우수 | 0.70 - 0.79 | 높음 | Good | ✅ **사용** |
| 양호 | 0.50 - 0.69 | 보통 | Fair | ⚠️ 신중히 사용 |
| 주의 | 0.30 - 0.49 | 낮음 | Poor | ⚠️ 재검토 필요 |
| 불량 | < 0.30 | 매우 낮음 | Fail | ❌ **제외** |

**권장 기준:**
- **보수적 분석:** GC Score ≥ 0.70
- **일반 분석:** GC Score ≥ 0.60
- **탐색적 분석:** GC Score ≥ 0.50

**코드 구현:**
```fortran
GC_Score = XR(27)  ! Column 27
if(GC_Score < 0.70) then
   pass_QC = .false.
   qc_fail_gc = qc_fail_gc + 1
end if
```

**GC Score가 낮은 이유:**
- 대립유전자 클러스터가 명확하게 분리되지 않음
- 신호 강도가 약함
- 샘플 간 변이가 큼
- SNP 설계 문제

---

### 2. R (Intensity) - 신호 강도

**정의:** X와 Y 형광 강도의 합 (R = X + Y)

**값의 의미:**
- **높은 R:** 강한 신호, 좋은 DNA 품질
- **낮은 R:** 약한 신호, DNA 품질 문제
- **매우 높은 R:** 비정상적 신호, 오류 가능성

**선별 기준:**
| 범위 | 평가 | 조치 |
|------|------|------|
| R > 2.0 | 비정상적으로 높음 | ❌ 제외 |
| 0.4 ≤ R ≤ 2.0 | 정상 범위 | ✅ 사용 |
| 0.2 ≤ R < 0.4 | 약한 신호 | ⚠️ 주의 |
| R < 0.2 | 매우 약함 | ❌ 제외 |

**코드 구현:**
```fortran
R_value = XR(25)  ! Column 25
if(R_value < 0.4 .or. R_value > 2.0) then
   pass_QC = .false.
   qc_fail_r = qc_fail_r + 1
end if
```

**참고사항:**
- R 값의 정상 범위는 칩 종류와 실험 프로토콜에 따라 다를 수 있음
- 배치(batch)별 R 값 분포 확인 필요

---

### 3. GT Score (Genotype Score)

**정의:** 개별 유전자형 호출의 품질 점수

**선별 기준:**
- **권장:** GT Score ≥ 0.60
- **최소:** GT Score ≥ 0.50

**코드 구현:**
```fortran
GT_Score = XR(29)  ! Column 29
if(GT_Score < 0.60) then
   pass_QC = .false.
   qc_fail_gt = qc_fail_gt + 1
end if
```

---

### 4. Cluster Separation (클러스터 분리도)

**정의:** AA, AB, BB 세 클러스터 간의 분리 정도

**값의 의미:**
- **높은 Cluster Sep:** 명확한 분리, 정확한 판정
- **낮은 Cluster Sep:** 불명확한 분리, 오류 가능성

**선별 기준:**
| Cluster Sep | 평가 | 조치 |
|-------------|------|------|
| ≥ 0.50 | 우수 | ✅ 사용 |
| 0.30 - 0.49 | 양호 | ✅ 사용 |
| 0.20 - 0.29 | 주의 | ⚠️ 재검토 |
| < 0.20 | 불량 | ❌ 제외 |

**코드 구현:**
```fortran
Cluster_Sep = XR(30)  ! Column 30
if(Cluster_Sep < 0.30) then
   pass_QC = .false.
   qc_fail_cluster = qc_fail_cluster + 1
end if
```

---

### 5. 대립유전자 검증

**필수 조건:**
- Allele1과 Allele2 모두 유효한 값 (A 또는 B)
- 둘 다 공백이거나 결측이면 제외

**코드 구현:**
```fortran
if(Allele1 == ' ' .or. Allele2 == ' ') then
   pass_QC = .false.
   qc_fail_allele = qc_fail_allele + 1
end if
```

---

### 6. 염색체 필터

**선별 기준 (돼지 기준):**
- **상염색체:** Chr 1-18
- **성염색체:** Chr 19 (X), Chr 20 (Y) - 선택적 포함
- **미배치:** Chr 0, 99 → 제외

**코드 구현:**
```fortran
if(MapInfo(j)%Chr < 1 .or. MapInfo(j)%Chr > 21) then
   pass_QC = .false.
   qc_fail_chr = qc_fail_chr + 1
end if
```

---

## QC 기준 상세 설명

### 종합 QC 알고리즘

```fortran
! Initialize
pass_QC = .true.

! Extract quality metrics
GC_Score = XR(27)      ! GC Score
R_value = XR(25)       ! R (Intensity)
GT_Score = XR(29)      ! GT Score
Cluster_Sep = XR(30)   ! Cluster Separation

! Apply filters sequentially
! 1. GC Score check (Most Important)
if(GC_Score < 0.70) pass_QC = .false.

! 2. Intensity check
if(R_value < 0.4 .or. R_value > 2.0) pass_QC = .false.

! 3. GT Score check
if(GT_Score < 0.60) pass_QC = .false.

! 4. Cluster Separation check
if(Cluster_Sep < 0.30) pass_QC = .false.

! 5. Allele validation
if(Allele1 == ' ' .or. Allele2 == ' ') pass_QC = .false.

! 6. Chromosome filter
if(MapInfo(j)%Chr < 1 .or. MapInfo(j)%Chr > 21) pass_QC = .false.

! Final assignment
if(pass_QC) then
   GENO(MapInfo(j)%Array_All) = genotype
else
   GENO(MapInfo(j)%Array_All) = 9_ki1  ! Missing
   count_miss = count_miss + 1
end if
```

---

## 권장 QC 워크플로우

### Phase 1: 개체 수준 사전 QC

```
1. FinalReport 파일 로드
2. 각 개체별로:
   a. Call Rate 계산
   b. Call Rate < 95% → 개체 제외
   c. 성염색체 검증
   d. 성별 불일치 → 재확인 또는 제외
```

### Phase 2: SNP 수준 QC (개체별)

```
3. 각 SNP-개체 조합에 대해:
   a. GC Score 확인 (≥ 0.70)
   b. R 값 확인 (0.4 - 2.0)
   c. GT Score 확인 (≥ 0.60)
   d. Cluster Sep 확인 (≥ 0.30)
   e. 대립유전자 유효성 확인
   f. 염색체 번호 확인
   g. 모든 조건 통과 → 유전자형 저장
   h. 하나라도 실패 → 결측 처리
```

### Phase 3: 집단 수준 SNP QC (권장 - 별도 프로그램)

```
4. 모든 개체의 유전자형 통합 후:
   a. SNP별 Call Rate 계산
      - SNP Call Rate < 95% → SNP 제외
   
   b. Minor Allele Frequency (MAF) 계산
      - MAF < 0.05 (5%) → SNP 제외
   
   c. Hardy-Weinberg Equilibrium (HWE) 검정
      - P-value < 10⁻⁶ → SNP 제외
   
   d. 중복 SNP 제거
      - 동일 위치 SNP 확인
```

### Phase 4: 최종 확인

```
5. QC 통계 요약:
   a. 최종 개체 수
   b. 최종 SNP 수
   c. 단계별 제거 통계
   d. QC 보고서 생성
```

---

## 코드 구현 세부사항

### 주요 변수 정의

```fortran
! QC variables
real :: GC_Score, R_value, GT_Score, Cluster_Sep
logical :: pass_QC
integer :: total_snps, total_animals
integer :: qc_fail_gc, qc_fail_r, qc_fail_gt, qc_fail_cluster
integer :: qc_fail_allele, qc_fail_chr
integer :: animals_low_callrate
```

### 통계 초기화

```fortran
! Initialize QC statistics
total_snps = 0
total_animals = 0
qc_fail_gc = 0
qc_fail_r = 0
qc_fail_gt = 0
qc_fail_cluster = 0
qc_fail_allele = 0
qc_fail_chr = 0
animals_low_callrate = 0
```

### QC 결과 출력

```fortran
print*,"======================================================================"
print*,"SNP QUALITY CONTROL SUMMARY"
print*,"======================================================================"
print*,"Total Animals Processed:      ", total_animals
print*,"Animals Excluded (Call Rate): ", animals_low_callrate
print*,"Animals Retained:             ", total_animals - animals_low_callrate
print*,""
print*,"Total SNP Calls Processed:    ", total_snps
print*,"QC Failures by Criterion:"
print*,"  - GC Score < 0.70:          ", qc_fail_gc
print*,"  - R out of range:           ", qc_fail_r
print*,"  - GT Score < 0.60:          ", qc_fail_gt
print*,"  - Cluster Sep < 0.30:       ", qc_fail_cluster
print*,"  - Missing Alleles:          ", qc_fail_allele
print*,"  - Invalid Chromosome:       ", qc_fail_chr
print*,"======================================================================"
```

---

## 기준값 조정 가이드

### 연구 목적에 따른 기준 조정

#### 보수적 분석 (높은 정확도 요구)
```fortran
GC_Score >= 0.80
R_value: 0.5 - 1.8
GT_Score >= 0.70
Cluster_Sep >= 0.40
Call_Rate >= 0.98
```

#### 표준 분석 (권장)
```fortran
GC_Score >= 0.70
R_value: 0.4 - 2.0
GT_Score >= 0.60
Cluster_Sep >= 0.30
Call_Rate >= 0.95
```

#### 탐색적 분석 (샘플 수 부족 시)
```fortran
GC_Score >= 0.50
R_value: 0.3 - 2.5
GT_Score >= 0.50
Cluster_Sep >= 0.20
Call_Rate >= 0.90
```

---

## 주의사항 및 권장사항

### ⚠️ 주의사항

1. **과도한 QC는 정보 손실**
   - 너무 엄격한 기준은 유용한 SNP를 과도하게 제거
   - 샘플 크기가 작은 경우 특히 주의

2. **칩 종류별 특성 고려**
   - PorcineSNP60, GGP-Porcine HD 등 칩마다 특성 다름
   - 제조사 권장 기준 참고

3. **배치 효과(Batch Effect)**
   - 실험 시기/담당자별로 품질 차이 가능
   - 배치별 QC 통계 확인

4. **성염색체 특수성**
   - 수컷의 X염색체 처리 주의
   - 성별 불일치 개체는 별도 검토

### ✅ 권장사항

1. **단계적 QC 적용**
   - 한 번에 모든 기준 적용보다 단계별 확인
   - 각 단계별 제거 통계 기록

2. **QC 전후 비교**
   - QC 전후 SNP 수, 개체 수 비교
   - MAF 분포, Call rate 분포 시각화

3. **재현성 확보**
   - QC 기준과 결과를 문서화
   - Parameter 파일에 기준 명시

4. **집단 수준 QC 필수**
   - 본 프로그램은 개체별 QC만 수행
   - SNP 수준 집단 통계는 별도 분석 필요

---

## 참고문헌

1. **Illumina GenCall Data Analysis Software**
   - GenCall Score 계산 방법론
   - https://www.illumina.com

2. **Anderson et al. (2010)**
   - "Data quality control in genetic case-control association studies"
   - Nature Protocols 5: 1564-1573

3. **Laurie et al. (2010)**
   - "Quality control and quality assurance in genotypic data for genome-wide association studies"
   - Genetic Epidemiology 34: 591-602

4. **VanRaden et al. (2009)**
   - "Invited review: Reliability of genomic predictions for North American Holstein bulls"
   - Journal of Dairy Science 92: 16-24

---

## 버전 이력

- **v1.0** (2026-02-12)
  - 초기 문서 작성
  - Enhanced QC 기준 적용
  - GC Score 기준 0.2 → 0.70 상향
  - Call Rate 기준 0.90 → 0.95 상향
  - R, GT Score, Cluster Sep 필터 추가
  - QC 통계 출력 기능 추가

---

## 문의 및 지원

- 코드 위치: `/home/dhlee/DKBLUPF90/ReadFR/ReadFR.f90`
- 문서 위치: `/home/dhlee/DKBLUPF90/ReadFR/SNP_QC_GUIDE.md`

---

**Last Updated: 2026-02-12**
