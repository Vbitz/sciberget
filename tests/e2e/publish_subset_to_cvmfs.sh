#!/usr/bin/env bash
set -euo pipefail

repo="${SCIBERGET_CVMFS_REPO:-sciberget.local}"
manifest="${SCIBERGET_E2E_MANIFEST:-/workspace/tests/e2e/.generated/subset.json}"
cvmfs_root="/cvmfs/${repo}"
containers_root="${cvmfs_root}/containers"
modules_root="${cvmfs_root}/sciberget-modules"

if [[ ! -f "$manifest" ]]; then
    echo "[ERROR] Missing E2E manifest: $manifest" >&2
    exit 1
fi

for _ in $(seq 1 120); do
    if [[ -d "/etc/cvmfs/repositories.d/${repo}" && -f "/srv/cvmfs/${repo}/.cvmfswhitelist" ]]; then
        break
    fi
    sleep 1
done

if [[ ! -d "/etc/cvmfs/repositories.d/${repo}" ]]; then
    echo "[ERROR] CVMFS repository ${repo} was not initialized" >&2
    exit 1
fi

start_transaction() {
    local output status
    for attempt in $(seq 1 10); do
        set +e
        output="$(cvmfs_server transaction "$repo" 2>&1)"
        status=$?
        set -e

        if (( status == 0 )); then
            break
        fi

        if grep -qi "another transaction is already open" <<<"$output"; then
            break
        fi

        if (( attempt == 10 )); then
            printf '%s\n' "$output" >&2
            return "$status"
        fi

        printf '%s\n' "$output" >&2
        echo "[INFO] CVMFS transaction start failed; retrying (${attempt}/10)" >&2
        sleep 3
    done

    if (( status != 0 )); then
        printf '%s\n' "$output" >&2
        if grep -qi "another transaction is already open" <<<"$output"; then
            if touch "${cvmfs_root}/.sciberget-write-test" 2>/dev/null; then
                rm -f "${cvmfs_root}/.sciberget-write-test"
                echo "[INFO] Reusing writable open transaction for ${repo}"
                return
            fi

            echo "[INFO] Aborting stale read-only transaction state for ${repo}"
            cvmfs_server abort -f "$repo" || true
            cvmfs_server transaction "$repo"
        else
            return "$status"
        fi
    fi

    if ! touch "${cvmfs_root}/.sciberget-write-test" 2>/dev/null; then
        echo "[ERROR] CVMFS repository ${repo} is still not writable after starting a transaction" >&2
        cvmfs_server list >&2 || true
        mount | grep "$repo" >&2 || true
        exit 1
    fi
    rm -f "${cvmfs_root}/.sciberget-write-test"
}

start_transaction

while IFS= read -r app; do
    image_id="$(jq -r '.image_id' <<<"$app")"
    name="$(jq -r '.name' <<<"$app")"
    version="$(jq -r '.version' <<<"$app")"
    sif_rel="$(jq -r '.sif' <<<"$app")"
    sif_src="/workspace/${sif_rel}"
    container_dir="${containers_root}/${image_id}"
    sif_dst="${container_dir}/${image_id}.simg"

    if [[ ! -f "$sif_src" ]]; then
        echo "[ERROR] Missing SIF for ${image_id}: ${sif_src}" >&2
        exit 1
    fi

    echo "[INFO] Publishing ${image_id}"
    mkdir -p "$container_dir"
    cp "$sif_src" "$sif_dst"
    : > "${container_dir}/commands.txt"

    while IFS= read -r bin; do
        [[ -n "$bin" ]] || continue
        echo "$bin" >> "${container_dir}/commands.txt"
        cat > "${container_dir}/${bin}" <<EOF
#!/usr/bin/env bash
set -euo pipefail
exec singularity --silent exec --cleanenv "${sif_dst}" "${bin}" "\$@"
EOF
        chmod +x "${container_dir}/${bin}"
    done < <(jq -r '.bins[]' <<<"$app")

    while IFS= read -r category; do
        [[ -n "$category" ]] || continue
        category="${category// /-}"
        module_dir="${modules_root}/${category}/${name}"
        mkdir -p "$module_dir"
        cat > "${module_dir}/${version}.lua" <<EOF
-- -*- lua -*-
help([[sci-ber-get E2E module for ${image_id}]])
whatis("${image_id}")
prepend_path("PATH", "${container_dir}")
EOF
        ln -sfn "${version}.lua" "${module_dir}/latest.lua"
        ln -sfn "${version}.lua" "${module_dir}/latest"
    done < <(jq -r '.categories[]' <<<"$app")
done < <(jq -c '.apps[]' "$manifest")

cvmfs_server publish -m "E2E publish selected sci-ber-get containers" "$repo"
echo "[INFO] Published E2E subset to ${repo}"
