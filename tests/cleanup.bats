#!/usr/bin/env bats

load helper

function teardown() {
    # remove generated files created by tests
	rm -rf "${TMPDIR}"
}

function setup() {
	export TMPDIR=$(mktemp -d)

	DIRS=(
		"build_20210218113337"
		"build_20210218114707"
		"build_20210225105650"
		"build_20210225131339"
		"build_20210225143149"
		"build_20210225153048"
		"build_20210225182130"
		"build_20210225193721"
		"build_20210304120158"
		"build_20210304193321"
		"build_20210308133843"
		"build_20210218113508"
		"build_20210218115148"
		"build_20210225115604"
		"build_20210308142346"
		"build_20210225133354"
		"build_20210225144511"
		"build_20210225155914"
		"build_20210225184847"
		"build_20210304102847"
		"build_20210304120859"
		"build_20210305115717"
		"build_20210308140802"
		"build_20210218114439"
		"build_20210218133331"
		"build_20210225131009"
		"build_20210225134917"
		"build_20210225145758"
		"build_20210225160051"
		"build_20210225190827"
		"build_20210304113532"
		"build_20210304123554"
		"build_20210308100013"
	)

	for BUILD_DIR in "${DIRS[@]}"; do
		mkdir -p "${TMPDIR}/${BUILD_DIR}"
	done

	# Add current symlink
	ln -s -v "${TMPDIR}/build_20210308142346" "${TMPDIR}/current"

	# Some output for debugging
	ls -lah "${TMPDIR}"
	echo ""
	echo "Last 10"
	ls "${TMPDIR}/" | sort -k2 -t_ -n -r | head -10
}

@test "Validate release dir not set" {
    run cleanup.sh
    assert_failure
    assert_output -p "Releases dir not set (-r|--releases-dir)"
}

@test "Validate non-existing release dir" {
	DIR=$(mktemp)
    run cleanup.sh --releases-dir "${DIR}"
    assert_failure
    assert_output -p "Releases dir '${DIR}' not found"
}

@test "Validate missing current symlink" {
	DIR=$(mktemp -d)
    run cleanup.sh --releases-dir "${DIR}"
    assert_failure
    assert_output -p "No current symlink found in ${DIR}"
}

@test "Remove default" {
    run cleanup.sh --releases-dir "${TMPDIR}" --releases-to-keep 10
    assert_success
    assert_output -p "Cleanup finished. 23 old builds removed!"

	assert [ -L "${TMPDIR}/current" ]

	assert [ -d "${TMPDIR}/build_20210308142346" ]
	assert [ -d "${TMPDIR}/build_20210308140802" ]
	assert [ -d "${TMPDIR}/build_20210308133843" ]
	assert [ -d "${TMPDIR}/build_20210308100013" ]
	assert [ -d "${TMPDIR}/build_20210305115717" ]
	assert [ -d "${TMPDIR}/build_20210304193321" ]
	assert [ -d "${TMPDIR}/build_20210304123554" ]
	assert [ -d "${TMPDIR}/build_20210304120859" ]
	assert [ -d "${TMPDIR}/build_20210304120158" ]
	assert [ -d "${TMPDIR}/build_20210304113532" ]

	assert [ ! -d "${TMPDIR}/build_20210225184847" ]
}

@test "Keep only 5 releases " {
    run cleanup.sh --releases-dir "${TMPDIR}" --releases-to-keep 5
    assert_success
    assert_output -p "Cleanup finished. 28 old builds removed!"

	assert [ -L "${TMPDIR}/current" ]

	assert [ -d "${TMPDIR}/build_20210308142346" ]
	assert [ -d "${TMPDIR}/build_20210308140802" ]
	assert [ -d "${TMPDIR}/build_20210308133843" ]
	assert [ -d "${TMPDIR}/build_20210308100013" ]
	assert [ -d "${TMPDIR}/build_20210305115717" ]

	assert [ ! -d "${TMPDIR}/build_20210304193321" ]
	assert [ ! -d "${TMPDIR}/build_20210304123554" ]
	assert [ ! -d "${TMPDIR}/build_20210304120859" ]
	assert [ ! -d "${TMPDIR}/build_20210304120158" ]
	assert [ ! -d "${TMPDIR}/build_20210304113532" ]
}

@test "Symlinked directories are ignored" {
	ln -s -v "${TMPDIR}/build_20210304193321" "${TMPDIR}/last"

    run cleanup.sh --releases-dir "${TMPDIR}" --releases-to-keep 5
    assert_success
    assert_output -p "Cleanup finished. 27 old builds removed!"

	assert [ -L "${TMPDIR}/current" ]
	assert [ -L "${TMPDIR}/last" ]

	assert [ -d "${TMPDIR}/build_20210304193321" ]
	assert [ -d "${TMPDIR}/build_20210308142346" ]
	assert [ -d "${TMPDIR}/build_20210308140802" ]
	assert [ -d "${TMPDIR}/build_20210308133843" ]
	assert [ -d "${TMPDIR}/build_20210308100013" ]
	assert [ -d "${TMPDIR}/build_20210305115717" ]

	assert [ ! -d "${TMPDIR}/build_20210304123554" ]
	assert [ ! -d "${TMPDIR}/build_20210304120859" ]
	assert [ ! -d "${TMPDIR}/build_20210304120158" ]
	assert [ ! -d "${TMPDIR}/build_20210304113532" ]
}

@test "Dry run mode" {
    run cleanup.sh --releases-dir "${TMPDIR}" --releases-to-keep 5 --dry-run
    assert_success
    assert_output -p "Cleanup finished. 0 old builds removed!"

	assert [ -L "${TMPDIR}/current" ]

	assert [ -d "${TMPDIR}/build_20210304193321" ]
	assert [ -d "${TMPDIR}/build_20210308142346" ]
	assert [ -d "${TMPDIR}/build_20210308140802" ]
	assert [ -d "${TMPDIR}/build_20210308133843" ]
	assert [ -d "${TMPDIR}/build_20210308100013" ]
	assert [ -d "${TMPDIR}/build_20210305115717" ]
	assert [ -d "${TMPDIR}/build_20210304123554" ]
	assert [ -d "${TMPDIR}/build_20210304120859" ]
	assert [ -d "${TMPDIR}/build_20210304120158" ]
	assert [ -d "${TMPDIR}/build_20210304113532" ]
}
