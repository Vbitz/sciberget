#!/usr/bin/env bash
#Deploy script for singularity Containers "Transparent Singularity"
#Creates wrapper scripts for all executables in a container's $DEPLOY_PATH
# singularity needs to be available
# for downloading images from nectar it needs curl installed
#11/07/2018
#by Steffen Bollmann <Steffen.Bollmann@cai.uq.edu.au> & Tom Shaw <t.shaw@uq.edu.au>
# set -e

echo "[DEBUG] This is the run_transparent_singularity.sh script"

export SINGULARITY_BINDPATH=$SINGULARITY_BINDPATH,$PWD

_script="$(readlink -f ${BASH_SOURCE[0]})" ## who am i? ##
_base="$(dirname $_script)" ## Delete last component from $_script ##

# echo "making sure this is not running in a symlinked directory (singularity bug)"
# echo "path: $_base"
cd $_base
_base=`pwd -P`
# echo "corrected path: $_base"

POSITIONAL=()
while [[ $# -gt 0 ]]
   do
   key="$1"

   case $key in
      -s|--storage)
      storage="$2"
      shift # past argument
      shift # past value
      ;;
      -c|--container)
      container="$2"
      shift # past argument
      shift # past value
      ;;
      -u|--unpack)
      unpack="$2"
      shift # past argument
      shift # past value
      ;;
      -o|--singularity-opts)
      singularity_opts="$2"
      shift # past argument
      shift # past value
      ;;
      --default)
      DEFAULT=YES
      shift # past argument
      ;;
      *)    # unknown option
      POSITIONAL+=("$1") # save it in an array for later
      shift # past argument
      ;;
   esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters


if [[ -n $1 ]]; then
    container="$1"
   # e.g. export container=matlab_2024b_20250117
fi

if [ -z "$container" ]; then
      echo "-----------------------------------------------"
      echo "Select the container you would like to install:"
      echo "-----------------------------------------------"
      echo "singularity container list:"
      if [[ -n "${SCIBERGET_LOG_URL:-}" ]]; then
         curl -s "${SCIBERGET_LOG_URL}"
      elif [[ -f "${_base}/../../cvmfs/log.txt" ]]; then
         cat "${_base}/../../cvmfs/log.txt"
      fi
      echo " "
      echo "-----------------------------------------------"
      echo "usage examples:"
      echo "./run_transparent_singularity.sh CONTAINERNAME"
      echo "./run_transparent_singularity.sh --container convert3d_1.0.0_20210104.simg --storage docker"
      echo "./run_transparent_singularity.sh convert3d_1.0.0_20210104.simg"
      echo "./run_transparent_singularity.sh convert3d_1.0.0_20210104 --unpack true --singularity-opts '--bind /cvmfs'"
      echo "-----------------------------------------------"
      exit
   else
      echo "-------------------------------------"
      echo "installing container ${container}"
      echo "-------------------------------------"


      # define mount points for this system
      echo "-------------------------------------"
      echo 'IMPORTANT: you need to set your system specific mount points in your .bashrc!: e.g. export SINGULARITY_BINDPATH="/opt,/data"'
      echo "-------------------------------------"
fi

containerName="$(cut -d'_' -f1 <<< ${container})"
echo "containerName: ${containerName}"

containerVersion="$(cut -d'_' -f2 <<< ${container})"
echo "containerVersion: ${containerVersion}"

containerDateAndFileEnding="$(cut -d'_' -f3 <<< ${container})"
containerDate="$(cut -d'.' -f1 <<< ${containerDateAndFileEnding})"
containerEnding="$(cut -d'.' -f2 <<< ${containerDateAndFileEnding})"

echo "containerDate: ${containerDate}"

# if no container extension is given, assume .simg
if [ "$containerEnding" = "$containerDate" ]; then
   containerEnding="simg"
   container=${containerName}_${containerVersion}_${containerDate}.${containerEnding}
fi
echo "containerEnding: ${containerEnding}"


