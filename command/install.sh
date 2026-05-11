#!/usr/bin/env bash
set -euo pipefail

script="$(readlink -f "${BASH_SOURCE[0]}")"
base="$(dirname "$script")"
repo_root="$(cd "${base}/.." && pwd -P)"
installdir="${SCIBERGET_INSTALLDIR:-${repo_root}/local/sciberget}"

exec "${base}/build.sh" --cli --installdir="${installdir}"
