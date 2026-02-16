program ReadFR
  use M_Kinds
  use M_Stamp
  use M_Variables, only: FileInfo, SNPInfo, PEDInfo, QC_Metrics, QC_Counters, &
                         PEDFile, SNPFile, MAPFile, OutputPrefix, &
                         MAX_STR, MAX_VAR, LEN_STR
  use M_StrEdit
  use M_ReadFile
  use M_readpar, only: read_parameters, M_readpar_get_thresholds
  use M_PEDHashTable
  implicit none

  character(len=MAX_STR) :: Par_File
  character(LEN=MAX_STR) :: XC(MAX_VAR)
  real(kind=r4) :: XR(MAX_VAR)
  integer(kind=ki4) :: XI(MAX_VAR)
  integer(kind=ki1),allocatable :: GENO(:)
  type(PEDHashTable) :: PED
  type(PEDInfo) :: PED_REC
  type(SNPInfo),allocatable :: MapInfo(:)
  logical :: file_exists
  
   integer :: unitGENO, unitF, n, i, j, animal_field_idx, snp_name_idx
   integer :: NREC, nSNP, NARN, tSNP, count_miss
   integer :: countX(3), countY(3), countY_hetero_errors
   integer :: total_animals, animals_retained, animals_low_callrate, snp_count
   integer :: valid_snp_total, invalid_snp_total, animal_seq_num
   ! Pre-calculated field indices for performance (avoid repeated find_field_index calls)
   integer :: idx_allele1, idx_allele2, idx_gc_score, idx_r_intensity
   integer :: idx_gt_score, idx_cluster_sep
   character(len=1) :: Allele1, Allele2
   character(len=MAX_STR) :: GenoFileName
   character(len=LEN_STR) :: Previous_Animal, Sample_Name
   character(len=LEN_STR) :: Animal_Field_Name, Current_SNP_Name
   logical :: snp_order_verified
  integer(kind=ki1) :: genotype
  logical :: found_ped = .false.
  real :: call_rate_animal
  real :: thresh_min_gc, thresh_min_r, thresh_max_r
  real :: thresh_min_gt, thresh_min_cluster, thresh_min_callrate
  


   call version('1.0 - GenomeQC SNP Quality Control Pipeline')
   print '(a)'
   call timestamp()
   print '(a)'
   call timestamp()
   print '(a)'
   
   call getarg(1,Par_File)
   if((len_trim(Par_File)).lt.1) then
      print *, "Usage: ReadFR <parameter_file>"
      print *, ""
      print *, "Example: ReadFR /home/dhlee/GPBLUP/ReadFR/check/parameter.gpblup"
      stop 'Parameter file required'
   end if
   
   ! Check if parameter file exists
   inquire(file=trim(Par_File), exist=file_exists)
   if (.not. file_exists) then
      print *, "ERROR: Parameter file not found: ", trim(Par_File)
      print *, "Please check the file path and try again."
      stop
   end if
   
   print *, "Reading parameter file: ", trim(Par_File)
   call read_parameters(Par_File)
   print*,"PED File Name=", trim(PEDFile%FileName)
   
   call M_readpar_get_thresholds(thresh_min_gc, thresh_min_r, thresh_max_r, &
                                 thresh_min_gt, thresh_min_cluster, thresh_min_callrate)
   
   ! Determine animal field name from parameter (ANIMAL_ARN or ANIMAL_ID)
   ! Must do this BEFORE loading PED file so we know which key to use for hashing
   ! Parameter 파일의 순서대로 index 할당 (column 위치 기반)
   animal_field_idx = 1  ! SNPFile에서 첫 번째 필드가 ANIMAL_ID (column 1)
   Animal_Field_Name = trim(SNPFile%FieldName(animal_field_idx))
   if (trim(Animal_Field_Name) /= 'ANIMAL_ID' .and. trim(Animal_Field_Name) /= 'ANIMAL_ARN') then
      stop 'ERROR: First SNP file field must be ANIMAL_ID or ANIMAL_ARN'
   end if
   print *, "Using field: ", trim(Animal_Field_Name)
   
   ! Now load PED file with dynamic hash key based on Animal_Field_Name
   call load_ped_file(PED, NARN, unitF, Animal_Field_Name)
   call load_map_file(MapInfo, tSNP, unitF)
   call get_snp_dimensions(SNPFile, unitF, nSNP, NREC)
   
   call generate_output_filename(GenoFileName)
   unitGENO = 999
   open(unit=unitGENO, file=trim(GenoFileName), status='replace', action='write')
   write(unitGENO,'(A)') 'Animal_ID BREED SIRE DAM SEX BDate LOC GENO'
   
   !====================================================================
   ! Sequential Reading: Read file once, group by Animal
   !====================================================================
   unitF = fopen(trim(SNPFile%FileName))
   do i=1, SNPFile%Header
      call readline(unitF, n, XC, XR, dlm_str=trim(SNPFile%Delim_char))
   end do
   
   total_animals = 0
   animals_retained = 0
   animals_low_callrate = 0
   valid_snp_total = 0
   invalid_snp_total = 0
   animal_seq_num = 0
   snp_order_verified = .false.
   GENO = 9_ki1
   countY_hetero_errors = 0
   snp_count = 0
   count_miss = 0
   countX = 0
   countY = 0
   Previous_Animal = ''
   
   ! Column 위치 기반 field indices - parameter 파일의 순서대로 설정
   ! SNPFile%FieldLoc(i)에 실제 column 위치가 저장됨
   ! Parameter 파일 순서: 1)ANIMAL_ID 2)SNP_NAME 3)CHR 4)POS 5)ALLELE1_AB 6)ALLELE2_AB 7)R_INTENSITY 8)GC_SCORE 9)GT_SCORE 10)CLUSTER_SEP 11)CALL_RATE
   snp_name_idx = 2        ! SNP_NAME은 parameter의 2번째 항목 (column 5)
   idx_allele1 = 5         ! ALLELE1_AB는 parameter의 5번째 항목 (column 11)
   idx_allele2 = 6         ! ALLELE2_AB는 parameter의 6번째 항목 (column 12)
   idx_r_intensity = 7     ! R_INTENSITY는 parameter의 7번째 항목 (column 25)
   idx_gc_score = 8        ! GC_SCORE는 parameter의 8번째 항목 (column 27)
   idx_gt_score = 9        ! GT_SCORE는 parameter의 9번째 항목 (column 30)
   idx_cluster_sep = 10    ! CLUSTER_SEP는 parameter의 10번째 항목 (column 31)
   
   print '(A)', "Field indices set based on parameter file order - optimization enabled"
   
   do  ! Sequential read until EOF
      call readline(unitF, n, XC, XR, dlm_str=trim(SNPFile%Delim_char))
      if (n < 0) exit  ! EOF
      
      ! Extract Sample Name from SNP file based on parameter keyword
      Sample_Name = trim(XC(SNPFile%FieldLoc(animal_field_idx)))
      
      ! When animal changes, output previous and reset
      if (Sample_Name /= Previous_Animal .and. len_trim(Previous_Animal) > 0) then
         animal_seq_num = animal_seq_num + 1
         call calculate_call_rate(snp_count, count_miss, call_rate_animal)
         if (call_rate_animal >= thresh_min_callrate) then
            animals_retained = animals_retained + 1
            valid_snp_total = valid_snp_total + (snp_count - count_miss)
            ! Print animal statistics before writing to file
            print '(A,I4,A,A,A,A,A,I6,A,I6,A,I6,A,F7.4,A)', &
               'Animal[', animal_seq_num, '] ',trim(PED_REC%ID), ' (',trim(PED_REC%BREED), &
               ') - Total SNPs: ', snp_count, ' Valid: ', (snp_count - count_miss), &
               ' Invalid: ', count_miss, ' CallRate: ', call_rate_animal, ' RETAINED'
            call flush(6)  ! Force output to screen immediately
            write(unitGENO,'(A,1X,A,1X,A,1X,A,1X,I1,1X,I8,1X,A,1X)', advance='no') &
               trim(PED_REC%ID), trim(PED_REC%BREED), &
               trim(PED_REC%SIRE), trim(PED_REC%DAM), &
               PED_REC%SEX, PED_REC%BDate, trim(PED_REC%LOC)
            do j=1, snp_count
               write(unitGENO,'(I1)', advance='no') GENO(j)
            end do
            write(unitGENO, *)
         else
            animals_low_callrate = animals_low_callrate + 1
            ! Print animal statistics for excluded animal
            print '(A,I4,A,A,A,A,A,I6,A,I6,A,I6,A,F7.4,A)', &
               'Animal[', animal_seq_num, '] ',trim(PED_REC%ID), ' (',trim(PED_REC%BREED), &
               ') - Total SNPs: ', snp_count, ' Valid: ', (snp_count - count_miss), &
               ' Invalid: ', count_miss, ' CallRate: ', call_rate_animal, ' EXCLUDED (Low CallRate)'
            call flush(6)  ! Force output to screen immediately
         end if
         invalid_snp_total = invalid_snp_total + count_miss
         GENO = 9_ki1
      end if
      
      ! Initialize for new animal
      if (Sample_Name /= Previous_Animal) then
         ! Search PED using Sample_Name (can be ARN or ID depending on parameter)
         found_ped = pht_search(PED, Sample_Name, PED_REC)
         
         if (found_ped) then
            total_animals = total_animals + 1
         end if
         snp_count = 0
         count_miss = 0
         countX = 0
         countY = 0
         countY_hetero_errors = 0
         Previous_Animal = Sample_Name
      end if
      
      ! Process SNP data
      snp_count = snp_count + 1
      
      ! Read SNP_NAME from FR file and verify against MAP file
      Current_SNP_Name = trim(XC(SNPFile%FieldLoc(snp_name_idx)))
      
      ! Verify SNP order on first animal's first SNP
      if (.not. snp_order_verified .and. snp_count == 1) then
         if (trim(Current_SNP_Name) /= trim(MapInfo(snp_count)%SNP_ID)) then
            print '(A)', "========================================"
            print '(A)', "WARNING: SNP order mismatch detected!"
            print '(A,A)', "  FR file first SNP: ", trim(Current_SNP_Name)
            print '(A,A)', "  MAP file first SNP: ", trim(MapInfo(snp_count)%SNP_ID)
            print '(A)', "  Please ensure correct MAP file is specified:"
            print '(A)', "    - V2 FR files require MAP_V2.txt"
            print '(A)', "    - K FR files require MAP_K.txt"
            print '(A)', "========================================"
            stop "ERROR: FR and MAP file mismatch"
         else
            snp_order_verified = .true.
            print '(A)', "SNP order verified: FR and MAP files match"
         end if
      end if
      
      ! Extract alleles (using pre-calculated indices)
      if (idx_allele1 > 0 .and. idx_allele2 > 0) then
         Allele1 = XC(SNPFile%FieldLoc(idx_allele1))(1:1)
         Allele2 = XC(SNPFile%FieldLoc(idx_allele2))(1:1)
      else
         cycle
      end if
      
      ! Apply QC filters (using pre-calculated indices)
      if (idx_gc_score > 0 .and. XR(SNPFile%FieldLoc(idx_gc_score)) < thresh_min_gc) then
         count_miss = count_miss + 1
         cycle
      end if
      
      if (idx_r_intensity > 0) then
         if (XR(SNPFile%FieldLoc(idx_r_intensity)) < thresh_min_r .or. &
             XR(SNPFile%FieldLoc(idx_r_intensity)) > thresh_max_r) then
            count_miss = count_miss + 1
            cycle
         end if
      end if
      
      if (idx_gt_score > 0 .and. XR(SNPFile%FieldLoc(idx_gt_score)) < thresh_min_gt) then
         count_miss = count_miss + 1
         cycle
      end if
      
      if (idx_cluster_sep > 0 .and. XR(SNPFile%FieldLoc(idx_cluster_sep)) < thresh_min_cluster) then
         count_miss = count_miss + 1
         cycle
      end if
      
      ! Call genotype
      if (Allele1 == Allele2) then
         if (Allele1 == 'A') then
            genotype = 0_ki1
         elseif (Allele1 == 'B') then
            genotype = 2_ki1
         else
            genotype = 9_ki1
         end if
      else if ((Allele1 == 'A' .and. Allele2 == 'B') .or. &
               (Allele1 == 'B' .and. Allele2 == 'A')) then
         genotype = 1_ki1
      else
         genotype = 9_ki1
      end if
      
      ! Store genotype sequentially
      ! Note: MAP file provides two address types:
      !   - Array_All (Address_Total): Global position across all chromosomes (Chr, Position sorted)
      !   - Array_Chr (Address_Chr): Position within each chromosome (nested sorting)
      ! SNP data from FR file is stored in the order they appear in MAP file
      if (genotype /= 9_ki1) then
         GENO(snp_count) = genotype
         
         ! Sex chromosome check using current SNP's chromosome from MapInfo
         ! snp_count corresponds to the sequential order in MAP file
         if (snp_count <= tSNP) then
            if (MapInfo(snp_count)%Chr == 20) then
               call check_Sex(genotype, countX)
            elseif (MapInfo(snp_count)%Chr == 21) then
               if (genotype == 1_ki1) then
                  GENO(snp_count) = 9_ki1
                  countY_hetero_errors = countY_hetero_errors + 1
               else
                  call check_Sex(genotype, countY)
               end if
            end if
         end if
      else
         count_miss = count_miss + 1
      end if
   end do
   
   ! Output last animal
   if (len_trim(Previous_Animal) > 0 .and. found_ped) then
      animal_seq_num = animal_seq_num + 1
      call calculate_call_rate(snp_count, count_miss, call_rate_animal)
      if (call_rate_animal >= thresh_min_callrate) then
         animals_retained = animals_retained + 1
         valid_snp_total = valid_snp_total + (snp_count - count_miss)
         ! Print animal statistics
         print '(A,I4,A,A,A,A,A,I6,A,I6,A,I6,A,F7.4,A)', &
            'Animal[', animal_seq_num, '] ',trim(PED_REC%ID), ' (',trim(PED_REC%BREED), &
            ') - Total SNPs: ', snp_count, ' Valid: ', (snp_count - count_miss), &
            ' Invalid: ', count_miss, ' CallRate: ', call_rate_animal, ' RETAINED'
         call flush(6)  ! Force output to screen immediately
         write(unitGENO,'(A,1X,A,1X,A,1X,A,1X,I1,1X,I8,1X,A,1X)', advance='no') &
            trim(PED_REC%ID), trim(PED_REC%BREED), &
            trim(PED_REC%SIRE), trim(PED_REC%DAM), &
            PED_REC%SEX, PED_REC%BDate, trim(PED_REC%LOC)
         do j=1, snp_count
            write(unitGENO,'(I1)', advance='no') GENO(j)
         end do
         write(unitGENO, *)
      else
         animals_low_callrate = animals_low_callrate + 1
         ! Print animal statistics for excluded animal
         print '(A,I4,A,A,A,A,A,I6,A,I6,A,I6,A,F7.4,A)', &
            'Animal[', animal_seq_num, '] ',trim(PED_REC%ID), ' (',trim(PED_REC%BREED), &
            ') - Total SNPs: ', snp_count, ' Valid: ', (snp_count - count_miss), &
            ' Invalid: ', count_miss, ' CallRate: ', call_rate_animal, ' EXCLUDED (Low CallRate)'
         call flush(6)  ! Force output to screen immediately
      end if
      invalid_snp_total = invalid_snp_total + count_miss
   end if
   
   close(unit=unitGENO)
   print*, ""
   print*, "GENO file saved: "//trim(GenoFileName)
   print*, "========================================"
   print*, "Total animals processed: ", total_animals
   print*, "Animals retained (Call Rate >= ", thresh_min_callrate, "): ", animals_retained
   print*, "Animals excluded (Low Call Rate): ", animals_low_callrate
   print*, "========================================"
   print*, "Total Valid SNPs: ", valid_snp_total
   print*, "Total Invalid SNPs: ", invalid_snp_total
   print*, "========================================"
   close(unit=unitF)