# echo "checking for singularity ..."
qq=`which  singularity`
if [[  ${#qq} -lt 1 ]]; then
   echo "This script requires singularity or apptainer on your path. E.g. add 'module load singularity' to your .bashrc"
   echo "If you are root try again as normal user"
   exit 2
fi

SCIBERGET_CVMFS_REPO="${SCIBERGET_CVMFS_REPO:-sciberget.example.org}"
SCIBERGET_CONTAINERS_DIR="${SCIBERGET_CONTAINERS_DIR:-containers}"
SCIBERGET_OBJECT_BASE_URL="${SCIBERGET_OBJECT_BASE_URL:-}"
SCIBERGET_DOCKER_REGISTRY="${SCIBERGET_DOCKER_REGISTRY:-ghcr.io/sciberget/sciberget}"
SCIBERGET_IMAGE_REF="${SCIBERGET_IMAGE_REF:-${containerName}_${containerVersion}:${containerDate}}"
CVMFS_CONTAINER_PATH="/cvmfs/${SCIBERGET_CVMFS_REPO}/${SCIBERGET_CONTAINERS_DIR}/${containerName}_${containerVersion}_${containerDate}/${containerName}_${containerVersion}_${containerDate}.simg"

echo "checking if $container exists in the cvmfs cache ..."
if  [[ -z "$CVMFS_DISABLE" ]] && [[ -e "${CVMFS_CONTAINER_PATH}" ]]; then
   echo "$container exists in cvmfs"
   storage="cvmfs"
   container_pull="ln -s ${CVMFS_CONTAINER_PATH} $container"
else
   object_url="${SCIBERGET_OBJECT_BASE_URL%/}/${container}"
   if [[ -n "$SCIBERGET_OBJECT_BASE_URL" ]] && curl --output /dev/null --silent --head --fail "$object_url"; then
      echo "$container exists in configured object storage"
      container_pull="curl -fL ${object_url} -O"
   else
      echo "$container does not exist in CVMFS or configured object storage - loading from docker!"
      storage="docker"
      container_pull="singularity pull --name $container docker://${SCIBERGET_DOCKER_REGISTRY}/${SCIBERGET_IMAGE_REF}"
   fi
fi


echo "deploying in $_base"
# echo "checking if container needs to be downloaded"
if  [[ -e $container ]]; then
   echo "container downloaded already. Remove to re-download!"
else
   echo "pulling image now ..."
   echo "where am I: $PWD"
   echo "running: $container_pull"
   $container_pull
fi

if [[ $unpack = "true" ]]
then
   echo "unpacking singularity file to sandbox directory:"
    singularity build --sandbox temp $container
    rm -rf $container
    mv temp $container
fi

echo "checking if there is a README.md file in the container"
echo "executing: singularity exec $singularity_opts --pwd $_base $container cat /README.md"
singularity exec $singularity_opts --pwd $_base $container cat /README.md > README.md

echo "checking which executables exist inside container"
echo "executing: singularity exec $singularity_opts --pwd $_base $container $_base/ts_binaryFinder.sh"
singularity exec $singularity_opts --pwd $_base $container $_base/ts_binaryFinder.sh

echo "create singularity executable for each regular executable in commands.txt"
# $@ parses command line options.
#test   executable="fslmaths"

# The --env option requires singularity > 3.6 or apptainer. Test here:
required_version="3.6"
if which apptainer >/dev/null 2>&1; then
    echo "Apptainer is installed."
    singularity_version=3.6
else
    echo "Apptainer is not installed. Testing for singularity version."
    singularity_version=$(singularity version | cut -d'-' -f1)
fi

while read executable; do \
   echo $executable > $_base/${executable}; \
   echo "#!/usr/bin/env bash" > $executable
   echo "export PWD=\`pwd -P\`" >> $executable

   # neurodesk_singularity_opts is a global variable that can be set in neurodesk for example --nv for gpu support
   # --silent is required to suppress bind mound warnings (e.g. for /etc/localtime)
   # --cleanenv is required to prevent environment variables on the host to affect the containers (e.g. Julia and R packages), but to work 
   # correctly with GUIs, the DISPLAY variable needs to be set as well. This only works in singularity >= 3.6.0
   # --bind is needed to handle non-default temp directories (Github issue #11)
   for customtmp in TMP TMPDIR TEMP TEMPDIR; do
      eval tmpvar=\$$customtmp
      if [[ -n $tmpvar ]]; then
         bindtmpdir="--bind \$$customtmp:/tmp"
      fi
   done
   if printf '%s\n' "$required_version" "$singularity_version" | sort -V | head -n1 | grep -q "$required_version"; then
      echo "singularity --silent exec --cleanenv --env DISPLAY=\$DISPLAY $bindtmpdir \$neurodesk_singularity_opts --pwd \"\$PWD\" $_base/$container $executable \"\$@\"" >> $executable
   else
      echo "Singularity version is older than $required_version. GUIs will not work correctly!"
      echo "singularity --silent exec --cleanenv $bindtmpdir \$neurodesk_singularity_opts --pwd \"\$PWD\" $_base/$container $executable \"\$@\"" >> $executable
   fi

   chmod a+x $executable
done < $_base/commands.txt

echo "creating activate script that runs deactivate first in case it is already there"
echo "#!/usr/bin/env bash" > activate_${container}.sh
echo "source deactivate_${container}.sh $_base" >> activate_${container}.sh
echo -e "export PWD=\`pwd -P\`" >> activate_${container}.sh
echo -e 'export PATH="$PWD:$PATH"' >> activate_${container}.sh
echo -e 'echo "# Container in $PWD" >> ~/.bashrc' >> activate_${container}.sh
echo -e 'echo "export PATH="$PWD:\$PATH"" >> ~/.bashrc' >> activate_${container}.sh
chmod a+x activate_${container}.sh

echo "deactivate script"
echo  pathToRemove=$_base | cat - ts_deactivate_ > temp && mv temp deactivate_${container}.sh
chmod a+x deactivate_${container}.sh


# e.g. export container=matlab_2024b_20250117
echo "create module files one directory up"
modulePath=$_base/../modules/`echo $container | cut -d _ -f 1`
echo $modulePath
# e.g. ../modules/matlab
mkdir $modulePath -p

moduleSoftwareName=`echo $container | cut -d _ -f 1`
# e.g. matlab

moduleName=`echo $container | cut -d _ -f 2`
# e.g. 2024b

echo "-- -*- lua -*-" > ${modulePath}/${moduleName}.lua
echo "help([===[" >> ${modulePath}/${moduleName}.lua 
cat README.md >> ${modulePath}/${moduleName}.lua
echo "]===])" >> ${modulePath}/${moduleName}.lua

echo "whatis(\"${container}\")" >> ${modulePath}/${moduleName}.lua
echo "prepend_path(\"PATH\", \"${_base}\")" >> ${modulePath}/${moduleName}.lua

echo "create environment variables for module file"
while read envvariable; do \
   # envvariable="DEPLOY_ENV_SPMMCRCMD=BASEPATH/opt/spm12/run_spm12.sh BASEPATH/opt/mcr/v97/ script"
   value=${envvariable#*=}
   # echo $value #BASEPATH/opt/spm12/run_spm12.sh BASEPATH/opt/mcr/v97/ script"

   value_with_basepath="${value//BASEPATH/${_base}/${container}}"
   # echo $value_with_basepath

   completeVariableName=${envvariable%=*}
   # echo $completeVariableName

   variableName=${completeVariableName#*DEPLOY_ENV_}
   # echo $variableName

   echo "setenv(\"${variableName}\", \"${value_with_basepath}\")" >> ${modulePath}/${moduleName}.lua
done < $_base/env.txt

#check if there is a manual module file for this container and add it to the end
if [[ -e manual_module_files/${moduleSoftwareName} ]]; then
   echo "addming manual module file"
   cat manual_module_files/${moduleSoftwareName} | sed "s/toolVersion/${moduleName}/g" >> ${modulePath}/${moduleName}.lua
fi

echo "rm ${modulePath}/${moduleName}" >> ts_uninstall.sh
