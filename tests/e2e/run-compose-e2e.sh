#!/usr/bin/env bash
set -euo pipefail

script="$(readlink -f "${BASH_SOURCE[0]}")"
script_dir="$(dirname "$script")"
repo_root="$(cd "${script_dir}/../.." && pwd -P)"
compose_file="${script_dir}/docker-compose.cvmfs-desktop.yml"
apps="${SCIBERGET_E2E_APPS:-nmap}"
repo="${SCIBERGET_CVMFS_REPO:-sciberget.local}"

cd "$repo_root"

python3 tests/e2e/prepare_subset.py --apps "$apps" --output tests/e2e/.generated/subset.json

while IFS= read -r app; do
    app_name="$(jq -r '.name' <<<"$app")"
    sif="$(jq -r '.sif' <<<"$app")"
    if [[ -f "$sif" ]]; then
        echo "[INFO] Reusing ${sif}"
        continue
    fi
    echo "[INFO] Building missing SIF for ${app_name}"
    python3 builder/build.py generate "$app_name" --recreate --build --generate-release
done < <(jq -c '.apps[]' tests/e2e/.generated/subset.json)

python3 builder/build.py generate sciberget-cvmfs-server --recreate
python3 builder/build.py generate sciberget-desktop --recreate

export SCIBERGET_CVMFS_REPO="$repo"

if [[ "${SCIBERGET_E2E_CLEAN:-true}" == "true" ]]; then
    docker compose -f "$compose_file" down -v --remove-orphans
fi

docker compose -f "$compose_file" up --build -d --wait cvmfs-server
docker compose -f "$compose_file" exec -T cvmfs-server \
    /workspace/tests/e2e/publish_subset_to_cvmfs.sh
docker compose -f "$compose_file" up --build -d --wait desktop

docker compose -f "$compose_file" exec -T desktop \
    /workspace/tests/e2e/assert_desktop_cvmfs.sh

echo "[INFO] E2E CVMFS desktop compose test passed"
echo "[INFO] Guacamole desktop: http://localhost:${SCIBERGET_E2E_DESKTOP_PORT:-8080}/"
echo "[INFO] CVMFS HTTP repo: http://localhost:${SCIBERGET_E2E_CVMFS_PORT:-8081}/cvmfs/${repo}/"
