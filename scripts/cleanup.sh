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
RELEASES_TO_KEEP=10
RELEASES_DIR=
DRY_RUN=false

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


function usage {
    echo ""
    echo "Usage:"
    echo "$0 --releases-dir <releasesDir> --releases-to-keep <number>"
    echo ""
    echo "   -r|--releases-dir           Releases dir"
    echo "   -n|--releases-to-keep       Releases to keep, default: 10"
	echo ""
    exit 0
}

POSITIONAL=()
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -n|--releases-to-keep)
    RELEASES_TO_KEEP="$2"
    shift # past argument
    shift # past value
    ;;
    -r|--releases-dir)
    RELEASES_DIR="${2%/}"
    shift # past argument
    shift # past value
    ;;
    -h|--help)
    usage
    shift # past argument
    ;;
    -d|--dry-run)
    DRY_RUN=true
    shift # past argument
    ;;
    *)    # unknown option
    POSITIONAL+=("$1") # save it in an array for later
    shift # past argument
    ;;
esac
done
[ "${#POSITIONAL[@]}" -eq 0 ] || set -- "${POSITIONAL[@]}" # restore positional parameters

function inArray() {
	KEY=$1; shift;
	STACK=( "$@" )
	for ITEM in "${STACK[@]}"; do
        if [ "${KEY}" == "$ITEM" ]; then
			return 0;
        fi;
    done;
	return 1
}

echo -e "\n${COLOR_GREEN}■ cleanup.sh \nTobias Schifftner (@tschifftner), Ambimax GmbH\ngithub.com/ambimax"

########################################################################################################################
info "Validation"
########################################################################################################################

# Check if releases folder exists
[ -n "${RELEASES_DIR}" ] || error_exit "Releases dir not set (-r|--releases-dir)"
[ -d "${RELEASES_DIR}" ] || error_exit "Releases dir '${RELEASES_DIR}' not found"
[ -L "${RELEASES_DIR}/current" ] || error_exit "No current symlink found in ${RELEASES_DIR}"

echo "OK"

########################################################################################################################
info "Remove old deployments"
########################################################################################################################

BUILDS=()
while IFS=  read -r -d $'\0'; do BUILDS+=( "$REPLY" ); done < <(find "${RELEASES_DIR}" -maxdepth 1 -name 'build_*' -type d -print0 | sort -k2 -t_ -n -r -z)

SYMLINKS=()
while IFS=  read -r -d $'\0'; do SYMLINKS+=( "$(readlink -f "$REPLY")" ); done < <(find "${RELEASES_DIR}" -maxdepth 1 -type l -print0)

LATEST_BUILDS=("${BUILDS[@]:0:${RELEASES_TO_KEEP}}")
BUILDS_TO_IGNORE=("${LATEST_BUILDS[@]}" "${SYMLINKS[@]}")

deleted=0
for BUILD in "${BUILDS[@]}"; do

	if inArray "$BUILD" "${BUILDS_TO_IGNORE[@]}"; then
		echo -e "${SUCCESS_COLOR} skipping ${COLOR_RESET} Skipping $BUILD"
	else
		if [ "${DRY_RUN}" = "true" ]; then
			echo -e "${WARNING_COLOR} DRY RUN  ${COLOR_RESET} Deleting old deployment $BUILD"
		else
			echo "Deleting old deployment $BUILD"
        	rm -rf "$BUILD" || warning "Cannot remove directory $BUILD"
			((deleted=deleted+1))
		fi
	fi
done


########################################################################################################################
# Finished
########################################################################################################################

echo -e "\n${SUCCESS_COLOR} Cleanup finished. ${deleted} old builds removed! ${COLOR_RESET}\n"
