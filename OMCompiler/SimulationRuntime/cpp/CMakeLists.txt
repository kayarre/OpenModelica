# This script will build and install all required libraries of the C++ Simulation-runtime
#
# The following conditional defines are passed to the c++ compiler:
#     if the Boost_log and Boost_setup_log libraries were found                    -DUSE_BOOST_LOG
#     if the Boost_thread library was found or C++ 11 is available                 -DUSE_THREAD
#     if the UMFPack library of SuiteSparse was found                              -DUSE_UMFPACK
#     if the PAPI library was found                                                -DUSE_PAPI
#     if the Sundials libraries were found                                         -DPMC_USE_SUNDIALS
#     if the runtime is build for the OMC                                          -DOMC_BUILD
#     if the write-output functionality should be handled in parallel              -DUSE_PARALLEL_OUTPUT
#     if ScoreP should be used for performance analysis                            -DUSE_SCOREP
#     if the Intel TBB library was found                                           -DUSE_INTEL_TBB
#     if the Pugi XML library was found                                            -DUSE_PUGI_XML
#     if profiling for the simulation runtime is enabled                           -DRUNTIME_PROFILING
#     if the equation systems of a FMU should be solved with sundials solvers      -DFMU_SUNDIALS
#     if the logger is used                                                        -DUSE_LOGGER
#
# Some of these options can be controlled by passing arguments to CMAKE
#     if write output should be handled in parallel                                -DUSE_PARALLEL_OUTPUT=ON [default: OFF]
#     if ScoreP should be used for performance analysis                            -DUSE_SCOREP=ON [default: OFF]
#     the path to the scorep-installation                                          -DSCOREP_HOME="..." [default: ""]
#     if dgesv library should NOT be used to solve simple equation systems in FMUs -DUSE_DGESV=OFF [default: ON]
#     the path to the dgesv-installation                                           -DDGESV_HOME="..." [default: ""]
#     if the boost libraries should be linked statically                           -DBOOST_STATIC_LINKING=ON [default: OFF]
#     if boost libraries should be linked against absolute path libraries          -DUSE_BOOST_REALPATHS=ON [default: OFF]
#     disable c++11, even if the compiler is able to use it                        -DUSE_CPP_03=ON [default: OFF]
#     if profiling of the simulation runtime should be enabled                     -DRUNTIME_PROFILING=ON [default: OFF]
#     if the equation systems of a FMU should be solved with sundials solvers      -DFMU_SUNDIALS=ON [default: OFF]
#     if the logger should be completely disabled or used                          -DUSE_LOGGER=OFF [default: ON]
#     specify target platform for compilation                                      -DPLATFORM=<dynamic, static or platform triple> [default: "dynamic"]
#     use Klu sparse liner solver                            -DUSE_KLU [default: OFF]
#     Example: "cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo" to create statically linked libraries
#
# The used defines are stored in the SYSTEM_CFLAGS variable, which is passed to the ModelicaConfig.inc and written in the PrecompiledHeader.cmake

if(OPENMODELICA_NEW_CMAKE_BUILD)
  include(cmake_3.14.cmake)
else(OPENMODELICA_NEW_CMAKE_BUILD)

CMAKE_MINIMUM_REQUIRED(VERSION 2.8.9)

IF(UNIX)
IF(APPLE)
# We set the rpath manually, later...
ELSE(APPLE)
# Needed to find Sundials; actually only the Sundials objects need this,
# but there are so many of them
SET(CMAKE_INSTALL_RPATH "$ORIGIN:$ORIGIN/..")
ENDIF(APPLE)
ENDIF(UNIX)

if(NOT PLATFORM OR PLATFORM STREQUAL "dynamic")
  set(BUILD_SHARED_LIBS ON)
elseif(PLATFORM STREQUAL "static")
  set(BUILD_SHARED_LIBS OFF)
else()
  # cross compilation of a subset of the runtime for FMI export
  set(FMU_TARGET PLATFORM)
  set(BUILD_SHARED_LIBS OFF)

  # set cross compiler and force its use
  include(CMakeForceCompiler)
  set(CMAKE_C_COMPILER ${PLATFORM}-gcc)
  cmake_force_c_compiler(${PLATFORM}-gcc GNU)
  set(CMAKE_CXX_COMPILER ${PLATFORM}-g++)
  cmake_force_cxx_compiler(${PLATFORM}-g++ GNU)

  # adapt lib installation dir, like lib/${PLATFORM}/omc/cpp
  execute_process(COMMAND gcc -dumpmachine OUTPUT_VARIABLE MACHINE)
  string(STRIP ${MACHINE} MACHINE)
  string(REPLACE ${MACHINE} ${PLATFORM} LIBINSTALLEXT ${LIBINSTALLEXT})
  message(STATUS "Libs will be installed in ${LIBINSTALLEXT}")
endif()

