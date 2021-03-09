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
export WARNING_COLOR="\e[41;1;37m"
export SUCCESS_COLOR="\e[30;48;5;82m"

# Defaults
INSTALL_EXTRA_PACKAGE=0
AWS_ARGS=
AWS_PROFILE=
ENVIRONMENT=
TARGET_DIR=
PACKAGE_URL=

########################################################################################################################
# Functions
########################################################################################################################

error_exit() {
	echo -e "\n${ERROR_COLOR} ${1} ${COLOR_RESET}"
    exit 1;
}

warning() {
	echo -e "\n${WARNING_COLOR} ${1} ${COLOR_RESET}"
}

info() {
    echo -e "${COLOR_GREEN}"
    echo -e "########################################################################################################################"
    echo -e " $1"
    echo -e "########################################################################################################################"
    echo -e "${COLOR_RESET}"
}

copyFile() {
    echo "Copying package ${1} to ${2}"
    cp "${1}" "${2}" || error_exit "Cannot copy"
}

downloadFile() {
    echo "Download package ${1} to ${2}"
    wget --auth-no-challenge "${WGET_ARGS}" "${1}" -O "${2}" || error_exit "Error while downloading ${1}"
}

downloadS3File() {
    echo "Download S3 package ${1} to ${2}"
    aws "${AWS_ARGS}" s3 cp "${1}" "${2}" || error_exit "Error while downloading ${1} from S3"
}

function usage {
    echo ""
    echo "Usage:"
    echo "$0 --package-url <packageUrl> --target-dir <targetDir>  --environment <environment> [--aws-profile <profile>] [--install-extra-package]"
    echo ""
    echo "   -e|--environment            Environment (i.e. staging, production)"
    echo "   -p|--package-url            Package url (https, S3 or local file)"
    echo "   -t|--target-dir             Target dir (root of releases/ and current/)"
    echo "   --install-extra-package     Also download and install .extra.tar.gz package"
    echo ""
    echo "   --aws-profile               AWS profile name"
    echo '   --wget-args                 Wget arguments like --wget-args "--user=USERNAME --password=PASSWORD"'
    echo ""
    echo ""
    echo " All environment variables and unused parameters will be send to vendor/bin/install.sh:"
    echo ""
    echo "   -p|--project-root             Project dir - will be set by CURRENT_RELEASE_DIR (i.e. <targetDir>/releases/build_2020202020)"
    echo "   -s|--shared-dir               Shared dir (root of pub/media/ and var/log/)"
    echo "   --skip-systemstorage-import   Skip systemstorage import"
    echo ""
    exit 0
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -p|--package-url)
    PACKAGE_URL="$2"
    shift # past argument
    shift # past value
    ;;
    -t|--target-dir)
    TARGET_DIR="${2%/}"
    shift # past argument
    shift # past value
    ;;
    -e|--environment)
    ENVIRONMENT="$2"
    shift # past argument
    shift # past value
    ;;
    --aws-profile)
    AWS_PROFILE="$2"
    shift # past argument
    shift # past value
    ;;
    --install-extra-package)
    INSTALL_EXTRA_PACKAGE=1
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
[ "${#POSITIONAL[@]}" -eq 0 ] || set -- "${POSITIONAL[@]}" # restore positional parameters

# Define folders
RELEASES_DIR="${TARGET_DIR}/releases"
CURRENT_RELEASE_NAME="build_$(date +%Y%m%d%H%M%S)"
CURRENT_RELEASE_DIR="${RELEASES_DIR}/${CURRENT_RELEASE_NAME}"

EXTRAPACKAGE_URL=${PACKAGE_URL/.tar.gz/.extra.tar.gz}

if [ -n "${AWS_PROFILE}" ] ; then
    AWS_ARGS="--profile ${AWS_PROFILE}"
fi

export RELEASES_DIR
export CURRENT_RELEASE_NAME
export CURRENT_RELEASE_DIR
export ENVIRONMENT

echo -e "\n${COLOR_GREEN}■ deploy.sh \nTobias Schifftner (@tschifftner), Ambimax GmbH\ngithub.com/ambimax"

########################################################################################################################
info "Validation"
########################################################################################################################

