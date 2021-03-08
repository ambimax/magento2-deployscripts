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
SCRIPTPATH=$([ -d "${0}" ] && readlink -f "${0}" || echo "")
SCRIPTDIR=$(dirname "${SCRIPTPATH}")
FALLBACK_PROJECT_ROOT=$(readlink -f "${SCRIPTDIR}/../../..")
PROJECT_ROOT=${PROJECT_ROOT:-"${FALLBACK_PROJECT_ROOT}"}
SKIP_SYSTEMSTORAGE_IMPORT=${SKIP_SYSTEMSTORAGE_IMPORT:-false}
ENVIRONMENT=${ENVIRONMENT:-}
SHARED_DIR=${SHARED_DIR:-}

function usage {
    echo ""
    echo "Usage:"
    echo "$0 --project-root <projectRoot> --environment <environment> --shared-dir <sharedDir> [--skip-systemstorage-import]"
    echo ""
    echo "   -e|--environment                Environment (i.e. staging, production)"
    echo "   -r|--project-root               Project root / extracted release folder /.../releases/build_20210201"
    echo "   -s|--shared-dir                 Shared folder /.../shared/"
    echo "   --skip-systemstorage-import     Also download and install .extra.tar.gz package"
    echo ""
    exit 0
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -r|--project-root)
    PROJECT_ROOT=$(echo "${2}" | sed -e "s/\/*$//")
    shift # past argument
    shift # past value
    ;;
    -s|--shared-dir)
    SHARED_DIR=$(echo "${2}" | sed -e "s/\/*$//")
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
# [ -n "${POSITIONAL[*]}" ] && set -- "${POSITIONAL[*]}" # restore positional parameters

export PROJECT_ROOT
export SHARED_DIR
export ENVIRONMENT
export SKIP_SYSTEMSTORAGE_IMPORT


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
    echo -e "$1"
    echo -e "########################################################################################################################"
    echo -e "${COLOR_RESET}"
}

getHookPath() {
	echo "deploy/${ENVIRONMENT}/${1}.sh"
}

getDefaultHookPath() {
	echo "deploy/defaults/${1}.sh"
}

hasTriggerHook() {
	[[ -x $(getHookPath "$1") ]] || [[ -x $(getDefaultHookPath "$1") ]]
}

getTriggerHook() {
	if [[ -f $(getHookPath "$1") ]]; then
		[[ ! -x $(getHookPath "$1") ]] && warning ""
	fi
}

triggerHook() {
	[ -d "${PROJECT_ROOT}" ] || error_exit "Invalid project root ${PROJECT_ROOT}"
	cd -P "${PROJECT_ROOT}" || error_exit "Error while switching to ${PROJECT_ROOT}"

	if [[ -x $(getHookPath "$1") ]]; then
		bash "$(getHookPath "$1")" || exit 1
		return 0
	elif [[ -x $(getDefaultHookPath "$1") ]]; then
		bash "$(getDefaultHookPath "$1")" || exit 1
		return 0
	fi

	echo "No hook found for $1"
}

hookTriggered() {
	hasTriggerHook "$1" && triggerHook "$1"
}

symlinkSharedDirectory() {
    SOURCE="${SHARED_DIR}/${1}"
    DEST="${PROJECT_ROOT}/${1}"

    echo "Symlinking ${SOURCE} to ${DEST}"

    [ ! -d "${SOURCE}" ] && error_exit "Shared directory ${SOURCE} not found"
    [ -d "${DEST}" ] && rm -rf "${DEST}"

    ln -s "${SOURCE}" "${DEST}" || error_exit "Error while symlinking ${SOURCE} to ${DEST}"
}