PROJECT(CppSimulationRuntime)
SET(CMAKE_VERBOSE_MAKEFILE ON)
LIST(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/CMake")
SET(CMAKE_POSITION_INDEPENDENT_CODE ON)

MESSAGE(STATUS "CMake version ${CMAKE_MAJOR_VERSION}.${CMAKE_MINOR_VERSION}.${CMAKE_PATCH_VERSION}")

STRING(TOUPPER ${CMAKE_BUILD_TYPE} CMAKE_BUILD_TYPE_UPPER)

#Set Options
OPTION(USE_PARALLEL_OUTPUT "USE_PARALLEL_OUTPUT" OFF)
OPTION(USE_SCOREP "USE_SCOREP" OFF)
OPTION(USE_DGESV "USE_DGESV" ON)
OPTION(BOOST_STATIC_LINKING "BOOST_STATIC_LINKING" OFF)
OPTION(USE_BOOST_REALPATHS "USE_BOOST_REALPATHS" OFF)
OPTION(RUNTIME_PROFILING "RUNTIME_PROFILING" OFF)
OPTION(FMU_SUNDIALS "FMU_SUNDIALS" OFF)
OPTION(KLU_ROOT "KLU ROOT" "")
OPTION(USE_CPP_03 "USE_CPP_03" OFF)
OPTION(REDUCE_DAE "Use reduce dae method" OFF)

#Set Variables
SET(MODELICAEXTERNALCDIR  "${CMAKE_SOURCE_DIR}/../ModelicaExternalC/C-Sources")

IF(NOT FMU_TARGET)
 IF(MSVC)
  SET(LIBINSTALLEXT "lib/omc/cpp/msvc" CACHE STRINGz "library directory")
 ELSE(MSVC)
  SET(LIBINSTALLEXT "lib/omc/cpp" CACHE STRING "library directory")
ENDIF()
ENDIF(NOT FMU_TARGET)

MESSAGE(STATUS "Using library folder extension" ${LIBINSTALLEXT})

SET(MODELICA_MODEL "ModelicaSystem")
SET(LIBPREFIX "OMCpp")
IF(BUILD_SHARED_LIBS)
  SET(LIBSUFFIX "")
ELSE(BUILD_SHARED_LIBS)
  SET(LIBSUFFIX "_static")
ENDIF(BUILD_SHARED_LIBS)
SET(SolverName ${LIBPREFIX}Solver${LIBSUFFIX})
SET(SystemName ${LIBPREFIX}System${LIBSUFFIX})
SET(OMCFactoryName ${LIBPREFIX}OMCFactory${LIBSUFFIX})
SET(MathName ${LIBPREFIX}Math${LIBSUFFIX})

SET(ModelicaExternalName ModelicaExternalC) # only static version
SET(ModelicaTablesName ModelicaStandardTables) # only static version
SET(ModelicaIOName ModelicaIO) # only static version
SET(ModelicaMatIOName ModelicaMatIO) # only static version
SET(LibZName zlib) # only static version

SET(SimulationSettings ${LIBPREFIX}SimulationSettings${LIBSUFFIX})
SET(SimControllerName ${LIBPREFIX}SimController${LIBSUFFIX})
SET(CVodeName ${LIBPREFIX}CVode${LIBSUFFIX})
SET(ARKodeName ${LIBPREFIX}ARKode${LIBSUFFIX})
SET(IDAName ${LIBPREFIX}IDA${LIBSUFFIX})
SET(PeerName ${LIBPREFIX}Peer${LIBSUFFIX})
SET(DASSLName ${LIBPREFIX}DASSL${LIBSUFFIX})
SET(CppDASSLName ${LIBPREFIX}CppDASSL${LIBSUFFIX})
SET(RTRKName ${LIBPREFIX}RTRK${LIBSUFFIX})
SET(EulerName ${LIBPREFIX}Euler${LIBSUFFIX})
SET(RK12Name ${LIBPREFIX}RK12${LIBSUFFIX})
#SET(kluName ${LIBPREFIX}klu${LIBSUFFIX})
SET(RTEulerName ${LIBPREFIX}RTEuler${LIBSUFFIX})
SET(IdaName ${LIBPREFIX}Ida${LIBSUFFIX})
SET(IdasName ${LIBPREFIX}Idas${LIBSUFFIX})
SET(KinsolName ${LIBPREFIX}Kinsol${LIBSUFFIX})
SET(LinearSolverName ${LIBPREFIX}LinearSolver${LIBSUFFIX})
SET(DgesvSolverName ${LIBPREFIX}DgesvSolver${LIBSUFFIX})
SET(ModelicaName ${LIBPREFIX}Modelica${LIBSUFFIX})
SET(NewtonName ${LIBPREFIX}Newton${LIBSUFFIX})
SET(BroydenName ${LIBPREFIX}Broyden${LIBSUFFIX})
SET(HybrjName ${LIBPREFIX}Hybrj${LIBSUFFIX})
SET(UmfPackName ${LIBPREFIX}UmfPack${LIBSUFFIX})
SET(DataExchangeName ${LIBPREFIX}DataExchange${LIBSUFFIX})
SET(ModelicaUtilitiesName ${LIBPREFIX}ModelicaUtilities${LIBSUFFIX})
SET(ExtensionUtilitiesName ${LIBPREFIX}ExtensionUtilities${LIBSUFFIX})
SET(BasiLibName ${LIBPREFIX}Base${LIBSUFFIX})
SET(ModelicaCompilerName ${LIBPREFIX}ModelicaCompiler${LIBSUFFIX})
SET(FMUName ${LIBPREFIX}FMU${LIBSUFFIX})
SET(DgesvName ${LIBPREFIX}Dgesv) # only static version
SET(ReduceDAEName ${LIBPREFIX}ReduceDAE) # only static version

SET(USE_MICO OFF)
SET(USE_KLU CACHE BOOL OFF)

IF(NOT FMU_TARGET OR FMU_SUNDIALS)
  SET(USE_SUNDIALS ON)
ENDIF(NOT FMU_TARGET OR FMU_SUNDIALS)
SET(OMC_BUILD ON)
SET(SIMSTER_BUILD OFF)

SET(Boost_USE_MULTITHREADED ON)


#IF(MINGW)
#    SET(REDUCE_DAE ON)
#ELSE()
#    SET(REDUCE_DAE OFF)
#ENDIF()

IF(USE_BOOST_REALPATHS)
  MESSAGE(STATUS "Using boost real paths")
  SET(Boost_REALPATH ON)
ELSE(USE_BOOST_REALPATHS)
  MESSAGE(STATUS "Boost real paths disabled")
ENDIF(USE_BOOST_REALPATHS)

# Precompiled Header
IF(MSVC)
  SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} /Zm113")
ENDIF(MSVC)
INCLUDE(${CMAKE_SOURCE_DIR}/PrecompiledHeader.cmake)

# Check C++11
IF(NOT(USE_CPP_03))
  IF(MSVC)
    IF(MSVC_VERSION GREATER 1700)
      SET(COMPILER_SUPPORTS_CXX11 True)
    ELSE(MSVC_VERSION GREATER 1700)
      SET(COMPILER_SUPPORTS_CXX11 False)
    ENDIF(MSVC_VERSION GREATER 1700)
  ELSE(MSVC)
    INCLUDE(CheckCXXCompilerFlag)
    IF(APPLE)
      CHECK_CXX_COMPILER_FLAG("-std=c++11 -stdlib=libc++" COMPILER_SUPPORTS_CXX11)
    ELSE(APPLE)
      IF(FMU_TARGET)
        SET(COMPILER_SUPPORTS_CXX11 True)
      ELSE(FMU_TARGET)
        CHECK_CXX_COMPILER_FLAG("-std=c++11" COMPILER_SUPPORTS_CXX11)
      ENDIF(FMU_TARGET)
    ENDIF(APPLE)
    IF(COMPILER_SUPPORTS_CXX11)
      IF(APPLE)
        SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11 -stdlib=libc++")
        SET(CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE} "${CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE}} -std=c++11 -stdlib=libc++")
        SET(CMAKE_EXE_LINKER_FLAGS "-stdlib=libc++")
        SET(CXX11_FLAGS " -std=c++11 -stdlib=libc++") #used for precompiled header
      ELSE(APPLE)
        SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++11")
        SET(CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE} "${CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE}} -std=c++11")
        SET(CXX11_FLAGS " -std=c++11") #used for precompiled header
      ENDIF(APPLE)
    ELSE()
      SET(COMPILER_SUPPORTS_CXX11 False)
    ENDIF(COMPILER_SUPPORTS_CXX11)
  ENDIF(MSVC)
ELSE()
  SET(COMPILER_SUPPORTS_CXX11 False)
  IF(APPLE)
    SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++03 -stdlib=libc++")
    SET(CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE} "${CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE}} -std=c++03 -stdlib=libc++")
    SET(CMAKE_EXE_LINKER_FLAGS "-stdlib=libc++")
    SET(CXX11_FLAGS " -std=c++03 -stdlib=libc++") #used for precompiled header
  ELSE(APPLE)
    SET(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++03")
    SET(CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE} "${CMAKE_CXX_FLAGS_${CMAKE_BUILD_TYPE}} -std=c++03")
    SET(CXX11_FLAGS " -std=c++03") #used for precompiled header
  ENDIF(APPLE)
ENDIF(NOT(USE_CPP_03))

IF(COMPILER_SUPPORTS_CXX11)
  MESSAGE(STATUS "C++11 support enabled")
ELSE(COMPILER_SUPPORTS_CXX11)
  MESSAGE(STATUS "C++11 support disabled")
  ADD_DEFINITIONS(-DUSE_CPP_03)
ENDIF(COMPILER_SUPPORTS_CXX11)

#Handle static boost linking
IF(NOT BOOST_STATIC_LINKING)
  SET(Boost_USE_STATIC_LIBS OFF)
  SET(Boost_USE_STATIC_RUNTIME OFF)
