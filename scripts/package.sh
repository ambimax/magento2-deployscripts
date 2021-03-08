#!/usr/bin/env bash
# Author Tobias Schifftner, https://www.twitter.com/tschifftner

# exit when any command fails
set -e
set -o pipefail
set -u

# debug
[ -n "${BATS_ROOT:-}" ] && set -x

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

FILENAME=
BUILD_NUMBER=
GIT_REVISION=

SOURCE_DIR=$PWD
TARGET_DIR='artifacts'
SKIP_CONFIG_DUMP=false
SKIP_DI_COMPILE=false
SKIP_STATIC_CONTENT_DEPLOY=false
SKIP_EXTRA_PACKAGE=false
SAVE_FILELIST=false

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
    echo "   -f|--filename                   Filename (i.e. projectA.tar.gz)"
    echo "   -s|--source-dir                 Source folder /project_root"
    echo "   -t|--target-dir                 Target folder (i.e. artifacts/)"
    echo "   -b|--build                      Build number (i.e. 123)"
    echo "   -g|--git-revision               GIT revision (i.e. 37ed7a1)"
	echo ""
    echo "   --skip-config-dump              Skip config dump before packaging"
    echo "   --skip-di-compile               Skip comiling dependency injections before packaging"
    echo "   --skip-static-content-deploy    Skip generating static content before packaging"
    echo "   --skip-extra-package            Skip generating extra package"
    echo "   --save-filelist                 Save filenames into text file"
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
    --skip-conf-dump)
    SKIP_CONFIG_DUMP=true
    shift # past argument
    ;;
    --skip-di-compile)
    SKIP_DI_COMPILE=true
    shift # past argument
    ;;
    --skip-static-content-deploy)
    SKIP_STATIC_CONTENT_DEPLOY=true
    shift # past argument
    ;;
    --skip-extra-package)
    SKIP_EXTRA_PACKAGE=true
    shift # past argument
    ;;
    --save-filelist)
    SAVE_FILELIST=true
    shift # past argument
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
# [ -n "${POSITIONAL[*]}" ] && set -- "${POSITIONAL[*]}" # restore positional parameters


########################################################################################################################
info "Validation"
########################################################################################################################

[ -z "${FILENAME}" ] && error_exit "No file name given (--filename)"
[ -z "${BUILD_NUMBER}" ] && error_exit "No build number given (--build)"

cd "${SOURCE_DIR}" || error_exit "Changing directory failed"

[ -f 'composer.json' ] || error_exit "Could not find composer.json"
[ -f 'pub/index.php' ] || error_exit "Could not find pub/index.php"
[ -f 'app/etc/config.php' ] || error_exit "Could not find app/etc/config.php"

########################################################################################################################
info "Prepare for packaging"
########################################################################################################################

# Prepare for production
php bin/magento maintenance:enable

echo "Clean caches"
php bin/magento cache:flush
rm -rf pub/static/* var/cache/* var/view_preprocessed/* var/page_cache/* generated/*

[ "${SKIP_CONFIG_DUMP}" = "true" ] || php bin/magento app:config:dump --no-interaction
[ "${SKIP_DI_COMPILE}" = "true" ] || php bin/magento setup:di:compile --no-interaction
[ "${SKIP_STATIC_CONTENT_DEPLOY}" = "true" ] || \
	php bin/magento setup:static-content:deploy --force --strategy=standard --jobs="$(nproc)" --max-execution-time=3600

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
tmpfile2=$(mktemp)

########################################################################################################################
info "Start packaging"
########################################################################################################################

BASEPACKAGE="${TARGET_DIR}/${FILENAME}"
echo "Creating base package '${BASEPACKAGE}'"
tar -vczf "${BASEPACKAGE}" \
    --exclude=./var/log \
    --exclude=./pub/media \
    --exclude=./artifacts \
    --exclude=./app/etc/env.php \
    --exclude="${TARGET_DIR}" \
    --exclude=./tmp \
    --exclude-from="deploy/tar_excludes.txt" . > "$tmpfile" || error_exit "Creating archive failed"

# Remove ./ line or all files are ignored
sed -i '/^\.\/$/d' "$tmpfile"

if [ "${SKIP_EXTRA_PACKAGE}" = "true" ]; then
	echo "Skipping extra package...."
else
	EXTRAPACKAGE=${BASEPACKAGE/.tar.gz/.extra.tar.gz}
	echo "Creating extra package '${EXTRAPACKAGE}' with the remaining files"
	tar -vczf "${EXTRAPACKAGE}" \
		--exclude=./var/log \
		--exclude=./pub/media \
		--exclude=./artifacts \
		--exclude=./app/etc/env.php \
		--exclude="${TARGET_DIR}" \
		--exclude=./tmp \
		--exclude-from="$tmpfile" . > "$tmpfile2" || error_exit "Creating extra archive failed"
fi

if [ "${SAVE_FILELIST}" = "true" ]; then
	cp "$tmpfile" artifacts/filelist.txt
	cp "$tmpfile2" artifacts/filelist.extra.txt
fi

rm "$tmpfile"
rm "$tmpfile2"

# Enable maintenance again
php bin/magento maintenance:disable

cd "${TARGET_DIR}" || error_exit "Cannot enter ${TARGET_DIR}"
md5sum -- *.* > MD5SUMS

########################################################################################################################
info "File hashes"
########################################################################################################################
cat MD5SUMS

echo -e "\n${SUCCESS_COLOR} Successfully packaged! ${COLOR_RESET}\n"

