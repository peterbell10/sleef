include(CheckCCompilerFlag)
include(CheckCSourceCompiles)
include(CheckTypeSize)
include(CheckLanguage)

if (BUILD_STATIC_TEST_BINS)
  set(CMAKE_FIND_LIBRARY_SUFFIXES ".a")
  set(BUILD_SHARED_LIBS OFF)
  set(CMAKE_EXE_LINKER_FLAGS "-static")
endif()

if (NOT CMAKE_CROSSCOMPILING AND NOT SLEEF_FORCE_FIND_PACKAGE_SSL)
  find_package(OpenSSL)
  if (OPENSSL_FOUND)
    set(SLEEF_OPENSSL_FOUND TRUE)
    set(SLEEF_OPENSSL_LIBRARIES ${OPENSSL_LIBRARIES})
    set(SLEEF_OPENSSL_VERSION ${OPENSSL_VERSION})
    set(SLEEF_OPENSSL_INCLUDE_DIR ${OPENSSL_INCLUDE_DIR})
  endif()
else()
  # find_package cannot find OpenSSL when cross-compiling
  find_library(LIBSSL ssl)
  find_library(LIBCRYPTO crypto)
  if (LIBSSL AND LIBCRYPTO)
    set(SLEEF_OPENSSL_FOUND TRUE)
    set(SLEEF_OPENSSL_LIBRARIES ${LIBSSL} ${LIBCRYPTO})
    set(SLEEF_OPENSSL_VERSION ${LIBSSL})
  endif()
endif()

if (ENFORCE_TESTER3 AND NOT SLEEF_OPENSSL_FOUND)
  message(FATAL_ERROR "ENFORCE_TESTER3 is specified and OpenSSL not found")
endif()

if (NOT (RUNNING_ON_APPVEYOR AND SLEEF_CLANG_ON_WINDOWS))
  # We rely on Cygwin tools in order to test the builds on
  # appveyor. However, if we try to link these libraries, cmake finds
  # the Cygwin version of libraries, which causes errors.
  
  # Some toolchains require explicit linking of the libraries following.
  find_library(LIB_MPFR mpfr)
  find_library(LIBM m)
  find_library(LIBGMP gmp)
  find_library(LIBRT rt)
  find_library(LIBFFTW3 fftw3)

  if (LIB_MPFR)
    find_path(MPFR_INCLUDE_DIR
      NAMES mpfr.h
      ONLY_CMAKE_FIND_ROOT_PATH)
  endif(LIB_MPFR)

  if (LIBFFTW3)
    find_path(FFTW3_INCLUDE_DIR
      NAMES fftw3.h
      ONLY_CMAKE_FIND_ROOT_PATH)
  endif(LIBFFTW3)

  if (NOT LIBM)
    set(LIBM "")
  endif()

  if (NOT LIBRT)
    set(LIBRT "")
  endif()
endif(NOT (RUNNING_ON_APPVEYOR AND SLEEF_CLANG_ON_WINDOWS))

# The library currently supports the following SIMD architectures
set(SLEEF_SUPPORTED_EXTENSIONS
  AVX512FNOFMA AVX512F AVX2 AVX2128 FMA4 AVX SSE4 SSE2  # x86
  SVENOFMA SVE ADVSIMDNOFMA ADVSIMD                     # Aarch64
  NEON32 NEON32VFPV4                                    # Aarch32
  VSX VSXNOFMA                                          # PPC64
  VXE VXENOFMA VXE2 VXE2NOFMA	                        # IBM Z
  PUREC_SCALAR PURECFMA_SCALAR                          # Generic type
  CACHE STRING "List of SIMD architectures supported by libsleef."
  )
set(SLEEF_SUPPORTED_GNUABI_EXTENSIONS 
  SSE2 AVX AVX2 AVX512F ADVSIMD SVE
  CACHE STRING "List of SIMD architectures supported by libsleef for GNU ABI."
)
set(SLEEFQUAD_SUPPORTED_EXT
  PUREC_SCALAR PURECFMA_SCALAR SSE2 AVX2 AVX512F ADVSIMD SVE VSX ZVECTOR2)
# Force set default build type if none was specified
# Note: some sleef code requires the optimisation flags turned on
if(NOT CMAKE_BUILD_TYPE)
  message(STATUS "Setting build type to 'Release' (required for full support).")
  set(CMAKE_BUILD_TYPE Release CACHE STRING "Choose the type of build." FORCE)
  set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
    "Debug" "Release" "RelWithDebInfo" "MinSizeRel")
endif()

# Function used to generate safe command arguments for add_custom_command
function(command_arguments PROPNAME)
  set(quoted_args "")
  foreach(arg ${ARGN})
    list(APPEND quoted_args "\"${arg}\"" )
  endforeach()
  set(${PROPNAME} ${quoted_args} PARENT_SCOPE)
endfunction()