ELSE(NOT BOOST_STATIC_LINKING)
  SET(Boost_USE_STATIC_LIBS ON)
  SET(Boost_USE_STATIC_RUNTIME ON)
  ADD_DEFINITIONS(-DBOOST_STATIC_LINKING)
ENDIF(NOT BOOST_STATIC_LINKING)

# Handle parallel output
IF(USE_PARALLEL_OUTPUT)
  ADD_DEFINITIONS(-DUSE_PARALLEL_OUTPUT)
  MESSAGE(STATUS "Using parallel output")
ELSE(USE_PARALLEL_OUTPUT)
  MESSAGE(STATUS "Parallel output disabled")
ENDIF(USE_PARALLEL_OUTPUT)

# Handle ScoreP
IF(USE_SCOREP)
  ADD_DEFINITIONS(-DUSE_SCOREP)
  SET(USE_SCOREP_ "ON")
  FIND_PACKAGE(ScoreP)
  SET(SCOREP_INCLUDE_ ${SCOREP_INCLUDE_DIR})
  MESSAGE(STATUS "ScoreP enabled")
  include_directories(${SCOREP_INCLUDE_DIR})
ELSE(USE_SCOREP)
  SET(SCOREP_INCLUDE_ ".")
  SET(USE_SCOREP_ "OFF")
  MESSAGE(STATUS "ScoreP disabled")
ENDIF(USE_SCOREP)

# Handle dgesv
IF(USE_DGESV)
  ADD_DEFINITIONS(-DUSE_DGESV)
  SET(USE_DGESV_ "ON")
  FIND_PACKAGE(Dgesv)
  SET(DGESV_INCLUDE_ ${DGESV_INCLUDE_DIR})
  MESSAGE(STATUS "Dgesv enabled")
ELSE(USE_DGESV)
  SET(DGESV_INCLUDE_ ".")
  SET(USE_DGESV_ "OFF")
  MESSAGE(STATUS "Dgesv disabled")
ENDIF(USE_DGESV)


# Handle runtime profiling
IF(RUNTIME_PROFILING)
  ADD_DEFINITIONS(-DRUNTIME_PROFILING)
  MESSAGE(STATUS "Runtime profiling enabled")
ELSE(RUNTIME_PROFILING)
  MESSAGE(STATUS "Runtime profiling disabled")
ENDIF(RUNTIME_PROFILING)

# Handle FMU sundials support
IF(FMU_SUNDIALS)
  ADD_DEFINITIONS(-DENABLE_SUNDIALS_STATIC)
  SET(USE_FMU_SUNDIALS_ "ON")
  MESSAGE(STATUS "FMU sundials enabled")
ELSE(FMU_SUNDIALS)
  SET(USE_FMU_SUNDIALS_ "OFF")
  MESSAGE(STATUS "FMU sundials disabled")
ENDIF(FMU_SUNDIALS)

# Handle Logger usage
IF(USE_LOGGER)
  ADD_DEFINITIONS(-DUSE_LOGGER)
  SET(USE_LOGGER_ "ON")
  MESSAGE(STATUS "Logger enabled")
ELSE(USE_LOGGER)
  MESSAGE(STATUS "Logger disabled")
  SET(USE_LOGGER_ "OFF")
ENDIF(USE_LOGGER)

# Handle build type
IF(OMC_BUILD)
  ADD_DEFINITIONS(-DOMC_BUILD)
ELSEIF(SIMSTER_BUILD)
  ADD_DEFINITIONS(-DSIMSTER_BUILD)
ENDIF(OMC_BUILD)

# Handle Boost
#  - On windows boost from MSYS are used else the installed versions are used
IF(WIN32)
  MESSAGE(STATUS "MINGW:")
  MESSAGE(STATUS ${IS_MINGW64})

  # Check environment variables
  if(NOT DEFINED ENV{OMDEV})
    message(FATAL_ERROR "Environment variable \"OMDEV\" is not set.")
  endif()
  if(NOT DEFINED ENV{MSYSTEM_PREFIX})
    message(FATAL_ERROR "Environment variable \"MSYSTEM_PREFIX\" is not set.")
  endif()
  string(REPLACE "\\" "/" OMDEV_ESCAPED "$ENV{OMDEV}")
  string(REPLACE "\\" "/" MSYSTEM_PREFIX_ESCAPED "$ENV{MSYSTEM_PREFIX}")

  IF(IS_MINGW64)
    SET(BOOST_ROOT ${MSYSTEM_PREFIX_ESCAPED})
  ELSEIF(IS_MINGW32)
    MESSAGE(FATAL_ERROR "32-bit version not supported")
  ELSEIF(MSVC)
    IF(MSVC_VERSION GREATER 1700)
      SET(BOOST_ROOT ${OMDEV_ESCAPED}/lib/3rdParty/boost-1_59/)
    ELSE(MSVC_VERSION GREATER 1700)
      SET(BOOST_ROOT ${OMDEV_ESCAPED}/lib/3rdParty/boost-1_55/)
    ENDIF(MSVC_VERSION GREATER 1700)
  ELSE()
    MESSAGE(FATAL_ERROR "CPPRuntime does not know how to handle boost in this configuration")
  ENDIF()
  MESSAGE(STATUS "Boost root for cpp runtime: ${BOOST_ROOT}")

  # Disable Optimization for RelWithDebInfo on Windows
  IF(MSVC)
    STRING(REPLACE "/O2" "/Od" CMAKE_CXX_FLAGS_RELWITHDEBINFO ${CMAKE_CXX_FLAGS_RELWITHDEBINFO})
  ELSE(MSVC)
    STRING(REPLACE "/O2" "/O0" CMAKE_CXX_FLAGS_RELWITHDEBINFO ${CMAKE_CXX_FLAGS_RELWITHDEBINFO})
    STRING(REPLACE "/O2" "/O0" CMAKE_CXX_FLAGS_DEBUG ${CMAKE_CXX_FLAGS_DEBUG})
  ENDIF(MSVC)

  #set mico paths
  IF(USE_MICO)
    SET(MICO_LIB_HOME ${OMDEV_ESCAPED}/lib/mico-msys-mingw/)
    SET(MICO_INCLUDE_HOME  ${OMDEV_ESCAPED}/include/mico-msys-mingw/)
  endif()

  SET(INSTALL_OMDEV_LIBS OFF)
ENDIF(WIN32)

# Find OpenMP
FIND_PACKAGE(OpenMP)
IF(OPENMP_FOUND)
  MESSAGE(STATUS "OPENMP enabled")
  SET(USE_OPENMP_ "ON")
ELSE(OPENMP_FOUND)
  MESSAGE(STATUS "OPENMP disabled")
  SET(USE_OPENMP_ "OFF")
  SET(OpenMP_CXX_FLAGS "")
ENDIF(OPENMP_FOUND)

# Find MPI
FIND_PACKAGE(MPI)
IF(MPI_FOUND)
  MESSAGE(STATUS "MPI enabled")
  SET(USE_MPI_ "ON")
ELSE(MPI_FOUND)
  MESSAGE(STATUS "MPI disabled")
  SET(USE_MPI_ "OFF")
ENDIF(MPI_FOUND)