contains
! Load PED file and populate hash table with dynamic hash key
! Animal_Field_Name parameter controls whether to hash by ARN or ID
subroutine load_ped_file(PED, NARN, unitF, Animal_Field_Name)
   type(PEDHashTable), intent(out) :: PED
   integer, intent(out) :: NARN, unitF
   character(len=*), intent(in) :: Animal_Field_Name
   integer :: i, n
   
   NARN = N_recf(PEDFile%FileName)
   NARN = NARN - PEDFile%Header
   print*,"Total number of PED records to read=", NARN
   print*,"Hash key field: ", trim(Animal_Field_Name)
   call pht_create(PED, int(NARN*1.3))
   unitF=fopen(trim(PEDFile%FileName))
   
   ! Skip header
   do i=1,PEDFile%Header
      call readline(unitF,n,XC,XI,dlm_str=trim(PEDFile%Delim_char))
   end do

   ! Read and store PED records
   do i=1,NARN
       call readline(unitF,n,XC,XI,dlm_str=trim(PEDFile%Delim_char))
       if(n < 0) exit
       call init_Ped(PED_REC)
       PED_REC%BREED= trim(XC(PEDFile%FieldLoc(1)))  ! Column 위치 기반: BREED는 1번 항목
       PED_REC%ID   = trim(XC(PEDFile%FieldLoc(2)))  ! Column 위치 기반: ID는 2번 항목 (parameter에서 2번째)
       PED_REC%ARN  = trim(XC(PEDFile%FieldLoc(3)))  ! Column 위치 기반: ARN은 3번 항목 (parameter에서 3번째)
       
       ! Determine hash key based on Animal_Field_Name parameter
       if (trim(Animal_Field_Name) == 'ANIMAL_ARN') then
           ! Use ARN as hash key (original behavior)
           if (len_trim(PED_REC%ARN) == 0 .or. trim(PED_REC%ARN) == "0") cycle
       else if (trim(Animal_Field_Name) == 'ANIMAL_ID') then
           ! Use ID as hash key (new behavior for ID-based PED files)
           if (len_trim(PED_REC%ID) == 0 .or. trim(PED_REC%ID) == "0") cycle
       else
           cycle  ! Skip if field name unknown
       end if
       
       PED_REC%SIRE = trim(XC(PEDFile%FieldLoc(4)))  ! Column 위치 기반: SIRE는 4번 항목 (parameter에서 4번째)
       PED_REC%DAM  = trim(XC(PEDFile%FieldLoc(5)))  ! Column 위치 기반: DAM은 5번 항목 (parameter에서 5번째)
       PED_REC%SEX  = XI(PEDFile%FieldLoc(6))        ! Column 위치 기반: SEX는 6번 항목 (parameter에서 6번째)
       PED_REC%BDate= XI(PEDFile%FieldLoc(7))        ! Column 위치 기반: BDATE는 7번 항목 (parameter에서 7번째)
       ! Read LOC field as text string
       PED_REC%LOC  = adjustl(trim(XC(PEDFile%FieldLoc(8))))  ! Column 위치 기반: LOC은 8번 항목 (parameter에서 8번째)
       call pht_insert_with_key(PED, PED_REC, Animal_Field_Name)
   end do
   close(unit=unitF)
   
   print*,"Total number of ", trim(Animal_Field_Name), " records in hash table=", PED%count
   NARN = PED%count