# PLATFORM DETECTION
if((CMAKE_SYSTEM_PROCESSOR MATCHES "x86") OR (CMAKE_SYSTEM_PROCESSOR MATCHES "AMD64") OR (CMAKE_SYSTEM_PROCESSOR MATCHES "amd64") OR (CMAKE_SYSTEM_PROCESSOR MATCHES "^i.86$"))
  set(SLEEF_ARCH_X86 ON CACHE INTERNAL "True for x86 architecture.")

  set(SLEEF_HEADER_LIST
    SSE_
    SSE2
    SSE4
    AVX_
    AVX
    FMA4
    AVX2
    AVX2128
    AVX512F_
    AVX512F
    AVX512FNOFMA
    PUREC_SCALAR
    PURECFMA_SCALAR
  )
  command_arguments(HEADER_PARAMS_SSE_          cinz_ 2 4 __m128d __m128 __m128i __m128i __SSE2__)
  command_arguments(HEADER_PARAMS_SSE2          cinz_ 2 4 __m128d __m128 __m128i __m128i __SSE2__ sse2)
  command_arguments(HEADER_PARAMS_SSE4          cinz_ 2 4 __m128d __m128 __m128i __m128i __SSE2__ sse4)
  command_arguments(HEADER_PARAMS_AVX_          cinz_ 4 8 __m256d __m256 __m128i "struct { __m128i x, y$<SEMICOLON> }" __AVX__)
  command_arguments(HEADER_PARAMS_AVX           cinz_ 4 8 __m256d __m256 __m128i "struct { __m128i x, y$<SEMICOLON> }" __AVX__ avx)
  command_arguments(HEADER_PARAMS_FMA4          finz_ 4 8 __m256d __m256 __m128i "struct { __m128i x, y$<SEMICOLON> }" __AVX__ fma4)
  command_arguments(HEADER_PARAMS_AVX2          finz_ 4 8 __m256d __m256 __m128i __m256i __AVX__ avx2)
  command_arguments(HEADER_PARAMS_AVX2128       finz_ 2 4 __m128d __m128 __m128i __m128i __SSE2__ avx2128)
  command_arguments(HEADER_PARAMS_AVX512F_      finz_ 8 16 __m512d __m512 __m256i __m512i __AVX512F__)
  command_arguments(HEADER_PARAMS_AVX512F       finz_ 8 16 __m512d __m512 __m256i __m512i __AVX512F__ avx512f)
  command_arguments(HEADER_PARAMS_AVX512FNOFMA  cinz_ 8 16 __m512d __m512 __m256i __m512i __AVX512F__ avx512fnofma)

  command_arguments(ALIAS_PARAMS_AVX512F_DP   8 __m512d __m256i e avx512f)
  command_arguments(ALIAS_PARAMS_AVX512F_SP -16 __m512  __m512i e avx512f)

  set(CLANG_FLAGS_ENABLE_PURECFMA_SCALAR "-mavx2;-mfma;-fno-strict-aliasing")

  set(TESTER3_DEFINITIONS_SSE2          ATR=cinz_ DPTYPE=__m128d SPTYPE=__m128 DPTYPESPEC=d2 SPTYPESPEC=f4  EXTSPEC=sse2)
  set(TESTER3_DEFINITIONS_SSE4          ATR=cinz_ DPTYPE=__m128d SPTYPE=__m128 DPTYPESPEC=d2 SPTYPESPEC=f4  EXTSPEC=sse4)
  set(TESTER3_DEFINITIONS_AVX2128       ATR=finz_ DPTYPE=__m128d SPTYPE=__m128 DPTYPESPEC=d2 SPTYPESPEC=f4  EXTSPEC=avx2128)
  set(TESTER3_DEFINITIONS_AVX           ATR=cinz_ DPTYPE=__m256d SPTYPE=__m256 DPTYPESPEC=d4 SPTYPESPEC=f8  EXTSPEC=avx)
  set(TESTER3_DEFINITIONS_FMA4          ATR=finz_ DPTYPE=__m256d SPTYPE=__m256 DPTYPESPEC=d4 SPTYPESPEC=f8  EXTSPEC=fma4)
  set(TESTER3_DEFINITIONS_AVX2          ATR=finz_ DPTYPE=__m256d SPTYPE=__m256 DPTYPESPEC=d4 SPTYPESPEC=f8  EXTSPEC=avx2)
  set(TESTER3_DEFINITIONS_AVX512F       ATR=finz_ DPTYPE=__m512d SPTYPE=__m512 DPTYPESPEC=d8 SPTYPESPEC=f16 EXTSPEC=avx512f)
  set(TESTER3_DEFINITIONS_AVX512FNOFMA  ATR=cinz_ DPTYPE=__m512d SPTYPE=__m512 DPTYPESPEC=d8 SPTYPESPEC=f16 EXTSPEC=avx512fnofma)

elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64|arm64")
  set(SLEEF_ARCH_AARCH64 ON CACHE INTERNAL "True for Aarch64 architecture.")
  # Aarch64 requires support for advsimdfma4
  set(COMPILER_SUPPORTS_ADVSIMD 1)
  set(COMPILER_SUPPORTS_ADVSIMDNOFMA 1)

  set(SLEEF_HEADER_LIST
    ADVSIMD_
    ADVSIMD
    ADVSIMDNOFMA
    SVE
    SVENOFMA
    PUREC_SCALAR
    PURECFMA_SCALAR
  )
  command_arguments(HEADER_PARAMS_ADVSIMD_      finz_ 2 4 float64x2_t float32x4_t int32x2_t int32x4_t __ARM_NEON)
  command_arguments(HEADER_PARAMS_ADVSIMD       finz_ 2 4 float64x2_t float32x4_t int32x2_t int32x4_t __ARM_NEON advsimd)
  command_arguments(HEADER_PARAMS_ADVSIMDNOFMA  cinz_ 2 4 float64x2_t float32x4_t int32x2_t int32x4_t __ARM_NEON advsimdnofma)
  command_arguments(HEADER_PARAMS_SVE           finz_ x x svfloat64_t svfloat32_t svint32_t svint32_t __ARM_FEATURE_SVE sve)
  command_arguments(HEADER_PARAMS_SVENOFMA      cinz_ x x svfloat64_t svfloat32_t svint32_t svint32_t __ARM_FEATURE_SVE svenofma)

  command_arguments(ALIAS_PARAMS_ADVSIMD_DP  2 float64x2_t int32x2_t n advsimd)
  command_arguments(ALIAS_PARAMS_ADVSIMD_SP -4 float32x4_t int32x4_t n advsimd)

  set(TESTER3_DEFINITIONS_ADVSIMD       ATR=finz_ DPTYPE=float64x2_t SPTYPE=float32x4_t DPTYPESPEC=d2 SPTYPESPEC=f4 EXTSPEC=advsimd)
  set(TESTER3_DEFINITIONS_ADVSIMDNOFMA  ATR=cinz_ DPTYPE=float64x2_t SPTYPE=float32x4_t DPTYPESPEC=d2 SPTYPESPEC=f4 EXTSPEC=advsimdnofma)
  set(TESTER3_DEFINITIONS_SVE           ATR=finz_ DPTYPE=svfloat64_t SPTYPE=svfloat32_t DPTYPESPEC=dx SPTYPESPEC=fx EXTSPEC=sve)
  set(TESTER3_DEFINITIONS_SVENOFMA      ATR=cinz_ DPTYPE=svfloat64_t SPTYPE=svfloat32_t DPTYPESPEC=dx SPTYPESPEC=fx EXTSPEC=svenofma)

elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "arm")
  set(SLEEF_ARCH_AARCH32 ON CACHE INTERNAL "True for Aarch32 architecture.")
  set(COMPILER_SUPPORTS_NEON32 1)
  set(COMPILER_SUPPORTS_NEON32VFPV4 1)

  set(SLEEF_HEADER_LIST
    NEON32_
    NEON32
    NEON32VFPV4
    PUREC_SCALAR
    PURECFMA_SCALAR
  )
  command_arguments(HEADER_PARAMS_NEON32_     cinz_ 2 4 - float32x4_t int32x2_t int32x4_t __ARM_NEON__)
  command_arguments(HEADER_PARAMS_NEON32      cinz_ 2 4 - float32x4_t int32x2_t int32x4_t __ARM_NEON__ neon)
  command_arguments(HEADER_PARAMS_NEON32VFPV4 finz_ 2 4 - float32x4_t int32x2_t int32x4_t __ARM_NEON__ neonvfpv4)

  command_arguments(ALIAS_PARAMS_NEON32_SP -4 float32x4_t int32x4_t - neon)
  command_arguments(ALIAS_PARAMS_NEON32_DP 0)

  set(CLANG_FLAGS_ENABLE_PURECFMA_SCALAR "-mfpu=vfpv4;-fno-strict-aliasing")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^(powerpc|ppc)64")
  set(SLEEF_ARCH_PPC64 ON CACHE INTERNAL "True for PPC64 architecture.")

  set(SLEEF_HEADER_LIST
    VSX_
    VSX
    VSXNOFMA
    PUREC_SCALAR
    PURECFMA_SCALAR
  )

  set(HEADER_PARAMS_VSX       finz_ 2 4 "__vector double" "__vector float" "__vector int" "__vector int" __VSX__ vsx)
  set(HEADER_PARAMS_VSX_      finz_ 2 4 "__vector double" "__vector float" "__vector int" "__vector int" __VSX__ vsx)
  set(HEADER_PARAMS_VSXNOFMA  cinz_ 2 4 "__vector double" "__vector float" "__vector int" "__vector int" __VSX__ vsxnofma)
  set(ALIAS_PARAMS_VSX_DP  2 "__vector double" "__vector int" - vsx)
  set(ALIAS_PARAMS_VSX_SP -4 "__vector float" "__vector int" - vsx)

  set(CLANG_FLAGS_ENABLE_PURECFMA_SCALAR "-mvsx;-fno-strict-aliasing")

  set(TESTER3_DEFINITIONS_VSX      ATR=finz_ DPTYPE=__vector_double SPTYPE=__vector_float DPTYPESPEC=d2 SPTYPESPEC=f4 EXTSPEC=vsx)
  set(TESTER3_DEFINITIONS_VSXNOFMA ATR=cinz_ DPTYPE=__vector_double SPTYPE=__vector_float DPTYPESPEC=d2 SPTYPESPEC=f4 EXTSPEC=vsxnofma)

elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "s390x")
  set(SLEEF_ARCH_S390X ON CACHE INTERNAL "True for IBM Z architecture.")

  set(SLEEF_HEADER_LIST
    VXE_
    VXE
    VXENOFMA
    VXE2
    VXE2NOFMA
    PUREC_SCALAR
    PURECFMA_SCALAR
  )

  set(HEADER_PARAMS_VXE_          finz_ 2 4 "SLEEF_VECTOR_DOUBLE" "SLEEF_VECTOR_FLOAT" "SLEEF_VECTOR_INT" "SLEEF_VECTOR_INT" __VEC__)
  set(HEADER_PARAMS_VXE           finz_ 2 4 "SLEEF_VECTOR_DOUBLE" "SLEEF_VECTOR_FLOAT" "SLEEF_VECTOR_INT" "SLEEF_VECTOR_INT" __VEC__ vxe)
  set(HEADER_PARAMS_VXENOFMA      cinz_ 2 4 "SLEEF_VECTOR_DOUBLE" "SLEEF_VECTOR_FLOAT" "SLEEF_VECTOR_INT" "SLEEF_VECTOR_INT" __VEC__ vxenofma)
  set(HEADER_PARAMS_VXE2          finz_ 2 4 "SLEEF_VECTOR_DOUBLE" "SLEEF_VECTOR_FLOAT" "SLEEF_VECTOR_INT" "SLEEF_VECTOR_INT" __VEC__ vxe2)
  set(HEADER_PARAMS_VXE2NOFMA     cinz_ 2 4 "SLEEF_VECTOR_DOUBLE" "SLEEF_VECTOR_FLOAT" "SLEEF_VECTOR_INT" "SLEEF_VECTOR_INT" __VEC__ vxe2nofma)
  set(ALIAS_PARAMS_VXE_DP  2 "__vector double" "__vector int" - vxe)
  set(ALIAS_PARAMS_VXE_SP -4 "__vector float"  "__vector int" - vxe)
  set(ALIAS_PARAMS_VXE2_DP  2 "__vector double" "__vector int" - vxe2)
  set(ALIAS_PARAMS_VXE2_SP -4 "__vector float"  "__vector int" - vxe2)

  set(CLANG_FLAGS_ENABLE_PURECFMA_SCALAR "-march=z14;-mzvector;-fno-strict-aliasing")

  set(TESTER3_DEFINITIONS_VXE       ATR=finz_ DPTYPE=SLEEF_VECTOR_DOUBLE SPTYPE=SLEEF_VECTOR_FLOAT DPTYPESPEC=d2 SPTYPESPEC=f4 EXTSPEC=vxe)
  set(TESTER3_DEFINITIONS_VXENOFMA  ATR=cinz_ DPTYPE=SLEEF_VECTOR_DOUBLE SPTYPE=SLEEF_VECTOR_FLOAT DPTYPESPEC=d2 SPTYPESPEC=f4 EXTSPEC=vxenofma)
  set(TESTER3_DEFINITIONS_VXE2      ATR=finz_ DPTYPE=SLEEF_VECTOR_DOUBLE SPTYPE=SLEEF_VECTOR_FLOAT DPTYPESPEC=d2 SPTYPESPEC=f4 EXTSPEC=vxe2)
  set(TESTER3_DEFINITIONS_VXE2NOFMA ATR=cinz_ DPTYPE=SLEEF_VECTOR_DOUBLE SPTYPE=SLEEF_VECTOR_FLOAT DPTYPESPEC=d2 SPTYPESPEC=f4 EXTSPEC=vxe2nofma)
endif()

command_arguments(HEADER_PARAMS_PUREC_SCALAR    cinz_ 1 1 double float int32_t int32_t __STDC__ purec)
command_arguments(HEADER_PARAMS_PURECFMA_SCALAR finz_ 1 1 double float int32_t int32_t FP_FAST_FMA purecfma)
command_arguments(ALIAS_PARAMS_PUREC_SCALAR_DP     1 double int32_t purec cinz_)
command_arguments(ALIAS_PARAMS_PUREC_SCALAR_SP    -1 float  int32_t purec cinz_)
command_arguments(ALIAS_PARAMS_PURECFMA_SCALAR_DP  1 double int32_t purecfma finz_)
command_arguments(ALIAS_PARAMS_PURECFMA_SCALAR_SP -1 float  int32_t purecfma finz_)

set(TESTER3_DEFINITIONS_PUREC_SCALAR    ATR=cinz_ DPTYPE=double SPTYPE=float DPTYPESPEC=d1 SPTYPESPEC=f1 EXTSPEC=purec)
set(TESTER3_DEFINITIONS_PURECFMA_SCALAR ATR=finz_ DPTYPE=double SPTYPE=float DPTYPESPEC=d1 SPTYPESPEC=f1 EXTSPEC=purecfma)
set(COMPILER_SUPPORTS_PUREC_SCALAR 1)
set(COMPILER_SUPPORTS_PURECFMA_SCALAR 1)

