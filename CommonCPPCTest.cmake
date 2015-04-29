# Copyright (c) 2010 Daniel Pfeifer
#               2010-2015, Stefan Eilemann <eile@eyescale.ch>
#               2014, Juan Hernando <jhernando@fi.upm.es>
#
# Creates cpptests and perftests targets. The first one creates a test
# for each .c or .cpp file in the current directory tree, excluding
# the ones which start with perf (either as top-level directory name
# or filename). The latter are added to perftests, and are not meant
# to be executed with each test run. Both targets will update and
# compile the test executables before invoking ctest. CommonCTests
# includes the targets into the more general 'tests' and 'perftests'
# targets, respectively.
#
# Input:
# * TEST_LIBRARIES link each test executables against these libraries
# * EXCLUDE_FROM_TESTS relative paths to test files to exclude; optional
# * For each test ${NAME}_INCLUDE_DIRECTORIES and ${NAME}_LINK_LIBRARIES can
#   be set to configure target specific includes and link libraries, where
#   NAME is the test filename without the .cpp extension. Per test include
#   directories are only supported for for CMake 2.8.8
# * For each test ${TEST_PREFIX} and ${TEST_ARGS}, or if present,
#   ${NAME}_TEST_PREFIX and ${NAME}_TEST_ARGS, can be
#   set to customise the actual test command, supplying a prefix command
#   and additional arguments to follow the test executable.
# * TEST_LABEL sets the LABEL property on each generated test;
#   ${NAME}_TEST_LABEL specifies an additional label.
# * UNIT_AND_PERF_TESTS a list with files which should be compiled
#   also as performance tests. The unit test will be named 'file',
#   whereas the performance test will be named 'perf_file'.

if(NOT WIN32) # tests want to be with DLLs on Windows - no rpath support
  set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR})
endif()

include_directories(${CMAKE_CURRENT_LIST_DIR}/cpp ${PROJECT_SOURCE_DIR})

file(GLOB_RECURSE TEST_FILES RELATIVE ${CMAKE_CURRENT_SOURCE_DIR} *.c *.cpp)
foreach(FILE ${EXCLUDE_FROM_TESTS})
  list(REMOVE_ITEM TEST_FILES ${FILE})
endforeach()
list(SORT TEST_FILES)

set(ALL_CPP_TESTS)
set(ALL_CPP_PERF_TESTS)

macro(common_add_cpp_test NAME FILE)
  set(TEST_NAME ${PROJECT_NAME}_${NAME})
  if(NOT TARGET ${NAME}) # Create target without project prefix if possible
    set(TEST_NAME ${NAME})
  endif()

  if(NAME MATCHES "^perf.*")
    list(APPEND ALL_CPP_PERF_TESTS ${TEST_NAME})
  else()
    list(APPEND ALL_CPP_TESTS ${TEST_NAME})
  endif()

  add_executable(${TEST_NAME} ${FILE})
  set_target_properties(${TEST_NAME} PROPERTIES FOLDER "Tests"
    OUTPUT_NAME ${NAME})

  # Per target INCLUDE_DIRECTORIES if supported
  if(CMAKE_VERSION VERSION_GREATER 2.8.7 AND ${NAME}_INCLUDE_DIRECTORIES)
    set_target_properties(${TEST_NAME} PROPERTIES
      INCLUDE_DIRECTORIES "${${NAME}_INCLUDE_DIRECTORIES}")
  endif()

  # Test link libraries
  target_link_libraries(${TEST_NAME}
    ${${NAME}_LINK_LIBRARIES} ${TEST_LIBRARIES})
  # Per target test command customisation with
  # ${NAME}_TEST_PREFIX and ${NAME}_TEST_ARGS
  set(RUN_PREFIX ${TEST_PREFIX})
  if(${NAME}_TEST_PREFIX)
    set(RUN_PREFIX ${${NAME}_TEST_PREFIX})
  endif()
  set(RUN_ARGS ${TEST_ARGS})
  if(${NAME}_TEST_ARGS)
    set(RUN_ARGS ${${NAME}_TEST_ARGS})
  endif()

  add_test(NAME ${TEST_NAME}
    COMMAND ${RUN_PREFIX} $<TARGET_FILE:${TEST_NAME}> ${RUN_ARGS})

  # Add test labels
  set(TEST_LABELS ${TEST_LABEL} ${${NAME}_TEST_LABEL})
  if(TEST_LABELS)
    set_tests_properties(${TEST_NAME} PROPERTIES
      LABELS "${TEST_LABELS}")
  endif()
endmacro()

foreach(FILE ${TEST_FILES})
  string(REGEX REPLACE "\\.(c|cpp)$" "" NAME ${FILE})
  string(REGEX REPLACE "[./]" "_" NAME ${NAME})
  source_group(\\ FILES ${FILE})

  common_add_cpp_test(${NAME} ${FILE})
  list(FIND UNIT_AND_PERF_TESTS ${FILE} ADD_PERF_TEST)
  if(ADD_PERF_TEST GREATER -1)
    common_add_cpp_test(perf_${NAME} ${FILE})
  endif()
endforeach()

if(TARGET ${PROJECT_NAME}_cpptests)
  add_dependencies(${PROJECT_NAME}_cpptests ${ALL_CPP_TESTS})
  if(ALL_CPP_PERF_TESTS)
    add_dependencies(${PROJECT_NAME}_perftests ${ALL_CPP_PERF_TESTS})
  endif()
else()
  add_custom_target(${PROJECT_NAME}_cpptests
    COMMAND ${CMAKE_CTEST_COMMAND} -E '^.*perf_.*' -C $<CONFIGURATION> \${ARGS}
    DEPENDS ${ALL_CPP_TESTS}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running all ${PROJECT_NAME} cpp tests")
  add_custom_target(${PROJECT_NAME}_perftests
    COMMAND ${CMAKE_CTEST_COMMAND} -R '^.*perf_.*' -C $<CONFIGURATION> \${ARGS}
    DEPENDS ${ALL_CPP_PERF_TESTS}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running all ${PROJECT_NAME} performance tests")
endif()
set_target_properties(${PROJECT_NAME}_cpptests PROPERTIES FOLDER "Tests")
set_target_properties(${PROJECT_NAME}_perftests PROPERTIES
  EXCLUDE_FROM_DEFAULT_BUILD ON FOLDER "Tests")

add_dependencies(${PROJECT_NAME}_tests ${PROJECT_NAME}_cpptests)
add_dependencies(tests ${PROJECT_NAME}_tests)
add_dependencies(perftests ${PROJECT_NAME}_perftests)
if(COVERAGE)
  add_dependencies(${PROJECT_NAME}_cpptests ${PROJECT_NAME}_lcov-clean)
  coverage_report(${PROJECT_NAME}_cpptests)
endif()