end subroutine load_ped_file
! Load MAP file with SNP information
! Supports two MAP versions (V2 and K) with standardized array addressing:
!   - ARRAY_ALL (Address_Total): SNPs ordered by Chr, Position across all chromosomes
!   - ARRAY_CHR (Address_Chr): SNPs ordered within each chromosome (nested sorting)
! This allows extraction of common SNPs from different MAP file types
subroutine load_map_file(MapInfo, tSNP, unitF)
   type(SNPInfo), allocatable, intent(out) :: MapInfo(:)
   integer, intent(out) :: tSNP, unitF
   integer :: i, n
   character(len=LEN_STR) :: first_snp_id
   character(len=30) :: map_version
   
   tSNP = N_recf(trim(MAPFile%FileName))
   tSNP = tSNP - MAPFile%Header
   print*,"Total number of SNPs in MAP file=", tSNP
   allocate(MapInfo(tSNP), GENO(tSNP))
   
   unitF = fopen(trim(MAPFile%FileName))
   do i=1,MAPFile%Header
      call readline(unitF,n,XC,XI,dlm_str=trim(MAPFile%Delim_char))
   end do
   
   do i=1,tSNP
       call readline(unitF,n,XC,XI,dlm_str=trim(MAPFile%Delim_char))
       MapInfo(i)%SNP_ID    = trim(XC(MAPFile%FieldLoc(1)))  ! Column 위치 기반: SNP_ID는 1번 항목 (parameter에서 1번째)
       MapInfo(i)%Chr       = XI(MAPFile%FieldLoc(2))         ! Column 위치 기반: CHR은 2번 항목 (parameter에서 2번째)
       MapInfo(i)%Pos       = XI(MAPFile%FieldLoc(3))         ! Column 위치 기반: POS는 3번 항목 (parameter에서 3번째)
       ! ARRAY_ALL: Address_Total (전체 SNP을 Chr, Position으로 순서화 - 모든 염색체 통합)
       ! ARRAY_CHR: Address_Chr (염색체 내에서 nested 순서화)
       MapInfo(i)%Array_All = XI(MAPFile%FieldLoc(4))         ! Column 위치 기반: ARRAY_ALL은 4번 항목 (parameter에서 4번째)
       MapInfo(i)%Array_Chr = XI(MAPFile%FieldLoc(5))         ! Column 위치 기반: ARRAY_CHR은 5번 항목 (parameter에서 5번째)
   end do
   close(unit=unitF)
   
   ! Detect MAP version from first SNP ID format
   first_snp_id = trim(MapInfo(1)%SNP_ID)
   if (index(first_snp_id, 'ALGA') > 0 .or. index(first_snp_id, 'ASGA') > 0 .or. &
       index(first_snp_id, 'DIAS') > 0 .or. index(first_snp_id, 'MARC') > 0) then
      map_version = 'V2 (Porcine60K)'
   else if (index(first_snp_id, '_') > 0) then
      map_version = 'K (GGP-Porcine)'
   else
      map_version = 'Unknown'
   end if
   print '(A,A,A,A,A)', "MAP version detected: ", trim(map_version), " (First SNP: ", trim(first_snp_id), ")"