# MKRename arguments per type
command_arguments(RENAME_PARAMS_SSE2            cinz_ 2 4 sse2)
command_arguments(RENAME_PARAMS_SSE4            cinz_ 2 4 sse4)
command_arguments(RENAME_PARAMS_AVX             cinz_ 4 8 avx)
command_arguments(RENAME_PARAMS_FMA4            finz_ 4 8 fma4)
command_arguments(RENAME_PARAMS_AVX2            finz_ 4 8 avx2)
command_arguments(RENAME_PARAMS_AVX2128         finz_ 2 4 avx2128)
command_arguments(RENAME_PARAMS_AVX512F         finz_ 8 16 avx512f)
command_arguments(RENAME_PARAMS_AVX512FNOFMA    cinz_ 8 16 avx512fnofma)
command_arguments(RENAME_PARAMS_ADVSIMD         finz_ 2 4 advsimd)
command_arguments(RENAME_PARAMS_ADVSIMDNOFMA    cinz_ 2 4 advsimdnofma)
command_arguments(RENAME_PARAMS_NEON32          cinz_ 2 4 neon)
command_arguments(RENAME_PARAMS_NEON32VFPV4     finz_ 2 4 neonvfpv4)
command_arguments(RENAME_PARAMS_VSX             finz_ 2 4 vsx)
command_arguments(RENAME_PARAMS_VSXNOFMA        cinz_ 2 4 vsxnofma)
command_arguments(RENAME_PARAMS_VXE             finz_ 2 4 vxe)
command_arguments(RENAME_PARAMS_VXENOFMA        cinz_ 2 4 vxenofma)
command_arguments(RENAME_PARAMS_VXE2            finz_ 2 4 vxe2)
command_arguments(RENAME_PARAMS_VXE2NOFMA       cinz_ 2 4 vxe2nofma)
command_arguments(RENAME_PARAMS_PUREC_SCALAR    cinz_ 1 1 purec)
command_arguments(RENAME_PARAMS_PURECFMA_SCALAR finz_ 1 1 purecfma)
command_arguments(RENAME_PARAMS_CUDA            finz_ 1 1 cuda)
# The vector length parameters in SVE, for SP and DP, are chosen for
# the smallest SVE vector size (128-bit). The name is generated using
# the "x" token of VLA SVE vector functions.
command_arguments(RENAME_PARAMS_SVE             finz_ x x sve)
command_arguments(RENAME_PARAMS_SVENOFMA        cinz_ x x svenofma)

command_arguments(RENAME_PARAMS_GNUABI_SSE2     sse2 b 2 4 _mm128d _mm128 _mm128i _mm128i __SSE2__)
command_arguments(RENAME_PARAMS_GNUABI_AVX      avx c 4 8 __m256d __m256 __m128i "struct { __m128i x, y$<SEMICOLON> }" __AVX__)
command_arguments(RENAME_PARAMS_GNUABI_AVX2     avx2 d 4 8 __m256d __m256 __m128i __m256i __AVX2__)
command_arguments(RENAME_PARAMS_GNUABI_AVX512F  avx512f e 8 16 __m512d __m512 __m256i __m512i __AVX512F__)
command_arguments(RENAME_PARAMS_GNUABI_ADVSIMD  advsimd n 2 4 float64x2_t float32x4_t int32x2_t int32x4_t __ARM_NEON)
# The vector length parameters in SVE, for SP and DP, are chosen for
# the smallest SVE vector size (128-bit). The name is generated using
# the "x" token of VLA SVE vector functions.
command_arguments(RENAME_PARAMS_GNUABI_SVE sve s x x svfloat64_t svfloat32_t svint32_t svint32_t __ARM_SVE)

command_arguments(MKMASKED_PARAMS_GNUABI_AVX512F_dp avx512f e 8)
command_arguments(MKMASKED_PARAMS_GNUABI_AVX512F_sp avx512f e -16)

command_arguments(MKMASKED_PARAMS_GNUABI_SVE_dp sve s 2)
command_arguments(MKMASKED_PARAMS_GNUABI_SVE_sp sve s -4)

# COMPILER DETECTION

# Detect CLANG executable path (on both Windows and Linux/OSX)
if(NOT CLANG_EXE_PATH)
  # If the current compiler used by CMAKE is already clang, use this one directly
  if(CMAKE_C_COMPILER MATCHES "clang")
    set(CLANG_EXE_PATH ${CMAKE_C_COMPILER})
  else()
    # Else we may find clang on the path?
    find_program(CLANG_EXE_PATH NAMES clang "clang-5.0" "clang-4.0" "clang-3.9")
  endif()
endif()

# Allow to define the Gcc/Clang here
# As we might compile the lib with MSVC, but generates bitcode with CLANG
# Intel vector extensions.
set(CLANG_FLAGS_ENABLE_SSE2 "-msse2")
set(CLANG_FLAGS_ENABLE_SSE4 "-msse4.1")
set(CLANG_FLAGS_ENABLE_AVX "-mavx")
set(CLANG_FLAGS_ENABLE_FMA4 "-mfma4")
set(CLANG_FLAGS_ENABLE_AVX2 "-mavx2;-mfma")
set(CLANG_FLAGS_ENABLE_AVX2128 "-mavx2;-mfma")
set(CLANG_FLAGS_ENABLE_AVX512F "-mavx512f")
set(CLANG_FLAGS_ENABLE_AVX512FNOFMA "-mavx512f")
set(CLANG_FLAGS_ENABLE_NEON32 "--target=arm-linux-gnueabihf;-mcpu=cortex-a8")
set(CLANG_FLAGS_ENABLE_NEON32VFPV4 "-march=armv7-a;-mfpu=neon-vfpv4")
# Arm AArch64 vector extensions.
set(CLANG_FLAGS_ENABLE_SVE "-march=armv8-a+sve")
set(CLANG_FLAGS_ENABLE_SVENOFMA "-march=armv8-a+sve")
# PPC64
set(CLANG_FLAGS_ENABLE_VSX "-mcpu=power8")
set(CLANG_FLAGS_ENABLE_VSXNOFMA "-mcpu=power8")
# IBM z
set(CLANG_FLAGS_ENABLE_VXE "-march=z14;-mzvector")
set(CLANG_FLAGS_ENABLE_VXENOFMA "-march=z14;-mzvector")
set(CLANG_FLAGS_ENABLE_VXE2 "-march=z15;-mzvector")
set(CLANG_FLAGS_ENABLE_VXE2NOFMA "-march=z15;-mzvector")

set(FLAGS_OTHERS "")

