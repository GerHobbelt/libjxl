#!/bin/bash
# Copyright (c) the JPEG XL Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Tests implemented in bash. These typically will run checks about the source
# code rather than the compiled one.

MYDIR=$(dirname $(realpath "$0"))

set -u

test_includes() {
  local ret=0
  local f
  for f in $(git ls-files | grep -E '(\.cc|\.cpp|\.h)$'); do
    # Check that the public files (in lib/include/ directory) don't use the full
    # path to the public header since users of the library will include the
    # library as: #include "jxl/foobar.h".
    if [[ "${f#lib/include/}" != "${f}" ]]; then
      if grep -i -H -n -E '#include\s*[<"]lib/include/jxl' "$f" >&2; then
        echo "Don't add \"include/\" to the include path of public headers." >&2
        ret=1
      fi
    fi

    if [[ "${f#third_party/}" == "$f" ]]; then
      # $f is not in third_party/

      # Check that local files don't use the full path to third_party/
      # directory since the installed versions will not have that path.
      # Add an exception for third_party/dirent.h.
      if grep -v -F 'third_party/dirent.h' "$f" | \
          grep -i -H -n -E '#include\s*[<"]third_party/' >&2 &&
          [[ $ret -eq 0 ]]; then
        cat >&2 <<EOF
$f: Don't add third_party/ to the include path of third_party projects. This \
makes it harder to use installed system libraries instead of the third_party/ \
ones.
EOF
        ret=1
      fi
    fi

  done
  return ${ret}
}

test_include_collision() {
  local ret=0
  local f
  for f in $(git ls-files | grep -E '^lib/include/'); do
    local base=${f#lib/include/}
    if [[ -e "lib/${base}" ]]; then
      echo "$f: Name collision, both $f and lib/${base} exist." >&2
      ret=1
    fi
  done
  return ${ret}
}

test_copyright() {
  local ret=0
  local f
  for f in $(git ls-files | grep -E '(\.cc|\.cpp|\.h|\.sh|\.m|\.py)$'); do
    if [[ "${f#third_party/}" == "$f" ]]; then
      # $f is not in third_party/
      if ! head -n 10 "$f" |
          grep -F 'Copyright (c) the JPEG XL Project' >/dev/null ; then
        echo "$f: Missing Copyright blob near the top of the file." >&2
        ret=1
      fi
    fi
  done
  return ${ret}
}

# Check for git merge conflict markers.
test_merge_conflict() {
  local ret=0
  TEXT_FILES='(\.cc|\.cpp|\.h|\.sh|\.m|\.py|\.md|\.txt|\.cmake)$'
  for f in $(git ls-files | grep -E "${TEXT_FILES}"); do
    if grep -E '^<<<<<<< ' "$f"; then
      echo "$f: Found git merge conflict marker. Please resolve." >&2
      ret=1
    fi
  done
  return ${ret}
}

# Check that the library and the package have the same version. This prevents
# accidentally having them out of sync.
get_version() {
  local varname=$1
  local line=$(grep -F "set(${varname} " lib/CMakeLists.txt | head -n 1)
  [[ -n "${line}" ]]
  line="${line#set(${varname} }"
  line="${line%)}"
  echo "${line}"
}

test_version() {
  local major=$(get_version JPEGXL_MAJOR_VERSION)
  local minor=$(get_version JPEGXL_MINOR_VERSION)
  local patch=$(get_version JPEGXL_PATCH_VERSION)
  # Check that the version is not empty
  if [[ -z "${major}${minor}${patch}" ]]; then
    echo "Couldn't parse version from CMakeLists.txt" >&2
    return 1
  fi
  local pkg_version=$(head -n 1 debian/changelog)
  # Get only the part between the first "jpeg-xl (" and the following ")".
  pkg_version="${pkg_version#jpeg-xl (}"
  pkg_version="${pkg_version%%)*}"
  if [[ -z "${pkg_version}" ]]; then
    echo "Couldn't parse version from debian package" >&2
    return 1
  fi

  local lib_version="${major}.${minor}.${patch}"
  lib_version="${lib_version%.0}"
  if [[ "${pkg_version}" != "${lib_version}"* ]]; then
    echo "Debian package version (${pkg_version}) doesn't match library" \
      "version (${lib_version})." >&2
    return 1
  fi
  return 0
}

# Check that the SHA versions in deps.sh matches the git submodules.
test_deps_version() {
  while IFS= read -r line; do
    if [[ "${line:0:10}" != "[submodule" ]]; then
      continue
    fi
    line="${line#[submodule \"}"
    line="${line%\"]}"
    local varname="${line^^}"
    varname="${varname/\//_}"
    if ! grep -F "${varname}=" deps.sh >/dev/null; then
      # Ignoring submodule not in deps.sh
      continue
    fi
    local deps_sha=$(grep -F "${varname}=" deps.sh | cut -f 2 -d '"')
    [[ -n "${deps_sha}" ]]
    local git_sha=$(git ls-tree -r HEAD "${line}" | cut -f 1 | cut -f 3 -d ' ')
    if [[ "${deps_sha}" != "${git_sha}" ]]; then
      cat >&2 <<EOF
deps.sh: SHA for project ${line} is at ${deps_sha} but the git submodule is at
${git_sha}. Please update deps.sh
EOF
      return 1
    fi
  done < .gitmodules
}

main() {
  local ret=0
  cd "${MYDIR}"

  if ! git rev-parse >/dev/null 2>/dev/null; then
    echo "Not a git checkout, skipping bash_test"
    return 0
  fi

  IFS=$'\n'
  for f in $(declare -F); do
    local test_name=$(echo "$f" | cut -f 3 -d ' ')
    # Runs all the local bash functions that start with "test_".
    if [[ "${test_name}" == test_* ]]; then
      echo "Test ${test_name}: Start"
      if ${test_name}; then
        echo "Test ${test_name}: PASS"
      else
        echo "Test ${test_name}: FAIL"
        ret=1
      fi
    fi
  done
  return ${ret}
}

main "$@"
