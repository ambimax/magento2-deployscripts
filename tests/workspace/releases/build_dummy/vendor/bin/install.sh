#!/usr/bin/env bash

echo "Composer installer..."

echo "v2"

export PROJECT_ROOT=${PROJECT_ROOT:-}
export SHARED_DIR=${SHARED_DIR:-}
export SKIP_SYSTEMSTORAGE_IMPORT=${SKIP_SYSTEMSTORAGE_IMPORT:-}

echo "$#"
echo "$@"

while [[ $# -gt 0 ]]
do
key="$1"
echo "$1 => $2"
case $key in
    -p|--project-root)
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
    export ENVIRONMENT="$2"
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
    # *)    # unknown option
    # POSITIONAL+=("$1") # save it in an array for later
    # shift # past argument
    # ;;
esac
done
# set -- "${POSITIONAL[@]}" # restore positional parameters

# Output install.sh variables for testing
printenv