# All variables storing compiler flags should be prefixed with FLAGS_
if(CMAKE_C_COMPILER_ID MATCHES "(GNU|Clang)")
  # Always compile sleef with -ffp-contract.
  set(FLAGS_STRICTMATH "-ffp-contract=off")
  set(FLAGS_FASTMATH "-ffast-math")
  set(FLAGS_NOSTRICTALIASING "-fno-strict-aliasing")

  # Without the options below, gcc generates calls to libm
  string(CONCAT FLAGS_OTHERS "-fno-math-errno -fno-trapping-math")
  
  # Intel vector extensions.
  foreach(SIMD ${SLEEF_SUPPORTED_EXTENSIONS})
    set(FLAGS_ENABLE_${SIMD} ${CLANG_FLAGS_ENABLE_${SIMD}})
  endforeach()

  # Warning flags.
  set(FLAGS_WALL "-Wall -Wno-unused -Wno-attributes -Wno-unused-result")
  if(CMAKE_C_COMPILER_ID MATCHES "GNU")
    # The following compiler option is needed to suppress the warning
    # "AVX vector return without AVX enabled changes the ABI" at
    # src/arch/helpervecext.h:88
    string(CONCAT FLAGS_WALL ${FLAGS_WALL} " -Wno-psabi")
    set(FLAGS_ENABLE_NEON32 "-mfpu=neon")
  endif(CMAKE_C_COMPILER_ID MATCHES "GNU")

  if(CMAKE_C_COMPILER_ID MATCHES "Clang" AND ENABLE_LTO)
    if (NOT LLVM_AR_COMMAND)
      find_program(LLVM_AR_COMMAND "llvm-ar")
    endif()
    if (LLVM_AR_COMMAND)
      SET(CMAKE_AR ${LLVM_AR_COMMAND})
      SET(CMAKE_C_ARCHIVE_CREATE "<CMAKE_AR> rcs <TARGET> <LINK_FLAGS> <OBJECTS>")
      SET(CMAKE_C_ARCHIVE_FINISH "true")
    endif(LLVM_AR_COMMAND)
    string(CONCAT FLAGS_OTHERS "-flto=thin")
  endif(CMAKE_C_COMPILER_ID MATCHES "Clang" AND ENABLE_LTO)

  # Flags for generating inline headers
  set(FLAG_PREPROCESS "-E")
  set(FLAG_PRESERVE_COMMENTS "-C")
  set(FLAG_INCLUDE "-I")
  set(FLAG_DEFINE "-D")

  if (SLEEF_CLANG_ON_WINDOWS)
    # The following line is required to prevent clang from displaying
    # many warnings. Clang on Windows references MSVC header files,
    # which have deprecation and security attributes for many
    # functions.

    string(CONCAT FLAGS_WALL ${FLAGS_WALL} " -D_CRT_SECURE_NO_WARNINGS -Wno-deprecated-declarations")
  endif()
elseif(MSVC)
  # Intel vector extensions.
  if (CMAKE_CL_64)
    set(FLAGS_ENABLE_SSE2 /D__SSE2__)
    set(FLAGS_ENABLE_SSE4 /D__SSE2__ /D__SSE3__ /D__SSE4_1__)
  else()
    set(FLAGS_ENABLE_SSE2 /D__SSE2__ /arch:SSE2)
    set(FLAGS_ENABLE_SSE4 /D__SSE2__ /D__SSE3__ /D__SSE4_1__ /arch:SSE2)
  endif()
  set(FLAGS_ENABLE_AVX  /D__SSE2__ /D__SSE3__ /D__SSE4_1__ /D__AVX__ /arch:AVX)
  set(FLAGS_ENABLE_FMA4 /D__SSE2__ /D__SSE3__ /D__SSE4_1__ /D__AVX__ /D__AVX2__ /D__FMA4__ /arch:AVX2)
  set(FLAGS_ENABLE_AVX2 /D__SSE2__ /D__SSE3__ /D__SSE4_1__ /D__AVX__ /D__AVX2__ /arch:AVX2)
  set(FLAGS_ENABLE_AVX2128 /D__SSE2__ /D__SSE3__ /D__SSE4_1__ /D__AVX__ /D__AVX2__ /arch:AVX2)
  set(FLAGS_ENABLE_AVX512F /D__SSE2__ /D__SSE3__ /D__SSE4_1__ /D__AVX__ /D__AVX2__ /D__AVX512F__ /arch:AVX2)
  set(FLAGS_ENABLE_AVX512FNOFMA /D__SSE2__ /D__SSE3__ /D__SSE4_1__ /D__AVX__ /D__AVX2__ /D__AVX512F__ /arch:AVX2)
  set(FLAGS_ENABLE_PURECFMA_SCALAR /D__SSE2__ /D__SSE3__ /D__SSE4_1__ /D__AVX__ /D__AVX2__ /arch:AVX2)
  set(FLAGS_WALL "/D_CRT_SECURE_NO_WARNINGS")

  set(FLAGS_NO_ERRNO "")

  set(FLAG_PREPROCESS "/E")
  set(FLAG_PRESERVE_COMMENTS "/C")
  set(FLAG_INCLUDE "/I")
  set(FLAG_DEFINE "/D")
elseif(CMAKE_C_COMPILER_ID MATCHES "Intel")
  set(FLAGS_ENABLE_SSE2 "-msse2")
  set(FLAGS_ENABLE_SSE4 "-msse4.1")
  set(FLAGS_ENABLE_AVX "-mavx")
  set(FLAGS_ENABLE_AVX2 "-march=core-avx2")
  set(FLAGS_ENABLE_AVX2128 "-march=core-avx2")
  set(FLAGS_ENABLE_AVX512F "-xCOMMON-AVX512")
  set(FLAGS_ENABLE_AVX512FNOFMA "-xCOMMON-AVX512")
  set(FLAGS_ENABLE_PURECFMA_SCALAR "-march=core-avx2;-fno-strict-aliasing")
  set(FLAGS_ENABLE_FMA4 "-msse2")  # This is a dummy flag
  set(FLAGS_STRICTMATH "-fp-model strict -Qoption,cpp,--extended_float_type")
  set(FLAGS_FASTMATH "-fp-model fast=2 -Qoption,cpp,--extended_float_type")
  set(FLAGS_NOSTRICTALIASING "-fno-strict-aliasing")
  set(FLAGS_WALL "-fmax-errors=3 -Wall -Wno-unused -Wno-attributes")

  set(FLAGS_NO_ERRNO "")

  set(FLAG_PREPROCESS "-E")
  set(FLAG_PRESERVE_COMMENTS "-C")
  set(FLAG_INCLUDE "-I")
  set(FLAG_DEFINE "-D")
endif()