if(NOT FMU_TARGET)
  # Find CMinpack
  # Note: Visual Studio libs are located in install/msvc, libs for gcc are directly in install
  IF(MSVC)
    SET(CMinpack_Path "${CMAKE_SOURCE_DIR}/../../3rdParty/CMinpack/install_msvc")
  ELSE(MSVC)
    SET(CMinpack_Path "${CMAKE_SOURCE_DIR}/../../3rdParty/CMinpack/build")
  ENDIF(MSVC)

  FIND_PATH(CMINPACK_INCLUDE_DIR cminpack.h
            HINTS ${CMinpack_Path}
            PATH_SUFFIXES include include/cminpack include/cminpack-1 ..)

  FIND_LIBRARY(CMINPACK_LIBRARY
               NAMES cminpack
               HINTS ${CMinpack_Path}
               PATH_SUFFIXES lib lib64)

  INCLUDE_DIRECTORIES(${CMINPACK_INCLUDE_DIR})
endif(NOT FMU_TARGET)

# Find Intel TBB
FIND_PACKAGE(TBB)
IF(TBB_FOUND)
  ADD_DEFINITIONS(-DUSE_INTEL_TBB)
  MESSAGE (STATUS "Using Intel TBB")
ELSE(TBB_FOUND)
  MESSAGE (STATUS "Intel TBB disabled")
ENDIF(TBB_FOUND)

# Find Pugi XML
FIND_PACKAGE(PugiXML)
IF(PUGIXML_FOUND)
  ADD_DEFINITIONS(-DUSE_PUGI_XML)
  MESSAGE (STATUS "Using Pugi XML")
ELSE(PUGIXML_FOUND)
  MESSAGE (STATUS "Pugi XML disabled")
ENDIF(PUGIXML_FOUND)

# Find PAPI
FIND_LIBRARY(PAPI_LIBRARIES NAMES libpapi.a papi)
FIND_PATH(PAPI_INCLUDE_DIRS NAMES papi.h)
INCLUDE(FindPackageHandleStandardArgs)
FIND_PACKAGE_HANDLE_STANDARD_ARGS(PAPI DEFAULT_MSG PAPI_LIBRARIES PAPI_INCLUDE_DIRS)
IF(PAPI_FOUND)
  ADD_DEFINITIONS(-DUSE_PAPI)
  SET(USE_PAPI_ "ON")
ELSE(PAPI_FOUND)
  SET(USE_PAPI_ "OFF")
ENDIF(PAPI_FOUND)

# Find Boost
# If MSVC, we do not want to use MSYS/MingGW installed boost's CMake config files for locating Boost
# We have a manually provided boost already specified using BOOST_ROOT.
# This is essentialy saying we do not want any help from boost itself in finding its libraries and setup.
# Let CMake do it alone the old way by just finding the files it knows.
IF(MSVC)
  SET(Boost_NO_BOOST_CMAKE ON)
ENDIF(MSVC)
#  - The optional boost libraries must be searched separately, otherwise no library is found if just one is missing.
#  - Additionaly the Boost_LIBRARIES variable is overwritten each time find_package(Boost ...) is called, thus it must be rescued
FIND_PACKAGE(Boost COMPONENTS log log_setup)

# Deactivate threading stuff in MSVC release mode, because this produces linker errors to boost::exception_ptr
IF(MSVC AND (CMAKE_BUILD_TYPE_UPPER STREQUAL "RELEASE"))
  SET(Boost_THREAD_LIBRARY_RELEASE "NOT_FOUND")
  SET(Boost_THREAD_LIBRARY_DEBUG "NOT_FOUND")
  MESSAGE(STATUS "Boost threading disabled because othwerwise the MSVC build produces linker errors in release mode.")
ELSE(MSVC AND (CMAKE_BUILD_TYPE_UPPER STREQUAL "RELEASE"))
  FIND_PACKAGE(Boost COMPONENTS thread atomic)
ENDIF(MSVC AND (CMAKE_BUILD_TYPE_UPPER STREQUAL "RELEASE"))

IF(NOT(COMPILER_SUPPORTS_CXX11))
  SET(Boost_LIBRARIES_TMP ${Boost_LIBRARIES_TMP} ${Boost_LIBRARIES})
  FIND_PACKAGE(Threads)
  IF(Boost_THREAD_FOUND AND Boost_ATOMIC_FOUND)
    ADD_DEFINITIONS(-DUSE_THREAD)
    MESSAGE(STATUS "Using boost thread")
  ELSE(Boost_THREAD_FOUND AND Boost_ATOMIC_FOUND)
    MESSAGE(STATUS "Boost thread disabled")
  ENDIF(Boost_THREAD_FOUND AND Boost_ATOMIC_FOUND)
ELSEIF(NOT FMU_TARGET)
  ADD_DEFINITIONS(-DUSE_THREAD)
  MESSAGE(STATUS "Boost thread disabled because of available C++11 support")
ENDIF(NOT(COMPILER_SUPPORTS_CXX11))

IF(NOT FMU_TARGET)
  FIND_PACKAGE(Boost REQUIRED COMPONENTS filesystem serialization program_options)
ELSE(NOT FMU_TARGET)
  FIND_PACKAGE(Boost COMPONENTS filesystem serialization program_options)
ENDIF(NOT FMU_TARGET)

# Use old C++ ABI for cross compilation of FMUs
# because libstdc++ might not be upgraded yet
# (e.g. i686-w64-mingw32 under Ubuntu 16.04 LTS).
# Note: the default ABI is used for simulators that link with boost libs.
IF(FMU_TARGET AND NOT MSVC)
  ADD_DEFINITIONS(-D_GLIBCXX_USE_CXX11_ABI=0)
ENDIF(FMU_TARGET AND NOT MSVC)

IF(WIN32)
  SET(CPPTHREADS_LIBRARY)
  SET(CPPTHREADS_LIBRARY_FLAG)
ELSE(WIN32)
  find_package(Threads REQUIRED)
  SET(CPPTHREADS_LIBRARY Threads::Threads)
  SET(CPPTHREADS_LIBRARY_FLAG ${CMAKE_THREAD_LIBS_INIT})
ENDIF(WIN32)

SET(Boost_LIBRARIES_TMP ${Boost_LIBRARIES_TMP} ${Boost_LIBRARIES})
SET(Boost_LIBRARIES ${Boost_LIBRARIES_TMP})
MESSAGE(STATUS "Boost Libraries for cpp runtime")
MESSAGE(STATUS ${Boost_LIBRARIES})

# Find Lapack and Blas
IF(MSVC)
  #workaround  because cmake does not find the lapack libraries for Visual Studio 10
  SET(LAPACK_MSVC_10  ${OMDEV_ESCAPED}/lib/3rdParty/Lapack/Lib/lapack_win32.lib )
  SET(BLAS_MSVC_10 ${OMDEV_ESCAPED}/lib/3rdParty/Lapack/Lib/blas_win32.lib )
  SET(LAPACK_LIBRARIES ${LAPACK_MSVC_10} ${BLAS_MSVC_10} )
ELSE()
  FIND_PACKAGE(BLAS)
  FIND_PACKAGE(LAPACK)
  if(LAPACK_FOUND AND BLAS_FOUND)
    MESSAGE(STATUS "LAPACK and BLAS found")
  else()
    message(FATAL_ERROR "Couldn't find LAPACK and BLAS.")
  endif()
ENDIF(MSVC)

