#!/usr/bin/env bash
set -euo pipefail

repo="${SCIBERGET_CVMFS_REPO:-sciberget.local}"
public_url_template="${SCIBERGET_PUBLIC_URL:-http://127.0.0.1/cvmfs/@fqrn@}"
public_url="${public_url_template//@fqrn@/$repo}"
repo_dir="/etc/cvmfs/repositories.d/${repo}"

if [[ "${SCIBERGET_AUTO_INIT:-true}" == "true" && ! -d "$repo_dir" ]]; then
    echo "[INFO] Initialising CVMFS repository ${repo}"
    apachectl start
    if ! cvmfs_server mkfs -o cvmfs -w "$public_url" "$repo"; then
        if [[ -d "$repo_dir" && -f "/srv/cvmfs/${repo}/.cvmfswhitelist" ]]; then
            echo "[WARN] CVMFS mkfs completed repository creation but failed its local mount health check."
            echo "[WARN] Continuing because the repository is configured and publishable over Apache."
        else
            exit 1
        fi
    fi
    apachectl stop
fi

if [[ -d "$repo_dir" ]]; then
    echo "[INFO] CVMFS repository ${repo} is configured."
    echo "[INFO] Public URL template: ${public_url}"
else
    echo "[WARN] ${repo} is not configured. Run cvmfs_server mkfs inside this container."
fi

if [[ -d "/srv/cvmfs/${repo}" ]]; then
    mkdir -p "/var/www/html/cvmfs"
    if [[ ! -e "/var/www/html/cvmfs/${repo}" ]]; then
        ln -s "/srv/cvmfs/${repo}" "/var/www/html/cvmfs/${repo}"
    fi
fi

exec apachectl -DFOREGROUND
