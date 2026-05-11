#!/usr/bin/env bash
set -euo pipefail

script="$(readlink -f "${BASH_SOURCE[0]}")"
base="$(dirname "$script")"
repo_root="$(cd "${base}/.." && pwd -P)"

deskenv="cli"
edit="n"
installdir="${SCIBERGET_INSTALLDIR:-${repo_root}/local/sciberget}"
appmenu="/etc/xdg/menus/lxde-applications.menu"
appdir="/usr/share/applications"
deskdir="/usr/share/desktop-directories"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --lxde)
            deskenv="lxde"
            shift
            ;;
        --cli)
            deskenv="cli"
            shift
            ;;
        --edit)
            edit="y"
            shift
            ;;
        --installdir=*)
            installdir="${1#*=}"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

mkdir -p "$installdir"
cat > "${repo_root}/config.ini" <<EOF
[neurodesk]
installdir=${installdir}
deskenv=${deskenv}
appmenu=${appmenu}
appdir=${appdir}
deskdir=${deskdir}
edit=${edit}
sh_prefix=
singularity_opts=
EOF

cd "$repo_root"
python3 -m command \
    --installdir="$installdir" \
    --deskenv="$deskenv" \
    --appmenu="$appmenu" \
    --appdir="$appdir" \
    --deskdir="$deskdir" \
    --edit="$edit"