MESSAGE(STATUS "LAPACK Libraries: ${LAPACK_LIBRARIES}")

MESSAGE(STATUS "use reduce dae method: ${REDUCE_DAE} - "  )
IF(REDUCE_DAE)
 MESSAGE(STATUS "using reduce dae method")
 ADD_DEFINITIONS("-DUSE_REDUCE_DAE")
 SET(OMCCAPI_INLCUDE_HOME  omcCAPI/include/)
 SET(OMCCAPI_LIBRARY_RELEASE_HOME   Build_CAPI/)
 FIND_LIBRARY(OMCCAPI_LIB "OMCDLL" NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH PATHS ${OMCCAPI_LIBRARY_RELEASE_HOME} )
 IF(NOT OMCCAPI_LIB)
     MESSAGE(FATAL_ERROR "Could not find omc c- api library!")
 ENDIF()
 MESSAGE(STATUS "omc c api include:")
 MESSAGE(STATUS "${OMCCAPI_INLCUDE_HOME}")
 MESSAGE(STATUS "omc c api library path:")
 MESSAGE(STATUS "${OMCCAPI_LIBRARY_RELEASE_HOME}")
 FIND_PATH(OMCCAPI_INCLUDE_DIR OMC.h PATHS ${OMCCAPI_INLCUDE_HOME})
 IF (NOT OMCCAPI_INCLUDE_DIR)
   MESSAGE(FATAL_ERROR "Could not find omc c- api")
 ENDIF(NOT OMCCAPI_INCLUDE_DIR)
 MESSAGE(STATUS "omc c api library:")
 MESSAGE(STATUS "${OMCCAPI_LIB}")
ENDIF(REDUCE_DAE)

# Find Sundials solvers
IF(USE_SUNDIALS)
  #set sundials solvers include and library directories
  IF(MSVC)
    SET(SUNDIALS_INLCUDE_HOME  "${CMAKE_SOURCE_DIR}/../../3rdParty/sundials-5.4.0/build_msvc/include/sundials")
    SET(SUNDIALS_LIBRARY_RELEASE_HOME "${CMAKE_SOURCE_DIR}/../../3rdParty/sundials-5.4.0/build_msvc/lib/")
  ELSE(MSVC)
    SET(SUNDIALS_INLCUDE_HOME  ${CMAKE_INSTALL_PREFIX}/include/omc/sundials)
    SET(SUNDIALS_LIBRARY_RELEASE_HOME   ${CMAKE_INSTALL_PREFIX}/${LIBINSTALLEXT}/..)
  ENDIF(MSVC)

  MESSAGE(STATUS "Sundials include:")
  MESSAGE(STATUS "${SUNDIALS_INLCUDE_HOME}")
  MESSAGE(STATUS "Sundials library:")
  MESSAGE(STATUS "${SUNDIALS_LIBRARY_RELEASE_HOME}")


  SET(SUNDIALS_INCLUDE_DIR "${SUNDIALS_INLCUDE_HOME}")
  IF (NOT EXISTS "${SUNDIALS_INLCUDE_HOME}/cvode/cvode.h")
    MESSAGE(FATAL_ERROR "Could not find Sundials; compile omc first")
  ENDIF()
  INCLUDE_DIRECTORIES(${SUNDIALS_INCLUDE_DIR})
  # Extract the version number from sundials_config.h
  SET(SUNDIALS_CONFIG_FILE "${SUNDIALS_INCLUDE_DIR}/sundials/sundials_config.h")
  IF(NOT EXISTS "${SUNDIALS_CONFIG_FILE}")
    MESSAGE(FATAL_ERROR "Could not find sundials_config.h")
  ENDIF()

  FILE(READ "${SUNDIALS_CONFIG_FILE}" SUNDIALS_CONFIG_FILE_CONTENT)
  MESSAGE(STATUS "Found config file ${SUNDIALS_CONFIG_FILE}")
  STRING(REGEX MATCH "#define SUNDIALS_VERSION .([0-9]+)\\.([0-9]+)\\.([0-9]+)." _ ${SUNDIALS_CONFIG_FILE_CONTENT})
  IF(DEFINED CMAKE_MATCH_1 AND DEFINED CMAKE_MATCH_2 AND DEFINED CMAKE_MATCH_3)
    SET(SUNDIALS_MAJOR_VERSION "${CMAKE_MATCH_1}")
    SET(SUNDIALS_MINOR_VERSION "${CMAKE_MATCH_2}")
    SET(SUNDIALS_PATCH_VERSION "${CMAKE_MATCH_3}")

    ADD_DEFINITIONS("-DSUNDIALS_MAJOR_VERSION=${SUNDIALS_MAJOR_VERSION}")
    ADD_DEFINITIONS("-DSUNDIALS_MINOR_VERSION=${SUNDIALS_MINOR_VERSION}")
  ELSE()
    MESSAGE(FATAL_ERROR "Could not determine sundials version")
  ENDIF()
  MESSAGE(STATUS "Using sundials ${SUNDIALS_MAJOR_VERSION}.${SUNDIALS_MINOR_VERSION}.${SUNDIALS_PATCH_VERSION}")

  FIND_LIBRARY(SUNDIALS_NVECSERIAL_LIB "sundials_nvecserial" NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH PATHS ${SUNDIALS_LIBRARY_RELEASE_HOME} $ENV{SUNDIALS_ROOT}/lib)
  IF(NOT SUNDIALS_NVECSERIAL_LIB)
    MESSAGE(FATAL_ERROR "Could not find libsundials_nvecserial!")
  ENDIF()
  GET_FILENAME_COMPONENT(SUNDIALS_LIBS "${SUNDIALS_NVECSERIAL_LIB}" PATH)

  FIND_LIBRARY(SUNDIALS_CVODES_LIB "sundials_cvodes" NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH  PATHS ${SUNDIALS_LIBRARY_RELEASE_HOME}  $ENV{SUNDIALS_ROOT}/lib)
  IF(NOT SUNDIALS_CVODES_LIB)
    MESSAGE(FATAL_ERROR "Could not find libsundials_cvodes!")
  ENDIF()

  FIND_LIBRARY(SUNDIALS_CVODE_LIB "sundials_cvode" NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH  PATHS ${SUNDIALS_LIBRARY_RELEASE_HOME}  $ENV{SUNDIALS_ROOT}/lib)
  IF(NOT SUNDIALS_CVODES_LIB)
    MESSAGE(FATAL_ERROR "Could not find libsundials_cvodes!")
  ENDIF()