end subroutine load_map_file
! Get SNP dimensions from file header
subroutine get_snp_dimensions(SNPFile, unitF, nSNP, NREC)
   type(FileInfo), intent(in) :: SNPFile
   integer, intent(out) :: unitF, nSNP, NREC
   integer :: i, n
   
   unitF = fopen(trim(SNPFile%FileName))
   nSNP = 0
   NREC = 0
   
   do i=1,SNPFile%Header     
      call readline(unitF,n,XC,XI,dlm_str=trim(SNPFile%Delim_char))
      if(n < 0) exit
      if(trim(XC(1)) == "Num SNPs") nSNP = XI(2)
      if(trim(XC(1)) == "Num Samples") NREC = XI(2)
   end do
   
   print*,"number of SNP=", nSNP
   print*,"number of Animals=", NREC
end subroutine get_snp_dimensions

! =========================================================================
! =========================================================================
! 7. Call Rate 계산
! =========================================================================
subroutine calculate_call_rate(snp_count, count_miss, call_rate_animal)
   integer, intent(in) :: snp_count, count_miss
   real, intent(out) :: call_rate_animal
   
   if(snp_count > 0) then
      call_rate_animal = 1.0_r4 - real(count_miss)/real(snp_count)
   else
      call_rate_animal = 0.0_r4
   end if
