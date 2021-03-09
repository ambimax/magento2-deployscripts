#!/usr/bin/env bats

load helper

function teardown() {
    # remove generated files created by tests
    find "${TEST_WORKSPACE}/releases/build_dummy/artifacts" -type f -delete
    find "${TEST_WORKSPACE}/releases/build_dummy" -name "build.txt" -type f -delete
    find "${TEST_WORKSPACE}/releases/build_dummy" -name "version.txt" -type f -delete
    find "${TEST_WORKSPACE}/releases/build_dummy" -name ".maintenance.flag" -type f -delete
	find "${TEST_WORKSPACE}/tmp" -type f ! -iname ".gitkeep" -delete
	find "${TEST_WORKSPACE}/tmp" -type d -name "package*" -exec rm -rv {} +
}

@test "Validate missing filename" {
    run package.sh
    assert_failure
    assert_output -p "No file name given (--filename)"
}

@test "Validate missing build number" {
    run package.sh --filename project.tar.gz
    assert_failure
    assert_output -p "No build number given (--build)"
}

@test "Build artifacts" {
    run package.sh \
        --source-dir "${TEST_WORKSPACE}/releases/build_dummy" \
        --filename project.tar.gz \
        --build 99
    assert_success
    assert_output -p "Creating base package 'artifacts/project.tar.gz'"
    assert_output -p "Creating extra package 'artifacts/project.extra.tar.gz' with the remaining files"
    assert_output -p "Successfully packaged!"
    [ -f "${TEST_WORKSPACE}/releases/build_dummy/artifacts/project.tar.gz" ]
    [ -f "${TEST_WORKSPACE}/releases/build_dummy/artifacts/project.extra.tar.gz" ]
    [ -f "${TEST_WORKSPACE}/releases/build_dummy/artifacts/MD5SUMS" ]

    run cat "${TEST_WORKSPACE}/releases/build_dummy/artifacts/MD5SUMS"
    assert_output -e '^[a-z0-9]{32}\s{2}.*$'
    assert_output -p "project.tar.gz"
}

@test "Validate hashfile" {
    run package.sh \
        --source-dir "${TEST_WORKSPACE}/releases/build_dummy/" \
        --filename project.tar.gz \
        --build 99 \
        && cat "${TEST_WORKSPACE}/releases/build_dummy/artifacts/MD5SUMS"
    assert_output -p "project.extra.tar.gz"
    assert_output -p "project.tar.gz"
}

@test "Validated generated version.txt" {
    run package.sh --source-dir "${TEST_WORKSPACE}/releases/build_dummy" -f project.tar.gz -b 77 -g 4f9ifk0
    assert_success

    run cat "${TEST_WORKSPACE}/releases/build_dummy/build.txt"
    assert_output "77"

    run cat "${TEST_WORKSPACE}/releases/build_dummy/pub/version.txt"
    assert_output -p "Build: 77"
    assert_output -p "Build time:"
    assert_output -p "Revision: 4f9ifk0"
}

@test "Validate archive contents" {
	run package.sh --target-dir "${TEST_WORKSPACE}/tmp" --source-dir "${TEST_WORKSPACE}/releases/build_dummy" --filename package.tar.gz --build 77
	assert_success
	assert_output -p "Successfully packaged!"
	assert [ -f "${TEST_WORKSPACE}/tmp/MD5SUMS" ]
	assert [ -f "${TEST_WORKSPACE}/tmp/package.tar.gz" ]
	assert [ -f "${TEST_WORKSPACE}/tmp/package.extra.tar.gz" ]

	run mkdir -p "${TEST_WORKSPACE}/tmp/package" && tar -C "${TEST_WORKSPACE}/tmp/package" -zxvf "${TEST_WORKSPACE}/tmp/package.tar.gz"
	assert_success
	assert [ -f "${TEST_WORKSPACE}/tmp/package/composer.json" ]
	assert [ ! -f "${TEST_WORKSPACE}/tmp/package/dev/test.php" ]

	run mkdir -p "${TEST_WORKSPACE}/tmp/package-extra" && tar -C "${TEST_WORKSPACE}/tmp/package-extra" -zxvf "${TEST_WORKSPACE}/tmp/package.extra.tar.gz"
	assert_success
	assert [ ! -f "${TEST_WORKSPACE}/tmp/package-extra/composer.json" ]
	assert [ -f "${TEST_WORKSPACE}/tmp/package-extra/dev/test.php" ]
}
