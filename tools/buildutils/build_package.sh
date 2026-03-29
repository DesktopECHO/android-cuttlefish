#!/usr/bin/env bash

# Copyright (C) 2025 The Android Open Source Project
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

set -o errexit -o nounset -o pipefail

function print_usage() {
  >&2 echo "usage: $0 /path/to/pkgdir"
}

if [[ $# -eq 0 ]]; then
  >&2 echo "missing path to package directory"
  print_usage
  exit 1
fi

readonly PKGDIR="$1"
shift

if [[ $# -ne 0 ]]; then
  print_usage
  exit 1
fi

if [[ ! -d "${PKGDIR}/rpm" ]]; then
  >&2 echo "missing rpm directory under ${PKGDIR}"
  exit 1
fi

readonly REPO_DIR="$(realpath "$(dirname "$0")/../..")"
readonly VERSION_FILE="${REPO_DIR}/packaging/VERSION"
readonly VERSION="$(tr -d '\n' < "${VERSION_FILE}")"
readonly RPMBUILD_TOPDIR="${REPO_DIR}/out/rpmbuild"
readonly TAR_BASENAME="android-cuttlefish-${VERSION}"
readonly SOURCE_TARBALL="${RPMBUILD_TOPDIR}/SOURCES/${TAR_BASENAME}.tar.gz"
readonly SOURCE_STAGING_DIR="${RPMBUILD_TOPDIR}/SOURCES/${TAR_BASENAME}"

mkdir -p \
  "${RPMBUILD_TOPDIR}/BUILD" \
  "${RPMBUILD_TOPDIR}/BUILDROOT" \
  "${RPMBUILD_TOPDIR}/RPMS" \
  "${RPMBUILD_TOPDIR}/SOURCES" \
  "${RPMBUILD_TOPDIR}/SPECS" \
  "${RPMBUILD_TOPDIR}/SRPMS"

rm -rf "${SOURCE_STAGING_DIR}" "${SOURCE_TARBALL}"
mkdir -p "${SOURCE_STAGING_DIR}"

rsync -a \
  --exclude='.git/' \
  --exclude='.jj/' \
  --exclude='out/' \
  --exclude='bazel-*/' \
  "${REPO_DIR}/" \
  "${SOURCE_STAGING_DIR}/"

tar -czf "${SOURCE_TARBALL}" -C "${RPMBUILD_TOPDIR}/SOURCES" "${TAR_BASENAME}"
rm -rf "${SOURCE_STAGING_DIR}"

specs=("${PKGDIR}"/rpm/*.spec)
if [[ ${#specs[@]} -eq 0 ]]; then
  >&2 echo "no spec files found under ${PKGDIR}/rpm"
  exit 1
fi

pushd "${PKGDIR}"
for spec in "${specs[@]}"; do
  echo "Building RPM from ${spec}"
  rpmbuild \
    --define "_topdir ${RPMBUILD_TOPDIR}" \
    --define "_sourcedir ${RPMBUILD_TOPDIR}/SOURCES" \
    --define "_srcrpmdir ${RPMBUILD_TOPDIR}/SRPMS" \
    --define "_rpmdir ${RPMBUILD_TOPDIR}/RPMS" \
    --define "_builddir ${RPMBUILD_TOPDIR}/BUILD" \
    --define "_buildrootdir ${RPMBUILD_TOPDIR}/BUILDROOT" \
    -ba "${spec}"
done
popd
