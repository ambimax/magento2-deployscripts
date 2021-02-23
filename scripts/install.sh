#!/usr/bin/env bash
# Author Tobias Schifftner, https://www.twitter.com/tschifftner

# exit when any command fails
set -e
shopt -s inherit_errexit

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

# Defaults
SCRIPTPATH=$([ -d "${0}" ] && readlink -f "${0}" || echo "")
SCRIPTDIR=$(dirname "${SCRIPTPATH}")
RELEASEFOLDER=$(readlink -f "${SCRIPTDIR}/../../..")
SKIP_SYSTEMSTORAGE_IMPORT=${SKIP_SYSTEMSTORAGE_IMPORT:-true}

function usage {
    echo ""
    echo "Usage:"
    echo "$0 --project-root <projectRoot> --environment <environment> --shared-dir <sharedDir> [--skip-systemstorage-import]"
    echo ""
    echo "   -e|--environment                Environment (i.e. staging, production)"
    echo "   -p|--project-root               Project root / extracted release folder /.../releases/build_20210201"
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
    -p|--project-root)
    RELEASEFOLDER=$(echo "${2}" | sed -e "s/\/*$//")
    shift # past argument
    shift # past value
    ;;
    -s|--shared-dir)
    SHAREDFOLDER=$(echo "${2}" | sed -e "s/\/*$//")
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

export RELEASEFOLDER
export SHAREDFOLDER
export ENVIRONMENT
export SKIP_SYSTEMSTORAGE_IMPORT


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

getHookPath() {
	echo "deploy/${ENVIRONMENT}/${1}.sh"
}

getDefaultHookPath() {
	echo "deploy/defaults/${1}.sh"
}

hasTriggerHook() {
	[[ -x $(getHookPath "$1") ]] || [[ -x $(getDefaultHookPath "$1") ]]
}

triggerHook() {
	[ -d "${RELEASEFOLDER}" ] || error_exit "Invalid release folder ${RELEASEFOLDER}"
	cd -P "${RELEASEFOLDER}" || error_exit "Error while switching to ${RELEASEFOLDER}"
	if [[ -x $(getHookPath "$1") ]]; then
		bash "$(getHookPath "$1")"
	elif [[ -x $(getDefaultHookPath "$1") ]]; then
		bash "$(getDefaultHookPath "$1")"
	fi
}

hookTriggered() {
	hasTriggerHook "$1" && triggerHook "$1"
}

symlinkSharedDirectory() {
    SOURCE="${SHAREDFOLDER}/${1}"
    DEST="${RELEASEFOLDER}/${1}"

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
		[ -z "${HOST}" ] || error_exit "waitFor: Host is missing"
		[ -z "${PORT}" ] || error_exit "waitFor: Port is missing"

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
info "Validation"
########################################################################################################################

if ! hookTriggered "defaultvalidation"; then
	[ -f "${RELEASEFOLDER}/pub/index.php" ] || error_exit "Invalid release folder ${RELEASEFOLDER}"
	[ -f "${RELEASEFOLDER}/bin/magento" ] || error_exit "Could not find bin/magento"

	[ -z "${ENVIRONMENT}" ] && error_exit "Please provide an environment code (e.g. -e staging)"
	[ -d "${RELEASEFOLDER}/deploy/${ENVIRONMENT}" ] || error_exit "Invalid environment: ${ENVIRONMENT} - No deploy/${ENVIRONMENT} directory"
fi

triggerHook "validation"

########################################################################################################################
# Info
########################################################################################################################

echo
echo "##################################################################################################################"
echo
echo "Environment:            ${ENVIRONMENT}"
echo "Project root:         ${RELEASEFOLDER}"
echo "Shared folder:          ${SHAREDFOLDER}"
echo "Skip Systemstorage:     ${SKIP_SYSTEMSTORAGE_IMPORT}"
echo
echo "##################################################################################################################"
echo

########################################################################################################################
info "Linking to shared directories"
########################################################################################################################

if [ -n "${SHAREDFOLDER}" ]; then
	if ! hookTriggered "symlinks"; then
		# default symlinks
		symlinkSharedDirectory "pub/media"
		symlinkSharedDirectory "generated"
		symlinkSharedDirectory "var/log"
	fi
else
	echo "No shared folder set. Skipping symlinks..."
fi

########################################################################################################################
info "Set permissions for directories"
########################################################################################################################

if ! hookTriggered "permissions"; then
	# default folders and permissions
	mkdir -p "${RELEASEFOLDER}"/{pub/{media,static},generated,var} || error_exit "Cannot create default directories"
	chmod -R 774 "${RELEASEFOLDER}"/pub/{media,static} || error_exit "Cannot set permissions for directories"
	chmod -R 775 "${RELEASEFOLDER}"/{generated,var} || error_exit "Cannot set permissions for directories"
fi


########################################################################################################################
info "Apply configuration settings"
########################################################################################################################

triggerHook "configure"


########################################################################################################################
info "Run upgrade scripts"
########################################################################################################################

if ! hookTriggered "upgrade"; then
	echo "No hook upgrade found, therefore default bin/magento setup:upgrade triggered";
	cd -P "${RELEASEFOLDER}/" || error_exit "Error while switching to htdocs directory"
	php bin/magento maintenance:enable
	php bin/magento setup:upgrade --keep-generated || error_exit "Error while running setup:upgrade"
	php bin/magento maintenance:disable
fi


########################################################################################################################
info "Run additional scripts"
########################################################################################################################

triggerHook "post"


########################################################################################################################
# Finished
########################################################################################################################

echo -e "\n${BACKGROUND_GREEN} Successfully deployed! ${COLOR_RESET}\n"

triggerHook "cleanup"

unset RELEASEFOLDER
unset VALID_ENVIRONMENTS
unset ENVIRONMENT
unset SKIP_SYSTEMSTORAGE_IMPORT
unset SHAREDFOLDER