waitFor() {
	TIMEOUT=15
	HOST=
	PORT=
	counter=1
	PROTOCOL="tcp"

	# parse arguments
	while [[ $# -gt 0 ]]; do
	key="$1"

	case $key in
		-c|--command)
		COMMAND="${2}"
		shift # past argument
		shift # past value
		;;
		-h|--host)
		HOST="${2}"
		shift # past argument
		shift # past value
		;;
		-p|--port)
		PORT="$2"
		shift # past argument
		shift # past value
		;;
		-t|--timeout)
		TIMEOUT="${2}"
		shift # past argument
		shift # past value
		;;
		--tcp)
		PROTOCOL="tcp"
		shift # past argument
		;;
		--upd)
		PROTOCOL="upd"
		shift # past argument
		;;
		*)    # unknown option
		shift # past argument
		;;
	esac
	done

	# Validation
	if [ -z "${COMMAND}" ]; then
		[ -n "${HOST}" ] || error_exit "waitFor: Host ${HOST} is missing"
		[ -n "${PORT}" ] || error_exit "waitFor: Port ${PORT} is missing"

		COMMAND="echo > /dev/${PROTOCOL}/${HOST}/${PORT}"
	fi

	[ -n "${COMMAND}" ] || error_exit "waitFor: Command is missing"

	# Wait for command
	echo "waiting ${TIMEOUT} seconds for ${COMMAND}"
	until ERROR=$(bash -c "${COMMAND}" 2>&1); do
		[ $counter -lt "${TIMEOUT}" ] || error_exit "Waiting failed... ${ERROR}"
		sleep 1
		((counter=counter+1))
	done

	echo -e " ${COLOR_GREEN}done${COLOR_RESET}"
}

export -f error_exit
export -f info
export -f symlinkSharedDirectory
export -f waitFor

triggerHook "pre"

########################################################################################################################
# Info
########################################################################################################################

echo
echo "##################################################################################################################"
echo
echo "Environment:            ${ENVIRONMENT}"
echo "Project root:           ${PROJECT_ROOT}"
echo "Shared folder:          ${SHARED_DIR}"
echo "Skip Systemstorage:     ${SKIP_SYSTEMSTORAGE_IMPORT}"
echo
echo "##################################################################################################################"
echo

########################################################################################################################
info "Validation"
########################################################################################################################

if ! hookTriggered "defaultvalidation"; then
	[ -f "${PROJECT_ROOT}/pub/index.php" ] || error_exit "Invalid project root ${PROJECT_ROOT}"
	[ -f "${PROJECT_ROOT}/bin/magento" ] || error_exit "Could not find bin/magento"

	[ -z "${ENVIRONMENT}" ] && error_exit "Please provide an environment code (e.g. -e staging)"
	[ -d "${PROJECT_ROOT}/deploy/${ENVIRONMENT}" ] || error_exit "Invalid environment: ${ENVIRONMENT} - No deploy/${ENVIRONMENT} directory"
fi


########################################################################################################################
info "Run installation"
########################################################################################################################

triggerHook "pre-install"

if ! hookTriggered "install"; then
	# default symlinks
	if [ -n "${SHARED_DIR}" ]; then
		symlinkSharedDirectory "pub/media"
		symlinkSharedDirectory "var/log"
		symlinkSharedDirectory "var/session"
	fi

	# default folders and permissions
	mkdir -p "${PROJECT_ROOT}"/{pub/{media,static/_cache},generated,var} || error_exit "Cannot create default directories"
	chmod -R 774 "${PROJECT_ROOT}"/pub/{media,static} || error_exit "Cannot set permissions for directories"
	chmod -R 775 "${PROJECT_ROOT}"/{generated,var} || error_exit "Cannot set permissions for directories"

	# Enable maintenance
	php bin/magento maintenance:enable

	# load config
	php bin/magento app:config:import --no-interaction || error_exit "Error while running app:config:import"

	# Upgrade
	php bin/magento setup:upgrade --keep-generated --no-interaction \
		|| error_exit "Error while running setup:upgrade --keep-generated"

	php bin/magento maintenance:disable
fi

triggerHook "post-install"


########################################################################################################################
# Finished
########################################################################################################################

echo -e "\n${SUCCESS_COLOR} Installation was successful! ${COLOR_RESET}\n"

triggerHook "cleanup"

unset PROJECT_ROOT
unset VALID_ENVIRONMENTS
unset ENVIRONMENT
unset SKIP_SYSTEMSTORAGE_IMPORT
unset SHARED_DIR
