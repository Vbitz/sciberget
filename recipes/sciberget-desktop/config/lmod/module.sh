# system-wide profile.modules
case "$0" in
    -bash|bash|*/bash) . /usr/share/lmod/lmod/init/bash ;;
       -ksh|ksh|*/ksh) . /usr/share/lmod/lmod/init/ksh ;;
       -zsh|zsh|*/zsh) . /usr/share/lmod/lmod/init/zsh ;;
          -sh|sh|*/sh) . /usr/share/lmod/lmod/init/sh ;;
                    *) . /usr/share/lmod/lmod/init/sh ;;
esac