end subroutine calculate_call_rate

! =========================================================================
! 8. 성염색체 검증 (기존 부프로그램)
! =========================================================================
subroutine check_Sex(Sex_Genotype, cnt)
   integer(kind=ki1), intent(in) :: Sex_Genotype
   integer, intent(inout) :: cnt(3)

   if(Sex_Genotype == 9_ki1) then
      return
   else
      select case(Sex_Genotype)
         case(0_ki1)
            cnt(1) = cnt(1) + 1
         case(1_ki1)
            cnt(2) = cnt(2) + 1
         case(2_ki1)
            cnt(3) = cnt(3) + 1
      end select
   end if
end subroutine Check_Sex

logical function check_SNP_ID(ID1, ID2)
  implicit none
  character(len=*), intent(in) :: ID1, ID2
  if(trim(ID1) == trim(ID2)) then
     check_SNP_ID = .true.
  else
     check_SNP_ID = .false.
  end if
end function check_SNP_ID 

integer(kind=ki1) function SeekGeno(A1, A2)
  implicit none
  character(len=1), intent(in) :: A1, A2
  integer(kind=ki1) :: A1_N, A2_N
  A1_N = changeNum(A1)     
  A2_N = changeNum(A2)     
  if(max(A1_N, A2_N) == 9_ki1) then
     SeekGeno = 9_ki1
  else   
     SeekGeno = A1_N + A2_N
  end if
