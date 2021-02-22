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

declare -a VALID_ENVIRONMENTS=("live" "production" "staging" "integration" "test")
declare -a PRODUCTION_ENVIRONMENTS=("live" "production" "staging")
export SKIP_SYSTEMSTORAGE_IMPORT=${SKIP_SYSTEMSTORAGE_IMPORT:-true}

SCRIPTPATH=$([ -d "${0}" ] && readlink -f "${0}" || echo "")
SCRIPTDIR=$(dirname "${SCRIPTPATH}")
RELEASEFOLDER=$(readlink -f "${SCRIPTDIR}/../../..")

function usage {
    echo ""
    echo "Usage:"
    echo "$0 --release-dir <releaseDir> --environment <environment> [--skip-systemstorage-import]"
    echo ""
    echo "   -e|--environment            Environment (i.e. staging, production)"
    echo "   -r|--release-dir            Release folder /.../releases/build_20210201"
    echo "   --skip-systemstorage-import     Also download and install .extra.tar.gz package"
    echo ""
    exit 0
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -r|--release-dir)
    RELEASEFOLDER=$(echo "${2}" | sed -e "s/\/*$//")
    shift # past argument
    shift # past value
    ;;
    -e|--environment)
    ENVIRONMENT="$2"
    shift # past argument
    shift # past value
    ;;
    --skip-systemstorage-import)
    SKIP_SYSTEMSTORAGE_IMPORT=true
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
set -- "${POSITIONAL[@]}" # restore positional parameters

SHAREDFOLDER=$([ -d "${RELEASEFOLDER}" ] && readlink -f "${RELEASEFOLDER}/../../shared" || echo "")

export RELEASEFOLDER
export SHAREDFOLDER
export ENVIRONMENT
export MAGE_MODE
# export VALID_ENVIRONMENTS
# export PRODUCTION_ENVIRONMENTS

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

triggerHook() {
    HOOK="deploy/${ENVIRONMENT}/${1}.sh"
    cd "${RELEASEFOLDER}" || error_exit "Error while switching to ${RELEASEFOLDER}"
    if [[ -x "${HOOK}" ]]; then
        bash "${HOOK}"
    fi
}

symlinkSharedDirectory() {
    SOURCE="${SHAREDFOLDER}/${1}"
    DEST="${RELEASEFOLDER}/${1}"

    echo "Symlinking ${SOURCE} to ${DEST}"

    [ ! -d "${SOURCE}" ] && error_exit "Shared directory ${SOURCE} not found"
    [ -d "${DEST}" ] && rm -rf "${DEST}"

    ln -s "${SOURCE}" "${DEST}" || error_exit "Error while symlinking ${SOURCE} to ${DEST}"
}

isValidEnvironment() {
    for i in "${VALID_ENVIRONMENTS[@]}"; do
        if [ "$i" == "$ENVIRONMENT" ] ; then
            return 0
        fi
    done
    error_exit "Illegal environment code: ${ENVIRONMENT}"
}

isProductionEnvironment() {
    for i in "${PRODUCTION_ENVIRONMENTS[@]}"; do
        echo "$i"
        echo "$ENVIRONMENT"
        if [ "$i" == "$ENVIRONMENT" ] ; then
            return 0
        fi
    done
    return 1
}

export -f error_exit
export -f info
export -f isProductionEnvironment
export -f symlinkSharedDirectory

########################################################################################################################
info "Validation"
########################################################################################################################

[ -f "${RELEASEFOLDER}/pub/index.php" ] || error_exit "Invalid release folder"
[ -f "${RELEASEFOLDER}/bin/magento" ] || error_exit "Could not find bin/magento"
[ -d "${SHAREDFOLDER}" ] || error_exit "Shared directory ${SHAREDFOLDER} not found"
[ -d "${SHAREDFOLDER}" ] || error_exit "Shared directory ${SHAREDFOLDER} not found"
[ -d "${SHAREDFOLDER}" ] || error_exit "Shared directory ${SHAREDFOLDER} not found"

[ -z "${ENVIRONMENT}" ] && error_exit "Please provide an environment code (e.g. -e staging)"
isValidEnvironment

triggerHook "validation"

########################################################################################################################
# Info
########################################################################################################################

echo
echo "##################################################################################################################"
echo
echo "Environment:            ${ENVIRONMENT}"
echo "Release folder:         ${RELEASEFOLDER}"
echo "Skip Systemstorage:     ${SKIP_SYSTEMSTORAGE_IMPORT}"
echo
echo "##################################################################################################################"
echo

########################################################################################################################
info "Linking to shared directories"
########################################################################################################################

symlinkSharedDirectory "pub/media"
symlinkSharedDirectory "generated"
symlinkSharedDirectory "var/log"

triggerHook "symlinks"

########################################################################################################################
info "Set permissions for directories"
########################################################################################################################

chmod -R 774 "${RELEASEFOLDER}"/pub/{media,static} || error_exit "Cannot set permissions for directories"
chmod -R 775 "${RELEASEFOLDER}"/{generated,var} || error_exit "Cannot set permissions for directories"

triggerHook "permissions"

########################################################################################################################
info "Apply configuration settings"
########################################################################################################################

triggerHook "configure"

########################################################################################################################
info "Run upgrade scripts"
########################################################################################################################

cd -P "${RELEASEFOLDER}/" || error_exit "Error while switching to htdocs directory"
php bin/magento setup:upgrade --keep-generated || error_exit "Error while running setup:upgrade"

triggerHook "cleanup"

unset RELEASEFOLDER
unset VALID_ENVIRONMENTS
unset ENVIRONMENT
unset SKIP_SYSTEMSTORAGE_IMPORT
unset SHAREDFOLDER

########################################################################################################################
# Finished
########################################################################################################################

echo -e "\n${BACKGROUND_GREEN} Successfully deployed! ${COLOR_RESET}\n"