[ -z "${PACKAGE_URL}" ] && error_exit "Package url not set (-p|--package-url)"
[ -z "${TARGET_DIR}" ] && error_exit "Target directory not set (-t|--target-dir)"
[ -z "${ENVIRONMENT}" ] && error_exit "Environment not set (-e|--environment)"

# Check if releases folder exists
[ -d "${RELEASES_DIR}" ] || error_exit "Releases dir ${RELEASES_DIR} not found"
[ -d "${CURRENT_RELEASE_DIR}" ] && error_exit "Release folder ${CURRENT_RELEASE_DIR} already exists"


########################################################################################################################
# Info
########################################################################################################################

echo
echo "##################################################################################################################"
echo
echo "Package url:            ${PACKAGE_URL}"
echo "Target dir:             ${TARGET_DIR}"
echo "Environment:            ${ENVIRONMENT}"
echo
echo "Release folder:         ${CURRENT_RELEASE_DIR}"
echo
echo "##################################################################################################################"
echo

########################################################################################################################
# Create tmp dir and make sure it's going to be deleted in any case
########################################################################################################################

TMPDIR=$(mktemp -d)
function cleanup {
    echo "Removing temp dir ${TMPDIR}"
    rm -rf "${TMPDIR}"
}

trap cleanup EXIT


########################################################################################################################
info "Retrieving package"
########################################################################################################################

if [ -f "${PACKAGE_URL}" ] ; then
    copyFile "${PACKAGE_URL}" "${TMPDIR}/package.tar.gz"
    [ "${INSTALL_EXTRA_PACKAGE}" == 1 ] && copyFile "${EXTRAPACKAGE_URL}" "${TMPDIR}/package.extra.tar.gz"
elif [[ "${PACKAGE_URL}" =~ ^https?:// ]] ; then
    downloadFile "${PACKAGE_URL}" "${TMPDIR}/package.tar.gz"
    [ "${INSTALL_EXTRA_PACKAGE}" == 1 ] && downloadFile "${EXTRAPACKAGE_URL}" "${TMPDIR}/package.extra.tar.gz"
elif [[ "${PACKAGE_URL}" =~ ^s3:// ]] ; then
    downloadS3File "${PACKAGE_URL}" "${TMPDIR}/package.tar.gz"
    [ "${INSTALL_EXTRA_PACKAGE}" == 1 ] && downloadS3File "${EXTRAPACKAGE_URL}" "${TMPDIR}/package.extra.tar.gz"
else
    error_exit "Package \"${PACKAGE_URL}\" not found"
fi


########################################################################################################################
info "Extract package into ${CURRENT_RELEASE_DIR}"
########################################################################################################################

mkdir "${CURRENT_RELEASE_DIR}" || error_exit "Error while creating current release folder"

echo "Extracting base package"
tar xzf "${TMPDIR}/package.tar.gz" -C "${CURRENT_RELEASE_DIR}" || error_exit "Error while extracting base package"

if [ "${INSTALL_EXTRA_PACKAGE}" == 1 ] ; then
    echo "Extracting extra package on top of base package"
    tar xzf "${TMPDIR}/package.extra.tar.gz" -C "${CURRENT_RELEASE_DIR}" || error_exit "Error while extracting extra package"
fi


########################################################################################################################
info "Trigger installation"
########################################################################################################################

COMPOSER_INSTALLER="${CURRENT_RELEASE_DIR}/vendor/bin/install.sh"
if [ -f "${COMPOSER_INSTALLER}" ]; then
    echo "Starting composer installer"
	export PROJECT_ROOT="${CURRENT_RELEASE_DIR}"
	bash "${COMPOSER_INSTALLER}" "$@" || error_exit "Composer installer failed"
fi


########################################################################################################################
info "Update symlink to be live"
########################################################################################################################

echo "Settings current (${RELEASES_DIR}/current) to release folder (${CURRENT_RELEASE_DIR})"
ln -sfn "${CURRENT_RELEASE_DIR}" "${RELEASES_DIR}/current" || error_exit "Error while symlinking 'current' to release folder"

########################################################################################################################
# Finished
########################################################################################################################

echo -e "\n${SUCCESS_COLOR} Successfully deployed! ${COLOR_RESET}\n"