set(SLEEF_C_FLAGS "${FLAGS_WALL} ${FLAGS_STRICTMATH} ${FLAGS_OTHERS}")
if(CMAKE_C_COMPILER_ID MATCHES "GNU" AND CMAKE_C_COMPILER_VERSION VERSION_GREATER 6.99)
  set(DFT_C_FLAGS "${FLAGS_WALL} ${FLAGS_NOSTRICTALIASING} ${FLAGS_OTHERS}")
else()
  set(DFT_C_FLAGS "${FLAGS_WALL} ${FLAGS_NOSTRICTALIASING} ${FLAGS_FASTMATH} ${FLAGS_OTHERS}")
endif()

if (CMAKE_SYSTEM_PROCESSOR MATCHES "^i.86$" AND CMAKE_C_COMPILER_ID MATCHES "GNU")
  set(SLEEF_C_FLAGS "${SLEEF_C_FLAGS} -msse2 -mfpmath=sse")
  set(DFT_C_FLAGS "${DFT_C_FLAGS} -msse2 -mfpmath=sse -m128bit-long-double")
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "^i.86$" AND CMAKE_C_COMPILER_ID MATCHES "Clang")
  set(SLEEF_C_FLAGS "${SLEEF_C_FLAGS} -msse2 -mfpmath=sse")
  set(DFT_C_FLAGS "${DFT_C_FLAGS} -msse2 -mfpmath=sse")
endif()

if(CYGWIN OR MINGW)
  set(SLEEF_C_FLAGS "${SLEEF_C_FLAGS} -fno-asynchronous-unwind-tables")
  set(DFT_C_FLAGS "${DFT_C_FLAGS} -fno-asynchronous-unwind-tables")
endif()

if(CMAKE_SYSTEM_PROCESSOR MATCHES "aarch64" AND CMAKE_C_COMPILER_ID MATCHES "GNU" AND CMAKE_C_COMPILER_VERSION VERSION_GREATER 9.3 AND CMAKE_C_COMPILER_VERSION VERSION_LESS 10.2)
  set(SLEEF_C_FLAGS "${SLEEF_C_FLAGS} -fno-shrink-wrap -fno-tree-vrp")
  set(DFT_C_FLAGS "${DFT_C_FLAGS} -fno-shrink-wrap -fno-tree-vrp")
endif()

# FEATURE DETECTION

# Long double

option(DISABLE_LONG_DOUBLE "Disable long double" OFF)
option(ENFORCE_LONG_DOUBLE "Build fails if long double is not supported by the compiler" OFF)

