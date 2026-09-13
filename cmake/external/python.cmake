# Copyright (c) 2016 PaddlePaddle Authors. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include(python_module)

check_py_version(${PY_VERSION})

# Find Python with the modern CMake module. The legacy PythonInterp and
# PythonLibs modules trigger CMP0148 warnings and are removed by newer CMake.
if(PYTHON_EXECUTABLE)
  set(Python3_EXECUTABLE "${PYTHON_EXECUTABLE}" CACHE FILEPATH
      "Python 3 interpreter selected by Paddle" FORCE)
endif()

if(WIN32)
  find_package(Python3 ${PY_VERSION} REQUIRED COMPONENTS Interpreter)
else()
  find_package(Python3 ${PY_VERSION} REQUIRED COMPONENTS Interpreter Development)
endif()

set(PYTHON_EXECUTABLE "${Python3_EXECUTABLE}" CACHE FILEPATH
    "Python interpreter" FORCE)
set(PYTHON_VERSION_STRING "${Python3_VERSION}" CACHE STRING
    "Python version" FORCE)
set(PYTHONINTERP_FOUND "${Python3_Interpreter_FOUND}")

if(WIN32)
  execute_process(
    COMMAND
      "${PYTHON_EXECUTABLE}" "-c"
      "import sys;import sysconfig;
print(sys.base_prefix);
print(sysconfig.get_config_var('LDVERSION') or sysconfig.get_config_var('VERSION'));
print(sysconfig.get_path('include'));
"
    RESULT_VARIABLE _PYTHON_SUCCESS
    OUTPUT_VARIABLE _PYTHON_VALUES
    ERROR_VARIABLE _PYTHON_ERROR_VALUE)

  if(NOT _PYTHON_SUCCESS EQUAL 0)
    set(PYTHONLIBS_FOUND FALSE)
    return()
  endif()

  # Convert the process output into a list
  string(REGEX REPLACE ";" "\\\\;" _PYTHON_VALUES ${_PYTHON_VALUES})
  string(REGEX REPLACE "\n" ";" _PYTHON_VALUES ${_PYTHON_VALUES})
  list(GET _PYTHON_VALUES 0 PYTHON_PREFIX)
  list(GET _PYTHON_VALUES 1 PYTHON_LIBRARY_SUFFIX)
  list(GET _PYTHON_VALUES 2 PYTHON_INCLUDE_DIR_FROM_SYS)

  # Make sure all directory separators are '/'
  string(REGEX REPLACE "\\\\" "/" PYTHON_PREFIX ${PYTHON_PREFIX})
  string(REGEX REPLACE "\\\\" "/" PYTHON_INCLUDE_DIR_FROM_SYS
                       ${PYTHON_INCLUDE_DIR_FROM_SYS})

  if(NOT Python3_INCLUDE_DIRS)
    set(Python3_INCLUDE_DIRS "${PYTHON_INCLUDE_DIR_FROM_SYS}")
  endif()

  set(PYTHON_LIBRARY "${PYTHON_PREFIX}/libs/Python${PYTHON_LIBRARY_SUFFIX}.lib")

  # when run in a venv, PYTHON_PREFIX points to it. But the libraries remain in the
  # original python installation. They may be found relative to PYTHON_INCLUDE_DIR.
  if(NOT EXISTS "${PYTHON_LIBRARY}")
    get_filename_component(_PYTHON_ROOT ${PYTHON_INCLUDE_DIR} DIRECTORY)
    set(PYTHON_LIBRARY
        "${_PYTHON_ROOT}/libs/Python${PYTHON_LIBRARY_SUFFIX}.lib")
  endif()

  # raise an error if the python libs are still not found.
  if(NOT EXISTS "${PYTHON_LIBRARY}")
    message(FATAL_ERROR "Python libraries not found")
  endif()
  set(PYTHON_LIBRARIES "${PYTHON_LIBRARY}")
  set(PYTHONLIBS_FOUND TRUE)
else()
  set(PYTHON_LIBRARIES "${Python3_LIBRARIES}" CACHE FILEPATH
      "Python libraries" FORCE)
  set(PYTHONLIBS_FOUND "${Python3_Development_FOUND}")
endif(WIN32)

set(PYTHON_INCLUDE_DIR "${Python3_INCLUDE_DIRS}" CACHE PATH
    "Python include directory" FORCE)

# Fixme: Maybe find a static library. Get SHARED/STATIC by FIND_PACKAGE.
add_library(python SHARED IMPORTED GLOBAL)
set_property(TARGET python PROPERTY IMPORTED_LOCATION ${PYTHON_LIBRARIES})

set(py_env "")
if(PYTHONINTERP_FOUND)
  find_python_module(pip REQUIRED)
  find_python_module(numpy REQUIRED)
  find_python_module(wheel REQUIRED)
  find_python_module(google.protobuf REQUIRED)
  find_package(NumPy REQUIRED)
  if(${PY_GOOGLE.PROTOBUF_VERSION} AND ${PY_GOOGLE.PROTOBUF_VERSION}
                                       VERSION_LESS "3.0.0")
    message(
      FATAL_ERROR
        "Found Python Protobuf ${PY_GOOGLE.PROTOBUF_VERSION} < 3.0.0, "
        "please use pip to upgrade protobuf. pip install -U protobuf")
  endif()
endif(PYTHONINTERP_FOUND)

include_directories(${PYTHON_INCLUDE_DIR})
include_directories(${PYTHON_NUMPY_INCLUDE_DIR})