#  FIND_LIBRARY(SUNDIALS_ARKODE_LIB "sundials_arkode" PATHS ${SUNDIALS_LIBRARY_RELEASE_HOME}  $ENV{SUNDIALS_ROOT}/lib)
#  IF(NOT SUNDIALS_ARKODE_LIB)
#    MESSAGE(FATAL_ERROR "Could not find libsundials_ARKODE!")
#  ENDIF()

  FIND_LIBRARY(SUNDIALS_IDA_LIB "sundials_idas" NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH  PATHS ${SUNDIALS_LIBRARY_RELEASE_HOME}  $ENV{SUNDIALS_ROOT}/lib)
  IF(NOT SUNDIALS_IDA_LIB)
    MESSAGE(FATAL_ERROR "Could not find libsundials_ida!")
  ENDIF()

  FIND_LIBRARY(SUNDIALS_KINSOL_LIB "sundials_kinsol" NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH  PATHS ${SUNDIALS_LIBRARY_RELEASE_HOME} $ENV{SUNDIALS_ROOT}/lib)
  IF(NOT SUNDIALS_KINSOL_LIB)
    MESSAGE(FATAL_ERROR "Could not find libsundials_kinsol!")
  ENDIF()
  SET(SUNDIALS_LIBRARIES ${SUNDIALS_NVECSERIAL_LIB} ${SUNDIALS_CVODE_LIB} ${SUNDIALS_CVODES_LIB} ${SUNDIALS_IDA_LIB} ${SUNDIALS_KINSOL_LIB} ${SUNDIALS_ARKODE_LIB})

  MESSAGE(STATUS "Sundials Libraries:")
  MESSAGE(STATUS "${SUNDIALS_LIBRARIES}")
  ADD_DEFINITIONS(-DPMC_USE_SUNDIALS)

  # On Windows we need to install those libraries along with the SimManager
  IF(WIN32)
    INSTALL(FILES ${SUNDIALS_LIBRARIES} DESTINATION bin)
  ENDIF(WIN32)
ENDIF(USE_SUNDIALS)

# Find Klu solvers
IF(USE_KLU)
  #set klu solvers include and library directories
  IF(MSVC)
    SET(Klu_Path "${CMAKE_SOURCE_DIR}/../../3rdParty/SuiteSparse/install_msvc")

#            SET(KLU_INLCUDE_HOME  ${Klu_Path}/include/omc/c/suitesparse)
#    SET(KLU_LIBRARY_RELEASE_HOME  ${Klu_Path}/lib/omc)
  ELSE(MSVC)
    SET(Klu_Path "${CMAKE_SOURCE_DIR}/../../3rdParty/SuiteSparse")
    #SET(Klu_Path ${CMAKE_SOURCE_DIR}/../../../build/include/omc/c/suitesparse) #"${CMAKE_SOURCE_DIR}/../../3rdParty/SuiteSparse")
  ENDIF(MSVC)

  IF(MSVC)
  SET(KLU_INLCUDE_HOME ${Klu_Path}/include/omc/c/suitesparse) #${Klu_Path}/KLU/Include)
  SET(KLU_LIBRARY_RELEASE_HOME ${Klu_Path}/lib/omc) #${Klu_Path}/build)
  ELSE(MSVC)
  SET(KLU_INLCUDE_HOME ${Klu_Path}/KLU/Include) #${Klu_Path}/KLU/Include)
  SET(KLU_LIBRARY_RELEASE_HOME ${Klu_Path}/build) #${Klu_Path}/build)
  ENDIF(MSVC)

  MESSAGE(STATUS "Klu include:")
  MESSAGE(STATUS "${KLU_INLCUDE_HOME}")
  MESSAGE(STATUS "Klu library:")
  MESSAGE(STATUS "${KLU_LIBRARY_RELEASE_HOME}")

  FIND_PATH(KLU_INCLUDE_DIR klu.h PATHS ${KLU_INLCUDE_HOME} $ENV{KLU_ROOT}/include)
  IF (NOT KLU_INCLUDE_DIR)
    MESSAGE(FATAL_ERROR "Could not find Klu, specify environment variable KLU_ROOT")
  ELSE(NOT KLU_INCLUDE_DIR)
    INCLUDE_DIRECTORIES(${KLU_INCLUDE_DIR})
  ENDIF(NOT KLU_INCLUDE_DIR)

  FIND_LIBRARY(KLU_LIB "klu" NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH PATHS ${KLU_LIBRARY_RELEASE_HOME} $ENV{SUNDIALS_ROOT}/lib)
  IF(NOT KLU_LIB)
    MESSAGE(FATAL_ERROR "Could not find klu library!")
  ENDIF()

  FIND_LIBRARY(AMD_LIB "amd" NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH PATHS ${KLU_LIBRARY_RELEASE_HOME} $ENV{SUNDIALS_ROOT}/lib)
  IF(NOT AMD_LIB)
    MESSAGE(FATAL_ERROR "Could not find klu amd library!")
  ENDIF()

  FIND_LIBRARY(BTF "btf" NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH PATHS ${KLU_LIBRARY_RELEASE_HOME} $ENV{SUNDIALS_ROOT}/lib)
  IF(NOT BTF)
    MESSAGE(FATAL_ERROR "Could not find klu btf library!")
  ENDIF()

   FIND_LIBRARY(COLAMD "colamd" NO_DEFAULT_PATH NO_SYSTEM_ENVIRONMENT_PATH PATHS ${KLU_LIBRARY_RELEASE_HOME} $ENV{SUNDIALS_ROOT}/lib)
  IF(NOT COLAMD)
    MESSAGE(FATAL_ERROR "Could not find klu colamd library!")
  ENDIF()

  SET(KLU_LIBRARIES ${KLU_LIB} ${AMD_LIB} ${BTF} ${COLAMD})

  MESSAGE(STATUS "Klu Libraries:")
  MESSAGE(STATUS "${KLU_LIBRARIES}")
  ADD_DEFINITIONS(-Dklu)
ENDIF(USE_KLU)



#Handle umfpack
#FIND_PACKAGE(SuiteSparse)
IF(SUITESPARSE_UMFPACK_FOUND)
  MESSAGE(STATUS "Using UmfPack include path: ${SUITESPARSE_UMFPACK_INCLUDE_DIR}")
  INCLUDE_DIRECTORIES(${SUITESPARSE_UMFPACK_INCLUDE_DIR})
  #ADD_DEFINITIONS(-DUSE_UMFPACK)
  SET(SUITESPARSE_INCLUDE ${SUITESPARSE_UMFPACK_INCLUDE_DIR})
  SET(UMFPACK_LIB ${SUITESPARSE_UMFPACK_LIBRARIES})
ELSE(SUITESPARSE_UMFPACK_FOUND)
  MESSAGE(STATUS "UmfPack disabled")
  SET(SUITESPARSE_INCLUDE ".")
  SET(UMFPACK_LIB "")
ENDIF(SUITESPARSE_UMFPACK_FOUND)


#Handle Mico corba
IF(USE_MICO)
  FIND_LIBRARY(MICO_LIBRARY  mico2313
    PATHS ${MICO_LIB_HOME}) #you can add additional search paths for mico library
  FIND_PATH(MICO_INCLUDE_DIR CORBA.h
     ${MICO_INCLUDE_HOME}) #you can add additional search paths for mico include
  MESSAGE(STATUS ${MICO_LIBRARY})
  MESSAGE(STATUS ${MICO_INCLUDE_DIR})
ENDIF(USE_MICO)


#Write the defines into the ADDITIONAL_DEFINES variable
# GET_DIRECTORY_PROPERTY(ADDITIONAL_DEFINES DEFINITIONS)
# message(STATUS "Generated compile definitions: ${ADDITIONAL_DEFINES}")
SET(Boost_Library_folder  ${Boost_LIBRARY_DIRS} CACHE STRING "library directory" )
link_directories ( ${Boost_LIBRARY_DIRS} )


include_directories (${Boost_INCLUDE_DIR})
include_directories ("${PROJECT_SOURCE_DIR}")
include_directories ("${PROJECT_BINARY_DIR}")

message(STATUS "Boost dirs '${Boost_LIBRARY_DIRS}', '${Boost_INCLUDE_DIR}'")

