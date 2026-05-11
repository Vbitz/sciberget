#!/usr/bin/env bash
set -euo pipefail

repo="${SCIBERGET_CVMFS_REPO:-sciberget.local}"
manifest="${SCIBERGET_E2E_MANIFEST:-/workspace/tests/e2e/.generated/subset.json}"

if [[ ! -d "/cvmfs/${repo}/sciberget-modules" ]]; then
    echo "[ERROR] CVMFS modules are not mounted for ${repo}" >&2
    exit 1
fi

# shellcheck disable=SC1091
source /usr/share/module.sh

for desktop_file in /home/sciberget/Desktop/Terminal.desktop /home/sciberget/Desktop/Nmap.desktop; do
    if [[ ! -f "$desktop_file" ]]; then
        echo "[ERROR] Missing desktop launcher: ${desktop_file}" >&2
        exit 1
    fi
done

if ! grep -q "sciberget-applications.menu" /etc/xdg/menus/lxde-applications.menu; then
    echo "[ERROR] sci-ber-get LXDE menu merge is not installed" >&2
    exit 1
fi

if [[ ! -f /usr/share/applications/sciberget-nmap-7_95.desktop ]]; then
    echo "[ERROR] Missing nmap application launcher" >&2
    exit 1
fi

for libfm_config in /etc/xdg/libfm/libfm.conf /home/sciberget/.config/libfm/libfm.conf; do
    if ! grep -Eq '^quick_exec=1$' "$libfm_config"; then
        echo "[ERROR] PCManFM executable launcher prompts are not disabled in ${libfm_config}" >&2
        exit 1
    fi
done

while IFS= read -r app; do
    name="$(jq -r '.name' <<<"$app")"
    version="$(jq -r '.version' <<<"$app")"
    first_bin="$(jq -r '.bins[0]' <<<"$app")"

    echo "[INFO] Checking module ${name}/${version}"
    module use "/cvmfs/${repo}/sciberget-modules"/*
    module avail "${name}/${version}" 2>&1 | grep -q "${name}/${version}"
    module load "${name}/${version}"
    command -v "$first_bin"
    "$first_bin" --version >/tmp/sciberget-e2e-${name}.txt 2>&1 || {
        cat "/tmp/sciberget-e2e-${name}.txt" >&2
        exit 1
    }
    SCIBERGET_E2E_MODULE="${name}/${version}" SCIBERGET_E2E_BIN="$first_bin" \
        sudo --preserve-env=SCIBERGET_CVMFS_REPO,SCIBERGET_E2E_MODULE,SCIBERGET_E2E_BIN -H -u sciberget bash -ic '
            set -e
            module avail "$SCIBERGET_E2E_MODULE" >/dev/null 2>&1
            module load "$SCIBERGET_E2E_MODULE"
            command -v "$SCIBERGET_E2E_BIN"
            "$SCIBERGET_E2E_BIN" --version >/dev/null
        '
done < <(jq -c '.apps[]' "$manifest")

echo "[INFO] Desktop can load and execute selected apps from CVMFS"
