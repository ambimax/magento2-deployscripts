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

    run install.sh --project-root /www
    assert_failure
    assert_output -p "Invalid release folder"
}

@test "Validate missing environment variable" {
    run install.sh --project-root "${TEST_WORKSPACE}/releases/build_dummy/"
    assert_failure
    assert_output -p "Please provide an environment code"
}

@test "Validate illegal environment variable" {
    run install.sh --project-root "${TEST_WORKSPACE}/releases/build_dummy" --environment feature
    assert_failure
    assert_output -p "Invalid environment: feature"
}

@test "Successfully release" {
    run install.sh --project-root "${TEST_WORKSPACE}/releases/build_dummy" --environment staging
    assert_success
    assert_output -p "Successfully deployed!"
}

@test "hooks are triggering" {
    run install.sh --project-root "${TEST_WORKSPACE}/releases/build_dummy" --environment staging
    assert_success
    assert_output -p "hook:validation:triggered"
}

@test "test environment variables" {
    run install.sh --project-root "${TEST_WORKSPACE}/releases/build_dummy" --environment test
    assert_success
    assert_output -p "RELEASEFOLDER=${TEST_WORKSPACE}/releases/build_dummy"
    assert_output -p "ENVIRONMENT=test"
    assert_output -p "SKIP_SYSTEMSTORAGE_IMPORT=true"
	assert_output -p "command:triggered:php bin/magento setup:upgrade --keep-generated"
}

@test "test is staging environment" {
    run install.sh --project-root "${TEST_WORKSPACE}/releases/build_dummy" --environment staging
    assert_success
    assert_output -p "hook:validation:triggered"
    assert_output -p "hook:configure:triggered"
	assert_output -p "command:triggered:php bin/magento setup:upgrade --keep-generated"
	assert_output -p "Is staging environment"
}

@test "test is production environment" {
    run install.sh --project-root "${TEST_WORKSPACE}/releases/build_dummy" --environment production
    assert_success
    assert_output -p "hook:validation:triggered"
    assert_output -p "Is production environment"
}

@test "test default environment" {
    run install.sh --project-root "${TEST_WORKSPACE}/releases/build_dummy" --environment production
    assert_success
    assert_output -p "hook:defaults::configure:triggered"
    assert_output -p "configure in defaults/ triggered"
}

@test "waitfor succeeds" {
	run install.sh --project-root "${TEST_WORKSPACE}/releases/build_dummy" --environment waitforsuccess
	assert_success
	assert_output -p "waitFor:command:succeeded"
}

@test "waitfor fails" {
	run install.sh --project-root "${TEST_WORKSPACE}/releases/build_dummy" --environment waitforfail
	assert_failure
	assert_output -p "waiting 1 seconds for /usr/local/nonexisting"
	assert_output -p "Waiting failed... bash: /usr/local/nonexisting: No such file or directory"
}
