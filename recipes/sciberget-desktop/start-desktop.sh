#!/usr/bin/env bash
set -euo pipefail

export HOME="${HOME:-/home/sciberget}"
export USER="${USER:-sciberget}"
export SCIBERGET_LOCAL_CONTAINERS="${SCIBERGET_LOCAL_CONTAINERS:-/sciberget-storage/containers}"
export SCIBERGET_CVMFS_REPO="${SCIBERGET_CVMFS_REPO:-sciberget.example.org}"
export CVMFS_MODULES="/cvmfs/${SCIBERGET_CVMFS_REPO}/sciberget-modules"
export OFFLINE_MODULES="${SCIBERGET_LOCAL_CONTAINERS}/modules"
export APPTAINER_BINDPATH="/data,/mnt,/sciberget-storage,/tmp,/cvmfs"

mkdir -p "$HOME/.vnc" "$SCIBERGET_LOCAL_CONTAINERS"
if [[ ! -f "$HOME/.vnc/passwd" ]]; then
    vnc_password="${SCIBERGET_VNC_PASSWORD:-$(openssl rand -base64 24 | tr -dc A-Za-z0-9 | head -c 8)}"
    printf '%s' "$vnc_password" > "$HOME/.vnc/plaintext-password"
    chmod 600 "$HOME/.vnc/plaintext-password"
    printf '%s\n' "$vnc_password" | vncpasswd -f > "$HOME/.vnc/passwd"
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

vnc_password="$(cat "$HOME/.vnc/plaintext-password")"
sed -i "s|SCIBERGET_VNC_PASSWORD|${vnc_password}|g" /etc/guacamole/user-mapping.xml
guacd -b 127.0.0.1 -l 4822 &
/usr/local/tomcat/bin/catalina.sh run
