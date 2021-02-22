#!/usr/bin/env bash
# Author Tobias Schifftner, https://www.twitter.com/tschifftner

# exit when any command fails
set -e

# debug
# set -x

########################################################################################################################
# Variables
########################################################################################################################

# Colors
export COLOR_RED="\033[0;31m"
export COLOR_YELLOW="\033[0;33m"
export COLOR_GREEN="\033[0;32m"
export COLOR_OCHRE="\033[38;5;95m"
export COLOR_BLUE="\033[0;34m"
export COLOR_WHITE="\033[0;37m"
export COLOR_RESET="\033[0m"

# Backgrounds
export ERROR_COLOR="\e[41;1;37m"
export SUCCESS_COLOR="\e[30;48;5;82m"

SOURCE_DIR=$PWD
TARGET_DIR='artifacts'

########################################################################################################################
# Functions
########################################################################################################################

error_exit() {
	echo -e "\n${ERROR_COLOR} ${1} ${COLOR_RESET}"
    exit 1;
}

info() {
    echo -e "${COLOR_GREEN}"
    echo -e "########################################################################################################################"
    echo -e "$1"
    echo -e "########################################################################################################################"
    echo -e "${COLOR_RESET}"
}

function usage {
    echo ""
    echo "Usage:"
    echo "$0 --filename <filename> --build <buildNr>  --source-dir <sourceDir> [--git-revision]"
    echo ""
    echo "   -f|--filename            Filename (i.e. projectA.tar.gz)"
    echo "   -s|--source-dir          Source folder /project_root"
    echo "   -t|--target-dir          Target folder (i.e. artifacts/)"
    echo "   -b|--build               Build number (i.e. 123)"
    echo "   -g|--git-revision        GIT revision (i.e. 37ed7a1)"
    echo ""
    exit 0
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -f|--filename)
    FILENAME="$2"
    shift # past argument
    shift # past value
    ;;
    -b|--build)
    BUILD_NUMBER="${2}"
    shift # past argument
    shift # past value
    ;;
    -g|--git-revision)
    GIT_REVISION="$2"
    shift # past argument
    shift # past value
    ;;
    -s|--source-dir)
    SOURCE_DIR=$(echo "${2}" | sed -e "s/\/*$//")
    shift # past argument
    shift # past value
    ;;
    -t|--target-dir)
    TARGET_DIR=$(echo "${2}" | sed -e "s/\/*$//")
    shift # past argument
    shift # past value
    ;;
    -h|--help)
    usage
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
set -- "${POSITIONAL[@]}" # restore positional parameters


########################################################################################################################
info "Validation"
########################################################################################################################

[ -z "${FILENAME}" ] && error_exit "No file name given (--filename)"
[ -z "${BUILD_NUMBER}" ] && error_exit "No build number given (--build)"

cd "${SOURCE_DIR}" || error_exit "Changing directory failed"

[ -f 'composer.json' ] || error_exit "Could not find composer.json"
[ -f 'pub/index.php' ] || error_exit "Could not find pub/index.php"

########################################################################################################################
info "Prepare for packaging"
########################################################################################################################

# Prepare for production
touch .maintenance.flag
#php bin/magento setup:di:compile
#php bin/magento setup:static-content:deploy

# Write file: build.txt
echo "${BUILD_NUMBER}" > build.txt

# Write file: version.txt
echo "Build: ${BUILD_NUMBER}" > pub/version.txt
printf "Build time: %s\n" "$(date "+%c")" >> pub/version.txt
[ -n "${GIT_REVISION}" ] && echo "Revision: ${GIT_REVISION}" >> pub/version.txt

# Create package
[ -d "${TARGET_DIR}" ] || mkdir "${TARGET_DIR}"

# Backwards compatibility in case tar_excludes.txt doesn't exist
[ -f "deploy/tar_excludes.txt" ] || touch deploy/tar_excludes.txt

tmpfile=$(mktemp)

BASEPACKAGE="${TARGET_DIR}/${FILENAME}"
echo "Creating base package '${BASEPACKAGE}'"
tar -vczf "${BASEPACKAGE}" \
    --exclude=./var/log \
    --exclude=./pub/media \
    --exclude=./artifacts \
    --exclude="${TARGET_DIR}" \
    --exclude=./tmp \
    --exclude-from="deploy/tar_excludes.txt" . > "$tmpfile" || error_exit "Creating archive failed"

# Remove ./ line or all files are ignored
sed -i '/^\.\/$/d' "$tmpfile"

EXTRAPACKAGE=${BASEPACKAGE/.tar.gz/.extra.tar.gz}
echo "Creating extra package '${EXTRAPACKAGE}' with the remaining files"
tar -czf "${EXTRAPACKAGE}" \
    --exclude=./var/log \
    --exclude=./pub/media \
    --exclude=./artifacts \
	--exclude="${TARGET_DIR}" \
    --exclude=./tmp \
    --exclude-from="$tmpfile" .  || error_exit "Creating extra archive failed"

rm "$tmpfile"

cd "${TARGET_DIR}" || error_exit "Cannot enter ${TARGET_DIR}"
md5sum -- *.* > MD5SUMS

########################################################################################################################
info "File hashes"
########################################################################################################################
cat MD5SUMS

echo -e "\n${BACKGROUND_GREEN} Successfully packaged! ${COLOR_RESET}\n"
