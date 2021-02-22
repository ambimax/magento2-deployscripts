#!/usr/bin/env bats

load helper

function teardown() {
    # remove symlinks created by tests
    find "${TEST_WORKSPACE}/releases/build_dummy" -type l -delete
}

@test "Validate missing release folder" {
    run install.sh
    assert_failure
    assert_output -p "Invalid release folder"

    run install.sh --release-dir /www
    assert_failure
    assert_output -p "Invalid release folder"
}

@test "Validate missing environment variable" {
    run install.sh --release-dir "${TEST_WORKSPACE}/releases/build_dummy/"
    assert_failure
    assert_output -p "Please provide an environment code"
}

@test "Validate illegal environment variable" {
    run install.sh --release-dir "${TEST_WORKSPACE}/releases/build_dummy" --environment feature
    assert_failure
    assert_output -p "Illegal environment code"
}

@test "Successfully release" {
    run install.sh --release-dir "${TEST_WORKSPACE}/releases/build_dummy" --environment staging
    assert_success
    assert_output -p "Successfully deployed!"
}

@test "hooks are triggering" {
    run install.sh --release-dir "${TEST_WORKSPACE}/releases/build_dummy" --environment staging
    assert_success
    assert_output -p "hook:validation:triggered"
}

@test "test environment variables" {
    run install.sh --release-dir "${TEST_WORKSPACE}/releases/build_dummy" --environment test
    assert_success
    assert_output -p "RELEASEFOLDER=${TEST_WORKSPACE}/releases/build_dummy"
    assert_output -p "ENVIRONMENT=test"
    assert_output -p "SHAREDFOLDER=${TEST_SHAREDPATH}"
    assert_output -p "SKIP_SYSTEMSTORAGE_IMPORT=true"
	assert_output -p "command:triggered:php bin/magento setup:upgrade --keep-generated"
}

@test "test is staging environment" {
    run install.sh --release-dir "${TEST_WORKSPACE}/releases/build_dummy" --environment staging
    assert_success
    assert_output -p "hook:validation:triggered"
    assert_output -p "hook:configure:triggered"
	assert_output -p "command:triggered:php bin/magento setup:upgrade --keep-generated"
	assert_output -p "Is staging environment"
}

@test "test is production environment" {
    run install.sh --release-dir "${TEST_WORKSPACE}/releases/build_dummy" --environment production
    assert_success
    assert_output -p "hook:validation:triggered"
    assert_output -p "Is production environment"
}
