#!/usr/bin/env bash
set -euo pipefail

script="$(readlink -f "${BASH_SOURCE[0]}")"
script_dir="$(dirname "$script")"
repo_root="$(cd "${script_dir}/.." && pwd -P)"

# shellcheck disable=SC1091
source "${script_dir}/sciberget.env"

open_cvmfs_transaction() {
    local repo="$1"
    local output status
    output="$(sudo cvmfs_server transaction "$repo" 2>&1)" || status=$?
    status="${status:-0}"
    if [[ "$status" -eq 0 ]]; then
        [[ -n "$output" ]] && echo "$output"
        return 0
    fi
    if grep -q "another transaction is already open" <<<"$output"; then
        echo "[INFO] Reusing existing open transaction for $repo."
        return 0
    fi
    echo "$output"
    return "$status"
}

publish_cvmfs_transaction() {
    local repo="$1"
    local message="$2"
    cd "$HOME"
    sudo cvmfs_server publish -m "$message" "$repo"
}

abort_cvmfs_transaction() {
    local repo="$1"
    cd "$HOME"
    sudo cvmfs_server abort "$repo" || true
}

run_or_echo() {
    if [[ "${SCIBERGET_DRY_RUN}" == "true" ]]; then
        printf '[DRY-RUN] '
        printf '%q ' "$@"
        printf '\n'
    else
        "$@"
    fi
}

sudo_or_echo() {
    run_or_echo sudo "$@"
}

ensure_log() {
    if [[ ! -f "${repo_root}/cvmfs/log.txt" || "${repo_root}/apps.json" -nt "${repo_root}/cvmfs/log.txt" ]]; then
        python3 "${repo_root}/cvmfs/generate_log.py" \
            --apps-json "${repo_root}/apps.json" \
            --output "${repo_root}/cvmfs/log.txt"
    fi
}

expected_containers() {
    cut -d' ' -f1 "${repo_root}/cvmfs/log.txt" | sed '/^$/d'
}

ensure_nested_catalog_markers_for_container() {
    local container_dir="$1"
    local container_name simg_dir catalog_dir
    container_name="$(basename "$container_dir")"
    simg_dir="$container_dir/$container_name.simg"
    for catalog_dir in "$container_dir" "$simg_dir" "$simg_dir/usr" "$simg_dir/usr/lib" "$simg_dir/usr/share"; do
        [[ -d "$catalog_dir" ]] || continue
        [[ -f "$catalog_dir/.cvmfscatalog" ]] && continue
        run_or_echo sudo touch "$catalog_dir/.cvmfscatalog"
    done
}

repair_latest_module_links() {
    local modules_root="${SCIBERGET_CVMFS_ROOT}/${SCIBERGET_MODULES_DIR}"
    [[ -d "$modules_root" || "${SCIBERGET_DRY_RUN}" == "true" ]] || return 0

    while IFS= read -r tool_dir; do
        [[ -d "$tool_dir" ]] || continue
        local latest
        latest="$(find "$tool_dir" -maxdepth 1 \( -type f -o -type l \) ! -name latest ! -name latest.lua -printf '%f\n' 2>/dev/null | sort -V | tail -1)"
        [[ -n "$latest" ]] || continue
        open_cvmfs_transaction "$SCIBERGET_CVMFS_REPO"
        sudo_or_echo ln -sfn "$latest" "${tool_dir}/latest"
        if [[ "$latest" == *.lua ]]; then
            sudo_or_echo ln -sfn "$latest" "${tool_dir}/latest.lua"
        elif [[ -f "${tool_dir}/${latest}.lua" ]]; then
            sudo_or_echo ln -sfn "${latest}.lua" "${tool_dir}/latest.lua"
        fi
        publish_cvmfs_transaction "$SCIBERGET_CVMFS_REPO" "repaired latest module pointer for ${tool_dir#$modules_root/}"
    done < <(find "$modules_root" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | sort)
}

