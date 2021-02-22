#!/usr/bin/env bash

# Set PATH variable for local or docker
[ -d /scripts ] && PATH="${PATH}:/scripts" || PATH="${PATH}:scripts"

# Variables
export TEST_WORKSPACE="${PWD}/tests/workspace"

# Mocks
function php() {
	echo "command:triggered:php $*"
}

export -f php