end function SeekGeno

integer(kind=ki1) function changeNum(A_char) result(A_num)
  implicit none
  character(len=1), intent(in) :: A_char
  select case(A_char)
     case('A')
        A_num = 0_ki1
     case('B')
        A_num = 1_ki1
     case default
        A_num = 9_ki1
  end select
end function changeNum

subroutine generate_output_filename(GenoFileName)
  implicit none
  character(len=*), intent(out) :: GenoFileName
  character(len=10) :: date_str

  integer :: values(8)
  integer :: seq_num
  character(len=MAX_STR) :: test_filename
  character(len=6) :: input_prefix
  character(len=MAX_STR) :: basename
  integer :: pos_slash, pos_dot, basename_len
  logical :: file_exists
  
  ! Get current date and time
  call date_and_time(values=values)
  
  ! Format as YYYYMMDD
  write(date_str, '(I4.4,I2.2,I2.2)') values(1), values(2), values(3)
  
  ! Extract first 6 characters from input filename (basename only, not full path)
  basename = trim(SNPFile%FileName)
  
  ! Remove path - find last '/' or '\'
  pos_slash = index(basename, '/', back=.true.)
  if (pos_slash > 0) then
     basename = basename(pos_slash+1:)
  end if
  
  ! Remove extension - find last '.'
  pos_dot = index(basename, '.', back=.true.)
  if (pos_dot > 0) then
     basename = basename(1:pos_dot-1)
  end if
  
  ! Get first 6 characters (or less if basename is shorter)
  basename_len = len_trim(basename)
  if (basename_len >= 6) then
     input_prefix = basename(1:6)
  else
     input_prefix = basename(1:basename_len)
  end if
  
  ! Try sequence numbers from 00 to 99
  do seq_num = 0, 99
     write(test_filename, '(A,A,A,A,A,A,I2.2,A)') &
        trim(OutputPrefix), '_', trim(input_prefix), '_', trim(date_str), '_', seq_num, '.geno'
     inquire(file=trim(test_filename), exist=file_exists)
     if (.not. file_exists) then
        GenoFileName = trim(test_filename)
        return
     end if
  end do
  
  ! If all numbered files exist (rare), use default
  write(GenoFileName, '(A,A,A,A,A,A)') &
     trim(OutputPrefix), '_', trim(input_prefix), '_', trim(date_str), '_99.geno'
  
end subroutine generate_output_filename

end program ReadFR