disable_stale_containers() {
    [[ "${SCIBERGET_DISABLE_STALE}" == "true" ]] || return 0

    local containers_root="${SCIBERGET_CVMFS_ROOT}/${SCIBERGET_CONTAINERS_DIR}"
    [[ -d "$containers_root" || "${SCIBERGET_DRY_RUN}" == "true" ]] || return 0

    local expected
    expected="$(expected_containers)"
    while IFS= read -r container_dir; do
        [[ -d "$container_dir" ]] || continue
        local name
        name="$(basename "$container_dir")"
        [[ "$name" == *.disabled ]] && continue
        if ! grep -qxF "$name" <<<"$expected"; then
            open_cvmfs_transaction "$SCIBERGET_CVMFS_REPO"
            sudo_or_echo mv "$container_dir" "${container_dir}.disabled"
            publish_cvmfs_transaction "$SCIBERGET_CVMFS_REPO" "disabled stale container ${name}"
        fi
    done < <(find "$containers_root" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
}

cleanup_old_tags() {
    [[ "${SCIBERGET_DRY_RUN}" != "true" ]] || {
        echo "[DRY-RUN] would keep the newest ${SCIBERGET_TAG_RETENTION} CVMFS tags for ${SCIBERGET_CVMFS_REPO}"
        return 0
    }
    command -v cvmfs_server >/dev/null 2>&1 || return 0
    mapfile -t tags < <(sudo cvmfs_server tag -l "$SCIBERGET_CVMFS_REPO" 2>/dev/null | awk 'NR > 1 {print $1}' | sed '/^$/d')
    local count="${#tags[@]}"
    [[ "$count" -gt "$SCIBERGET_TAG_RETENTION" ]] || return 0
    local remove_count=$((count - SCIBERGET_TAG_RETENTION))
    for tag in "${tags[@]:0:$remove_count}"; do
        sudo cvmfs_server tag -r "$tag" "$SCIBERGET_CVMFS_REPO"
    done
}

sync_one_container() {
    local line="$1"
    local image_builddate tool_name tool_version build_date categories
    local containers_root modules_root container_dir image_url ret

    image_builddate="$(cut -d' ' -f1 <<<"$line")"
    categories="$(awk -F"categories:" '{print $2}' <<<"$line")"
    tool_name="$(cut -d'_' -f1 <<<"$image_builddate")"
    tool_version="$(cut -d'_' -f2 <<<"$image_builddate")"
    build_date="$(cut -d'_' -f3 <<<"$image_builddate")"

    containers_root="${SCIBERGET_CVMFS_ROOT}/${SCIBERGET_CONTAINERS_DIR}"
    modules_root="${SCIBERGET_CVMFS_ROOT}/${SCIBERGET_MODULES_DIR}"
    container_dir="${containers_root}/${image_builddate}"
    image_url="${SCIBERGET_OBJECT_BASE_URL%/}/${image_builddate}.simg"

    if [[ -f "${container_dir}/commands.txt" ]]; then
        echo "[INFO] ${image_builddate} already exists on CVMFS."
    else
        echo "[INFO] Publishing ${image_builddate} from ${image_url}"
        if ! curl --output /dev/null --silent --head --fail "$image_url"; then
            echo "[WARN] Missing SIF object: $image_url"
            return 0
        fi

        if [[ "${SCIBERGET_DRY_RUN}" != "true" ]]; then
            open_cvmfs_transaction "$SCIBERGET_CVMFS_REPO"
            mkdir -p "$containers_root"
            git clone "$SCIBERGET_TRANSPARENT_SINGULARITY_REPO" "$container_dir"
            (
                cd "$container_dir"
                export SINGULARITY_BINDPATH=/cvmfs
                export PATH="$PATH:/usr/sbin"
                ./run_transparent_singularity.sh "$image_builddate" --unpack true
            ) || ret=$?
            ret="${ret:-0}"
            if [[ "$ret" -eq 0 ]]; then
                ensure_nested_catalog_markers_for_container "$container_dir"
                publish_cvmfs_transaction "$SCIBERGET_CVMFS_REPO" "added ${image_builddate}"
            else
                abort_cvmfs_transaction "$SCIBERGET_CVMFS_REPO"
                return "$ret"
            fi
        else
            echo "[DRY-RUN] would clone transparent-singularity and unpack ${image_builddate}"
        fi
    fi

    IFS=',' read -r -a category_list <<<"$categories"
    for category in "${category_list[@]}"; do
        [[ -n "$category" ]] || continue
        category="${category// /-}"
        local source_module="${containers_root}/modules/${tool_name}/${tool_version}"
        local source_lua="${source_module}.lua"
        local target_dir="${modules_root}/${category}/${tool_name}"
        if [[ -f "$source_module" ]]; then
            open_cvmfs_transaction "$SCIBERGET_CVMFS_REPO"
            sudo_or_echo mkdir -p "$target_dir"
            sudo_or_echo cp "$source_module" "${target_dir}/${tool_version}"
            publish_cvmfs_transaction "$SCIBERGET_CVMFS_REPO" "added module ${category}/${tool_name}/${tool_version}"
        fi
        if [[ -f "$source_lua" ]]; then
            open_cvmfs_transaction "$SCIBERGET_CVMFS_REPO"
            sudo_or_echo mkdir -p "$target_dir"
            sudo_or_echo cp "$source_lua" "${target_dir}/${tool_version}.lua"
            publish_cvmfs_transaction "$SCIBERGET_CVMFS_REPO" "added module ${category}/${tool_name}/${tool_version}.lua"
        fi
    done
}

main() {
    ensure_log
    while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        sync_one_container "$line"
    done < "${repo_root}/cvmfs/log.txt"
    repair_latest_module_links
    disable_stale_containers
    cleanup_old_tags
}

main "$@"
