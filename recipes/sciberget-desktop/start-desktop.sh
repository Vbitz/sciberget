#!/usr/bin/env bash
set -euo pipefail

export HOME="${HOME:-/home/sciberget}"
export USER="${USER:-sciberget}"
export SCIBERGET_LOCAL_CONTAINERS="${SCIBERGET_LOCAL_CONTAINERS:-/sciberget-storage/containers}"
export SCIBERGET_CVMFS_REPO="${SCIBERGET_CVMFS_REPO:-sciberget.example.org}"
export CVMFS_MODULES="/cvmfs/${SCIBERGET_CVMFS_REPO}/sciberget-modules"
export OFFLINE_MODULES="${SCIBERGET_LOCAL_CONTAINERS}/modules"
export APPTAINER_BINDPATH="/data,/mnt,/sciberget-storage,/tmp,/cvmfs"

configure_cvmfs() {
    local repo="$SCIBERGET_CVMFS_REPO"
    local server_url="${SCIBERGET_CVMFS_SERVER_URL:-}"
    local key_source="${SCIBERGET_CVMFS_KEY_SOURCE:-}"
    local key_dir="/etc/cvmfs/keys/sciberget"
    local config_dir="/etc/cvmfs/config.d"

    mkdir -p "$key_dir" "$config_dir" "/cvmfs/${repo}" /var/cache/cvmfs
    chown -R cvmfs:cvmfs /var/cache/cvmfs

    if [[ -n "$key_source" ]]; then
        if [[ -f "$key_source" ]]; then
            cp "$key_source" "${key_dir}/${repo}.pub"
        elif [[ -f "${key_source}/keys/${repo}.pub" ]]; then
            cp "${key_source}/keys/${repo}.pub" "${key_dir}/${repo}.pub"
        elif [[ -f "${key_source}/${repo}.pub" ]]; then
            cp "${key_source}/${repo}.pub" "${key_dir}/${repo}.pub"
        fi
    fi

    if [[ -n "$server_url" ]]; then
        cat > "${config_dir}/${repo}.conf" <<EOF
CVMFS_SERVER_URL="${server_url}"
CVMFS_PUBLIC_KEY="${key_dir}/${repo}.pub"
CVMFS_HTTP_PROXY=DIRECT
CVMFS_QUOTA_LIMIT=5000
CVMFS_CACHE_BASE=/var/cache/cvmfs
CVMFS_USE_GEOAPI=no
EOF
    fi

    if [[ "${SCIBERGET_CVMFS_MOUNT:-false}" == "true" ]]; then
        cvmfs_config setup >/dev/null 2>&1 || true
        if ! mountpoint -q "/cvmfs/${repo}"; then
            mount -t cvmfs "$repo" "/cvmfs/${repo}"
        fi
    fi
}

if [[ "$(id -u)" -eq 0 ]]; then
    chmod 660 /dev/loop-control /dev/loop* 2>/dev/null || true
    configure_cvmfs
    chown -R sciberget:sciberget /home/sciberget /sciberget-storage
    exec sudo --preserve-env=SCIBERGET_CVMFS_REPO,SCIBERGET_CVMFS_SERVER_URL,SCIBERGET_CVMFS_KEY_SOURCE,SCIBERGET_CVMFS_MOUNT,SCIBERGET_CVMFS_REQUIRED,SCIBERGET_LOCAL_CONTAINERS,SCIBERGET_DESKTOP_PASSWORD,SCIBERGET_VNC_PASSWORD,SCIBERGET_DESKTOP_GEOMETRY -H -u sciberget "$0" "$@"
fi

if [[ "${SCIBERGET_CVMFS_REQUIRED:-false}" == "true" && ! -d "$CVMFS_MODULES" ]]; then
    echo "[ERROR] Required CVMFS module path is missing: ${CVMFS_MODULES}" >&2
    exit 1
fi

mkdir -p "$HOME/.vnc" "$SCIBERGET_LOCAL_CONTAINERS"
if [[ ! -f "$HOME/.vnc/passwd" ]]; then
    desktop_password="${SCIBERGET_DESKTOP_PASSWORD:-${SCIBERGET_VNC_PASSWORD:-$(openssl rand -base64 32 | tr -dc A-Za-z0-9 | head -c 14)}}"
    printf '%s' "$desktop_password" > "$HOME/.vnc/plaintext-password"
    chmod 600 "$HOME/.vnc/plaintext-password"
    printf '%s\n' "$desktop_password" | vncpasswd -f > "$HOME/.vnc/passwd"
    chmod 600 "$HOME/.vnc/passwd"
fi
cp /home/sciberget/.vnc-xstartup "$HOME/.vnc/xstartup"
chmod +x "$HOME/.vnc/xstartup"

if [[ -f /usr/share/module.sh ]]; then
    # shellcheck disable=SC1091
    source /usr/share/module.sh
fi

if [[ -d "$CVMFS_MODULES" ]]; then
    export MODULEPATH="$(find "$CVMFS_MODULES" -mindepth 1 -maxdepth 1 -type d -printf '%p:' 2>/dev/null)${OFFLINE_MODULES}"
else
    export MODULEPATH="$OFFLINE_MODULES"
fi

vncserver -kill :1 >/dev/null 2>&1 || true
vncserver -geometry "${SCIBERGET_DESKTOP_GEOMETRY:-1280x720}" -depth 24 -localhost yes :1

desktop_password="$(cat "$HOME/.vnc/plaintext-password")"
echo "[INFO] Guacamole username: sciberget"
echo "[INFO] Guacamole password: ${desktop_password}"
sed -i "s|SCIBERGET_GUACAMOLE_PASSWORD|${desktop_password}|g" /etc/guacamole/user-mapping.xml
sed -i "s|SCIBERGET_VNC_PASSWORD|${desktop_password}|g" /etc/guacamole/user-mapping.xml
guacd -b 127.0.0.1 -l 4822 &
/usr/local/tomcat/bin/catalina.sh run