if(NOT DISABLE_LONG_DOUBLE)
  CHECK_TYPE_SIZE("long double" LD_SIZE)
  if(LD_SIZE GREATER "9")
    # This is needed to check since internal compiler error occurs with gcc 4.x
    CHECK_C_SOURCE_COMPILES("
  typedef long double vlongdouble __attribute__((vector_size(sizeof(long double)*2)));
  vlongdouble vcast_vl_l(long double d) { return (vlongdouble) { d, d }; }
  int main() { vlongdouble vld = vcast_vl_l(0);
  }" COMPILER_SUPPORTS_LONG_DOUBLE)
  endif()
else()
  message(STATUS "Support for long double disabled by CMake option")
endif()

if (ENFORCE_LONG_DOUBLE AND NOT COMPILER_SUPPORTS_LONG_DOUBLE)
  message(FATAL_ERROR "ENFORCE_LONG_DOUBLE is specified and that feature is disabled or not supported by the compiler")
endif()

# float128

option(DISABLE_FLOAT128 "Disable float128" OFF)
option(ENFORCE_FLOAT128 "Build fails if float128 is not supported by the compiler" OFF)

if(NOT DISABLE_FLOAT128)
  CHECK_C_SOURCE_COMPILES("
  int main() { __float128 r = 1;
  }" COMPILER_SUPPORTS_FLOAT128)
else()
  message(STATUS "Support for float128 disabled by CMake option")
endif()

if (ENFORCE_FLOAT128 AND NOT COMPILER_SUPPORTS_FLOAT128)
  message(FATAL_ERROR "ENFORCE_FLOAT128 is specified and that feature is disabled or not supported by the compiler")
endif()

# SSE2

option(DISABLE_SSE2 "Disable SSE2" OFF)
option(ENFORCE_SSE2 "Build fails if SSE2 is not supported by the compiler" OFF)

if(SLEEF_ARCH_X86 AND NOT DISABLE_SSE2)
  string (REPLACE ";" " " CMAKE_REQUIRED_FLAGS "${FLAGS_ENABLE_SSE2}")
  CHECK_C_SOURCE_COMPILES("
  #if defined(_MSC_VER)
  #include <intrin.h>
  #else
  #include <x86intrin.h>
  #endif
  int main() {
    __m128d r = _mm_mul_pd(_mm_set1_pd(1), _mm_set1_pd(2)); }"
    COMPILER_SUPPORTS_SSE2)
endif()

if (ENFORCE_SSE2 AND NOT COMPILER_SUPPORTS_SSE2)
  message(FATAL_ERROR "ENFORCE_SSE2 is specified and that feature is disabled or not supported by the compiler")
endif()

# SSE 4.1

option(DISABLE_SSE4 "Disable SSE4" OFF)
option(ENFORCE_SSE4 "Build fails if SSE4 is not supported by the compiler" OFF)

if(SLEEF_ARCH_X86 AND NOT DISABLE_SSE4)
  string (REPLACE ";" " " CMAKE_REQUIRED_FLAGS "${FLAGS_ENABLE_SSE4}")
  CHECK_C_SOURCE_COMPILES("
  #if defined(_MSC_VER)
  #include <intrin.h>
  #else
  #include <x86intrin.h>
  #endif
  int main() {
    __m128d r = _mm_floor_sd(_mm_set1_pd(1), _mm_set1_pd(2)); }"
    COMPILER_SUPPORTS_SSE4)
endif()

if (ENFORCE_SSE4 AND NOT COMPILER_SUPPORTS_SSE4)
  message(FATAL_ERROR "ENFORCE_SSE4 is specified and that feature is disabled or not supported by the compiler")
endif()

# AVX

option(ENFORCE_AVX "Disable AVX" OFF)
option(ENFORCE_AVX "Build fails if AVX is not supported by the compiler" OFF)

if(SLEEF_ARCH_X86 AND NOT DISABLE_AVX)
  string (REPLACE ";" " " CMAKE_REQUIRED_FLAGS "${FLAGS_ENABLE_AVX}")
  CHECK_C_SOURCE_COMPILES("
  #if defined(_MSC_VER)
  #include <intrin.h>
  #else
  #include <x86intrin.h>
  #endif
  int main() {
    __m256d r = _mm256_add_pd(_mm256_set1_pd(1), _mm256_set1_pd(2));
  }" COMPILER_SUPPORTS_AVX)
endif()

if (ENFORCE_AVX AND NOT COMPILER_SUPPORTS_AVX)
  message(FATAL_ERROR "ENFORCE_AVX is specified and that feature is disabled or not supported by the compiler")
endif()

# FMA4

option(DISABLE_FMA4 "Disable FMA4" OFF)
option(ENFORCE_FMA4 "Build fails if FMA4 is not supported by the compiler" OFF)

if(SLEEF_ARCH_X86 AND NOT DISABLE_FMA4)
  string (REPLACE ";" " " CMAKE_REQUIRED_FLAGS "${FLAGS_ENABLE_FMA4}")
  CHECK_C_SOURCE_COMPILES("
  #if defined(_MSC_VER)
  #include <intrin.h>
  #else
  #include <x86intrin.h>
  #endif
  int main() {
    __m256d r = _mm256_macc_pd(_mm256_set1_pd(1), _mm256_set1_pd(2), _mm256_set1_pd(3)); }"
    COMPILER_SUPPORTS_FMA4)
endif()

if (ENFORCE_FMA4 AND NOT COMPILER_SUPPORTS_FMA4)
  message(FATAL_ERROR "ENFORCE_FMA4 is specified and that feature is disabled or not supported by the compiler")
endif()

# AVX2

option(DISABLE_AVX2 "Disable AVX2" OFF)
option(ENFORCE_AVX2 "Build fails if AVX2 is not supported by the compiler" OFF)

if(SLEEF_ARCH_X86 AND NOT DISABLE_AVX2)
  string (REPLACE ";" " " CMAKE_REQUIRED_FLAGS "${FLAGS_ENABLE_AVX2}")
  CHECK_C_SOURCE_COMPILES("
  #if defined(_MSC_VER)
  #include <intrin.h>
  #else
  #include <x86intrin.h>
  #endif
  int main() {
    __m256i r = _mm256_abs_epi32(_mm256_set1_epi32(1)); }"
    COMPILER_SUPPORTS_AVX2)

  # AVX2 implies AVX2128
  if(COMPILER_SUPPORTS_AVX2)
    set(COMPILER_SUPPORTS_AVX2128 1)
  endif()
endif()

if (ENFORCE_AVX2 AND NOT COMPILER_SUPPORTS_AVX2)
  message(FATAL_ERROR "ENFORCE_AVX2 is specified and that feature is disabled or not supported by the compiler")
endif()

# AVX512F

option(DISABLE_AVX512F "Disable AVX512F" OFF)
option(ENFORCE_AVX512F "Build fails if AVX512F is not supported by the compiler" OFF)

if(SLEEF_ARCH_X86 AND NOT DISABLE_AVX512F)
  string (REPLACE ";" " " CMAKE_REQUIRED_FLAGS "${FLAGS_ENABLE_AVX512F}")
  CHECK_C_SOURCE_COMPILES("
  #if defined(_MSC_VER)
  #include <intrin.h>
  #else
  #include <x86intrin.h>
  #endif
  __m512 addConstant(__m512 arg) {
    return _mm512_add_ps(arg, _mm512_set1_ps(1.f));
  }
  int main() {
    __m512i a = _mm512_set1_epi32(1);
    __m256i ymm = _mm512_extracti64x4_epi64(a, 0);
    __mmask16 m = _mm512_cmp_epi32_mask(a, a, _MM_CMPINT_EQ);
    __m512i r = _mm512_andnot_si512(a, a); }"
    COMPILER_SUPPORTS_AVX512F)

  if (COMPILER_SUPPORTS_AVX512F)
    set(COMPILER_SUPPORTS_AVX512FNOFMA 1)
  endif()
endif()

if (ENFORCE_AVX512F AND NOT COMPILER_SUPPORTS_AVX512F)
  message(FATAL_ERROR "ENFORCE_AVX512F is specified and that feature is disabled or not supported by the compiler")
endif()

# SVE

option(DISABLE_SVE "Disable SVE" OFF)
option(ENFORCE_SVE "Build fails if SVE is not supported by the compiler" OFF)

if(SLEEF_ARCH_AARCH64 AND NOT DISABLE_SVE)
  string (REPLACE ";" " " CMAKE_REQUIRED_FLAGS "${FLAGS_ENABLE_SVE}")
  CHECK_C_SOURCE_COMPILES("
  #include <arm_sve.h>
  int main() {
    svint32_t r = svdup_n_s32(1); }"
    COMPILER_SUPPORTS_SVE)

  if(COMPILER_SUPPORTS_SVE)
    set(COMPILER_SUPPORTS_SVENOFMA 1)
  endif()
endif()

if (ENFORCE_SVE AND NOT COMPILER_SUPPORTS_SVE)
  message(FATAL_ERROR "ENFORCE_SVE is specified and that feature is disabled or not supported by the compiler")
endif()

# VSX

option(DISABLE_VSX "Disable VSX" OFF)
option(ENFORCE_VSX "Build fails if VSX is not supported by the compiler" OFF)

if(SLEEF_ARCH_PPC64 AND NOT DISABLE_VSX)
  string (REPLACE ";" " " CMAKE_REQUIRED_FLAGS "${FLAGS_ENABLE_VSX}")
  CHECK_C_SOURCE_COMPILES("
  #include <altivec.h>
  #ifndef __LITTLE_ENDIAN__
    #error \"Only VSX(ISA2.07) little-endian mode is supported \"
  #endif
  int main() {
    vector double d;
    vector unsigned char p = {
      4, 5, 6, 7, 0, 1, 2, 3, 12, 13, 14, 15, 8, 9, 10, 11
    };
    d = vec_perm(d, d, p);
  }"
    COMPILER_SUPPORTS_VSX)

  if (COMPILER_SUPPORTS_VSX)
    set(COMPILER_SUPPORTS_VSXNOFMA 1)
  endif()
endif()

if (ENFORCE_VSX AND NOT COMPILER_SUPPORTS_VSX)
  message(FATAL_ERROR "ENFORCE_VSX is specified and that feature is disabled or not supported by the compiler")
endif()

# IBM Z

option(DISABLE_VXE "Disable VXE" OFF)
option(ENFORCE_VXE "Build fails if VXE is not supported by the compiler" OFF)

if(SLEEF_ARCH_S390X AND NOT DISABLE_VXE)
  string (REPLACE ";" " " CMAKE_REQUIRED_FLAGS "${FLAGS_ENABLE_VXE}")
  CHECK_C_SOURCE_COMPILES("
  #include <vecintrin.h>
  int main() {
    __vector float d;
    d = vec_sqrt(d);
  }"
    COMPILER_SUPPORTS_VXE)

  if(COMPILER_SUPPORTS_VXE)
    set(COMPILER_SUPPORTS_VXENOFMA 1)
  endif()
endif()

if (ENFORCE_VXE AND NOT COMPILER_SUPPORTS_VXE)
  message(FATAL_ERROR "ENFORCE_VXE is specified and that feature is disabled or not supported by the compiler")
endif()

#

option(DISABLE_VXE2 "Disable VXE2" OFF)
option(ENFORCE_VXE2 "Build fails if VXE2 is not supported by the compiler" OFF)

if(SLEEF_ARCH_S390X AND NOT DISABLE_VXE2)
  string (REPLACE ";" " " CMAKE_REQUIRED_FLAGS "${FLAGS_ENABLE_VXE2}")
  CHECK_C_SOURCE_COMPILES("
  #include <vecintrin.h>
  int main() {
    __vector float d;
    d = vec_sqrt(d);
  }"
    COMPILER_SUPPORTS_VXE2)

  if(COMPILER_SUPPORTS_VXE2)
    set(COMPILER_SUPPORTS_VXE2NOFMA 1)
  endif()
endif()

if (ENFORCE_VXE2 AND NOT COMPILER_SUPPORTS_VXE2)
  message(FATAL_ERROR "ENFORCE_VXE2 is specified and that feature is disabled or not supported by the compiler")
endif()

# CUDA

option(ENFORCE_CUDA "Build fails if CUDA is not supported" OFF)

if (ENFORCE_CUDA AND NOT CMAKE_CUDA_COMPILER)
  message(FATAL_ERROR "ENFORCE_CUDA is specified and that feature is disabled or not supported by the compiler")
endif()

# OpenMP

option(DISABLE_OPENMP "Disable OPENMP" OFF)
option(ENFORCE_OPENMP "Build fails if OPENMP is not supported by the compiler" OFF)

if(NOT DISABLE_OPENMP)
  find_package(OpenMP)
  # Check if compilation with OpenMP really succeeds
  # It does not succeed on Travis even though find_package(OpenMP) succeeds.
  if(OPENMP_FOUND)
    set (CMAKE_REQUIRED_FLAGS "${OpenMP_C_FLAGS}")
    CHECK_C_SOURCE_COMPILES("
  #include <stdio.h>
  int main() {
  int i;
  #pragma omp parallel for
    for(i=0;i < 10;i++) { putchar(0); }
  }"
      COMPILER_SUPPORTS_OPENMP)
  endif(OPENMP_FOUND)
else()
  message(STATUS "Support for OpenMP disabled by CMake option")
endif()

if (ENFORCE_OPENMP AND NOT COMPILER_SUPPORTS_OPENMP)
  message(FATAL_ERROR "ENFORCE_OPENMP is specified and that feature is disabled or not supported by the compiler")
endif()

# Weak aliases

CHECK_C_SOURCE_COMPILES("
#if defined(__CYGWIN__)
#define EXPORT __stdcall __declspec(dllexport)
#else
#define EXPORT
#endif
  EXPORT int f(int a) {
   return a + 2;
  }
  EXPORT int g(int a) __attribute__((weak, alias(\"f\")));
  int main(void) {
    return g(2);
  }"
  COMPILER_SUPPORTS_WEAK_ALIASES)
if (COMPILER_SUPPORTS_WEAK_ALIASES AND
    NOT CMAKE_SYSTEM_PROCESSOR MATCHES "arm" AND
    NOT CMAKE_SYSTEM_PROCESSOR MATCHES "^(powerpc|ppc)64" AND
    NOT SLEEF_CLANG_ON_WINDOWS AND
    NOT MINGW AND BUILD_GNUABI_LIBS)
  set(ENABLE_GNUABI ${COMPILER_SUPPORTS_WEAK_ALIASES})
endif()

# Built-in math functions

CHECK_C_SOURCE_COMPILES("
  int main(void) {
    double a = __builtin_sqrt (2);
    float  b = __builtin_sqrtf(2);
  }"
  COMPILER_SUPPORTS_BUILTIN_MATH)

# SYS_getrandom

CHECK_C_SOURCE_COMPILES("
#define _GNU_SOURCE
#include <unistd.h>
#include <sys/syscall.h>
#include <linux/random.h>
  int main(void) {
    int i;
    syscall(SYS_getrandom, &i, sizeof(i), 0);
  }"
  COMPILER_SUPPORTS_SYS_GETRANDOM)

#

# Reset used flags
set(CMAKE_REQUIRED_FLAGS)
set(CMAKE_REQUIRED_LIBRARIES)

# Save the default C flags
set(ORG_CMAKE_C_FLAGS ${CMAKE_C_FLAGS})

##

# Check if sde64 command is available

find_program(SDE_COMMAND sde64)
if (NOT SDE_COMMAND)
  find_program(SDE_COMMAND sde)
endif()

# Check if armie command is available

find_program(ARMIE_COMMAND armie)
if (NOT SVE_VECTOR_BITS)
  set(SVE_VECTOR_BITS 128)
endif()

#

find_program(SED_COMMAND sed)

##

if(SLEEF_SHOW_ERROR_LOG)
  if (EXISTS ${PROJECT_BINARY_DIR}/CMakeFiles/CMakeError.log)
    file(READ ${PROJECT_BINARY_DIR}/CMakeFiles/CMakeError.log FILE_CONTENT)
    message("")
    message("=====  Content of CMakeError.log  =====")
    message("")
    message("${FILE_CONTENT}")
    message("")
    message("=======================================")
    message("")
  endif()
endif(SLEEF_SHOW_ERROR_LOG)

if (RUNNING_ON_TRAVIS AND CMAKE_C_COMPILER_ID MATCHES "Clang")
  message(STATUS "Travis bug workaround turned on")
  set(COMPILER_SUPPORTS_OPENMP FALSE)   # Workaround for https://github.com/travis-ci/travis-ci/issues/8613
  set(COMPILER_SUPPORTS_FLOAT128 FALSE) # Compilation on unroll_0_vecextqp.c does not finish on Travis
endif()

if (MSVC OR SLEEF_CLANG_ON_WINDOWS)
  set(COMPILER_SUPPORTS_OPENMP FALSE)   # At this time, OpenMP is not supported on MSVC
endif()

##

# Set common definitions

if (NOT BUILD_SHARED_LIBS)
  set(COMMON_TARGET_DEFINITIONS SLEEF_STATIC_LIBS=1)
  set(SLEEF_STATIC_LIBS 1)
endif()

if (COMPILER_SUPPORTS_WEAK_ALIASES)
  set(COMMON_TARGET_DEFINITIONS ${COMMON_TARGET_DEFINITIONS} ENABLE_ALIAS=1)
endif()

if (COMPILER_SUPPORTS_SYS_GETRANDOM)
  set(COMMON_TARGET_DEFINITIONS ${COMMON_TARGET_DEFINITIONS} ENABLE_SYS_getrandom=1)
endif()
