#!/usr/bin/env bats

load helper

function teardown() {
    # remove symlinks created by tests
    find "${TEST_WORKSPACE}/releases" -type d -name "build_2*" -exec rm -rv {} +
    find "${TEST_WORKSPACE}" -type l -name "current" -delete
}

@test "Assert package url" {
    run deploy.sh
    assert_failure
    assert_output -p "Package url not set (-p|--package-url)"
}

@test "Assert target dir" {
    run deploy.sh --package-url "test"
    assert_failure
    assert_output -p "Target directory not set (-t|--target-dir)"
}

@test "Assert environment" {
    run deploy.sh --package-url "test" --target-dir /var/www
    assert_failure
    assert_output -p "Environment not set (-e|--environment)"
}

@test "Assert releases dir" {
    run deploy.sh --package-url "test" --target-dir /var --environment staging
    assert_failure
    assert_output -p "Releases dir /var/releases not found"
}

@test "Assert package not found" {
    run deploy.sh --package-url "test" --target-dir "${TEST_WORKSPACE}" --environment staging
    assert_failure
    assert_output -p 'Package "test" not found'
}

@test "Download package (local), extract, run composer installer" {
    run deploy.sh --package-url "${TEST_WORKSPACE}/artifacts/project.tar.gz" --target-dir "${TEST_WORKSPACE}" --environment staging
    assert_success
    assert_output -p "Starting composer installer"
    assert_output -p "Composer installer..."
}