if(UNIX AND Boost_INCLUDE_DIR STREQUAL "/usr/include")
  # symlink boost includes outside platform specific /usr/include
  execute_process(COMMAND ln -sf /usr/include/boost ./)
endif(UNIX AND Boost_INCLUDE_DIR STREQUAL "/usr/include")

#set (CMAKE_CXX_FLAGS "-Winvalid-pch")
#build of simulation.core
include_directories ("Include")
#include_directories ("Solver/KLU")

#add_subdirectory (Solver/KLU)
# Needs to be included before Core/Modelica othwise environment variables are not set.
IF(USE_DGESV)
  ADD_SUBDIRECTORY(Solver/Dgesv)

  IF(DGESV_FOUND)
    GET_TARGET_PROPERTY(libDgesv ${DgesvName} LOCATION)
    GET_FILENAME_COMPONENT(libDgesvName ${libDgesv} NAME)
  ENDIF()
ENDIF(USE_DGESV)

# add base definitions for generating a target
# adrpo: make sure this is first for the precompiled headers!
add_subdirectory(Core/Modelica)

# add system default implemention project
add_subdirectory(Core/System)
# add solver default implemention project
add_subdirectory(Core/Solver)

add_subdirectory(Core/Math)
add_subdirectory(Core/Utils/Modelica)
add_subdirectory(Core/Utils/extension)
add_subdirectory(Core/ModelicaExternalC)

# add projects for generating a simulator
# (add them to FMU_TARGET as well due to include dependencies)
#if(NOT FMU_TARGET)
  add_subdirectory(SimCoreFactory/OMCFactory)
  add_subdirectory(Core/DataExchange)
  add_subdirectory(Core/SimulationSettings)
  add_subdirectory(Core/SimController)
  #add_subdirectory(ModelicaCompiler)
#endif(NOT FMU_TARGET)

# add Newton solver
add_subdirectory(Solver/Newton)

if(NOT FMU_TARGET)
  # add more algebraic loop solvers
  add_subdirectory(Solver/Broyden)
  add_subdirectory(Solver/Hybrj)
  add_subdirectory(Solver/UmfPack)
  add_subdirectory(Solver/Peer)
  add_subdirectory(Solver/LinearSolver)
  # add simulation solvers
  find_package(Cdaskr)
  if(CDASKR_FOUND)
    add_subdirectory(Solver/DASSL)
    message(STATUS "DASSL enabled")
  else(CDASKR_FOUND)
    message(STATUS "DASSL disabled because Cdaskr not found")
  endif(CDASKR_FOUND)
  add_subdirectory(Solver/Euler)
  add_subdirectory(Solver/RK12)
  add_subdirectory(Solver/RTEuler)
  if(OPENMP_FOUND)
    if(SUITESPARSE_UMFPACK_FOUND)
      message(STATUS "CppDassl enabled")
      add_subdirectory (Solver/CppDASSL)
    else(SUITESPARSE_UMFPACK_FOUND)
      message(STATUS "CppDassl disabled, because of missing UMFPACK support")
    endif(SUITESPARSE_UMFPACK_FOUND)
  else(OPENMP_FOUND)
    message(STATUS "CppDassl disabled, because of missing OpenMP support")
  endif(OPENMP_FOUND)
  ##add_subdirectory(Solver/RTRK)
endif(NOT FMU_TARGET)

add_subdirectory(FMU)

if(REDUCE_DAE)
  add_subdirectory(Core/ReduceDAE)
endif()



IF(USE_SUNDIALS)
  #add  Cvode solver project
  ADD_SUBDIRECTORY (Solver/CVode)
  #add_subdirectory (Solver/ARKode)
  ADD_SUBDIRECTORY(Solver/IDA)
  ADD_SUBDIRECTORY(Solver/Kinsol)
  #add  Idas solver project
  ##add_subdirectory (Solver/Idas/Implementation)
  ##add_subdirectory (Solver/Ida/Implementation)
  GET_TARGET_PROPERTY(libCVode ${CVodeName} LOCATION)
  GET_TARGET_PROPERTY(libARKode ${ARKodeName} LOCATION)
  GET_FILENAME_COMPONENT(libCVodeName ${libCVode} NAME)
  GET_FILENAME_COMPONENT(libARKodeName ${libARKode} NAME)

  GET_TARGET_PROPERTY(libIDA ${IDAName} LOCATION)
  GET_FILENAME_COMPONENT(libIDAName ${libIDA} NAME)

  GET_TARGET_PROPERTY(libKinsol ${KinsolName} LOCATION)
  GET_FILENAME_COMPONENT(libKinsolName ${libKinsol} NAME)

  #GET_TARGET_PROPERTY(libIdas ${IdasName} LOCATION)
  #GET_FILENAME_COMPONENT(libIdasName ${libIdas} NAME)
  #GET_TARGET_PROPERTY(libIda ${IdaName} LOCATION)
  #GET_FILENAME_COMPONENT(libIdaName ${libIda} NAME)

  #set (IDAS_LIB ${libIdasName})
  SET(CVODE_LIB ${libCVodeName})
  SET(ARKODE_LIB ${libARKodeName})
  SET(IDA_LIB ${libIDAName})
  SET(KINSOL_LIB ${libKinsolName})
  #set(IDA_LIB ${libIdaName})
ENDIF(USE_SUNDIALS)


GET_TARGET_PROPERTY(libLinearSolver ${LinearSolverName} LOCATION)
GET_FILENAME_COMPONENT(libLinearSolverName ${libLinearSolver} NAME)

GET_TARGET_PROPERTY(libDgesvSolver ${DgesvSolverName} LOCATION)
GET_FILENAME_COMPONENT(libDgesvSolverName ${libDgesvSolver} NAME)

GET_TARGET_PROPERTY(libPeer ${PeerName} LOCATION)
GET_FILENAME_COMPONENT(libPeerName ${libPeer} NAME)

IF(CDASKR_FOUND)
  GET_TARGET_PROPERTY(libDASSL ${DASSLName} LOCATION)
  GET_FILENAME_COMPONENT(libDASSLName ${libDASSL} NAME)
ENDIF(CDASKR_FOUND)

IF(OPENMP_FOUND)
  GET_TARGET_PROPERTY(libCppDASSL ${CppDASSLName} LOCATION)
  GET_FILENAME_COMPONENT(libCppDASSLName ${libCppDASSL} NAME)
ENDIF(OPENMP_FOUND)

GET_TARGET_PROPERTY(libRTRK ${RTRKName} LOCATION)
GET_FILENAME_COMPONENT(libRTRKName ${libRTRK} NAME)

GET_TARGET_PROPERTY(libNewton ${NewtonName} LOCATION)
GET_FILENAME_COMPONENT(libNewtonName ${libNewton} NAME)

GET_TARGET_PROPERTY(libBroyden ${BroydenName} LOCATION)
GET_FILENAME_COMPONENT(libBroydenName ${libBroyden} NAME)

GET_TARGET_PROPERTY(libUmfPack ${UmfPackName} LOCATION)
GET_FILENAME_COMPONENT(libUmfPackName ${libUmfPack} NAME)

GET_TARGET_PROPERTY(libEuler ${EulerName} LOCATION)
GET_FILENAME_COMPONENT(libEulerName ${libEuler} NAME)

GET_TARGET_PROPERTY(libRK12 ${RK12Name} LOCATION)
GET_FILENAME_COMPONENT(libRK12Name ${libRK12} NAME)

#GET_TARGET_PROPERTY(libKlu ${kluName} LOCATION)
#GET_FILENAME_COMPONENT(libKluName ${libKlu} NAME)

GET_TARGET_PROPERTY(libRTEuler ${RTEulerName} LOCATION)
GET_FILENAME_COMPONENT(libRTEulerName ${libRTEuler} NAME)

GET_TARGET_PROPERTY(libHybrj ${HybrjName} LOCATION)
GET_FILENAME_COMPONENT(libHybrjName ${libHybrj} NAME)

GET_TARGET_PROPERTY(libSetFactory ${SimulationSettings} LOCATION)
GET_FILENAME_COMPONENT(libSetFactoryName ${libSetFactory} NAME)

GET_TARGET_PROPERTY(libModelica ${ModelicaName} LOCATION)
GET_FILENAME_COMPONENT(libModelicaName ${libModelica} NAME)

GET_TARGET_PROPERTY(libSystem ${SystemName} LOCATION)
GET_FILENAME_COMPONENT(libSystemName ${libSystem} NAME)

GET_TARGET_PROPERTY(libSolver ${SolverName} LOCATION)
GET_FILENAME_COMPONENT(libSolverName ${libSolver} NAME)

GET_TARGET_PROPERTY(libSimController ${SimControllerName} LOCATION)
GET_FILENAME_COMPONENT(libSimControllerName ${libSimController} NAME)

GET_TARGET_PROPERTY(libMath ${MathName} LOCATION)
GET_FILENAME_COMPONENT(libMathName ${libMath} NAME)

GET_TARGET_PROPERTY(libDataExchange ${DataExchangeName} LOCATION)
GET_FILENAME_COMPONENT(libDataExchangeName ${libDataExchange} NAME)

GET_TARGET_PROPERTY(libModelicaCompiler ${ModelicaCompilerName} LOCATION)
GET_FILENAME_COMPONENT(libModelicaCompilerName ${libModelicaCompiler} NAME)

GET_TARGET_PROPERTY(libSimObjFactory ${OMCFactoryName} LOCATION)
GET_FILENAME_COMPONENT(libSimObjFactoryName ${libSimObjFactory} NAME)

GET_TARGET_PROPERTY(libFMU ${FMUName} LOCATION)
GET_FILENAME_COMPONENT(libFMUName ${libFMU} NAME)

#set (KLU_LIB ${libKluName})
set (EULER_LIB ${libEulerName})
set (RK12_LIB ${libRK12Name})
set (RTEULER_LIB ${libRTEulerName})
set (SETTINGSFACTORY_LIB ${libSetFactoryName})
set (MODELICASYSTEM_LIB ${libModelicaName})
set (NEWTON_LIB ${libNewtonName})
set (BROYDEN_LIB ${libBroydenName})
set (UMFPACK_LIB ${libUmfPackName})
set (PEER_LIB ${libPeerName})
set (DASSL_LIB ${libDASSLName})
set (CPPDASSL_LIB ${libCppDASSLName})
set (RTRK_LIB ${libRTRKName})
set (SYSTEM_LIB ${libSystemName})
set (SOLVER_LIB ${libSolverName})
SET (LINEARSOLVER_LIB ${libLinearSolverName})
SET (DGESVSOLVER_LIB ${libDgesvSolverName})
set (MATH_LIB ${libMathName})
set (HYBRJ_LIB ${libHybrjName})
set (SIMOBJFACTORY_LIB ${libSimObjFactoryName})
set (DATAEXCHANGE_LIB ${libDataExchangeName})
set (SIMCONTROLLER_LIB ${libSimControllerName})
set (EXTENSIONUTILITIES_LIB ${libExtensionUtilitiesName})
set (MODELICACOMPILER_LIB ${libModelicaCompilerName})
set (FMU_LIB ${libFMUName})
set (DGESV_LIB ${libDgesvName})

# configure a header file to pass some library names
# to the source code which are used to dynamic load and instantiate
configure_file (
  "${PROJECT_SOURCE_DIR}/LibrariesConfig.h.in"
  "${PROJECT_BINARY_DIR}/LibrariesConfig.h"
  )

MACRO(INSTALL_HEADERS_WITH_DIRECTORY HEADER_LIST)

FOREACH(HEADER ${${HEADER_LIST}})
    STRING(REGEX MATCH "(.*)[/\\]" DIR ${HEADER})
    STRING(REPLACE Include "" DIR ${DIR})
  #message(STATUS "copy to "include/omc/cpp/${DIR})
  INSTALL(FILES ${HEADER} DESTINATION include/omc/cpp/${DIR})
ENDFOREACH(HEADER)

ENDMACRO(INSTALL_HEADERS_WITH_DIRECTORY)




install (FILES "${PROJECT_BINARY_DIR}/LibrariesConfig.h" DESTINATION include/omc/cpp)

install (FILES "Licenses/sundials.license" DESTINATION share/omc/runtime/cpp/licenses)

#copy Utils/extension
SET(HS Core/Object/IObject.h
        Core/Object/Object.h
        Core/Utils/extension/adaptable_factory.hpp
        Core/Utils/extension/common.hpp
        Core/Utils/extension/convenience.hpp
        Core/Utils/extension/extension.hpp
        Core/Utils/extension/factory.hpp
        Core/Utils/extension/factory_map.hpp
        Core/Utils/extension/filesystem.hpp
        Core/Utils/extension/parameter.hpp
        Core/Utils/extension/parameter_map.hpp
        Core/Utils/extension/registry.hpp
        Core/Utils/extension/shared_library.hpp
        Core/Utils/extension/type_map.hpp
        Core/Utils/extension/logger.hpp
        Core/Utils/extension/impl/adaptable_factory.hpp
        Core/Utils/extension/impl/adaptable_factory_free_functions.hpp
        Core/Utils/extension/impl/adaptable_factory_set.hpp
        Core/Utils/extension/impl/create.hpp
        Core/Utils/extension/impl/create_func.hpp
        Core/Utils/extension/impl/decl.hpp
        Core/Utils/extension/impl/factory.hpp
        Core/Utils/extension/impl/factory_map.hpp
        Core/Utils/extension/impl/function.hpp
        Core/Utils/extension/impl/library_impl.hpp
        Core/Utils/extension/impl/shared_library.hpp
        Core/Utils/extension/impl/typeinfo.hpp
        FMU2/fmi2Functions.h
        FMU2/fmi2FunctionTypes.h
        FMU2/fmi2TypesPlatform.h
        FMU2/FMU2GlobalSettings.h
        FMU2/FMU2Interface.cpp
        FMU2/FMU2Wrapper.cpp
        FMU2/FMU2Wrapper.h)
   INSTALL_HEADERS_WITH_DIRECTORY(HS)

if(UNIX AND Boost_INCLUDE_DIR STREQUAL "/usr/include")
  # symlink boost includes outside platform specific /usr/include
  install(CODE "execute_process(COMMAND ln -sf /usr/include/boost \"${CMAKE_INSTALL_PREFIX}/include/omc/cpp/\")")
endif(UNIX AND Boost_INCLUDE_DIR STREQUAL "/usr/include")


endif(OPENMODELICA_NEW_CMAKE_BUILD)
