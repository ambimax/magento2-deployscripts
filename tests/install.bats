#!/usr/bin/env bats

load helper

function teardown() {
    # remove symlinks created by tests
    find "${TEST_WORKSPACE}/releases/build_dummy" -type l -delete
}

@test "Validate missing release folder" {
    run install.sh
    assert_failure
    assert_output -p "Invalid project root /"

    run install.sh --project-root /www
    assert_failure
    assert_output -p "Invalid project root /www"
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
    assert_output -p "Installation was successful!"
}

@test "hooks are triggering" {
    run install.sh --project-root "${TEST_WORKSPACE}/releases/build_dummy" --environment hooks
    assert_success
    assert_output -p "hook:pre:triggered"
    assert_output -p "hook:pre-install:triggered"
    assert_output -p "hook:install:triggered"
    assert_output -p "hook:post-install:triggered"
    assert_output -p "hook:cleanup:triggered"
}

# @test "non-executable hooks warning" {
#     run install.sh --project-root "${TEST_WORKSPACE}/releases/build_dummy" --environment test
#     assert_success
# 	assert [[ -f  "${TEST_WORKSPACE}/releases/build_dummy/deploy/test/permissions.sh" ]]
# 	assert [[ ! -x  "${TEST_WORKSPACE}/releases/build_dummy/deploy/test/permissions.sh" ]]
#     assert_output -p "Non-executable hook "
# }

@test "test environment variables" {
    run install.sh --project-root "${TEST_WORKSPACE}/releases/build_dummy" --environment test --skip-systemstorage-import
    assert_success
    assert_output -p "PROJECT_ROOT=${TEST_WORKSPACE}/releases/build_dummy"
    assert_output -p "ENVIRONMENT=test"
    assert_output -p "SKIP_SYSTEMSTORAGE_IMPORT=true"
	assert_output -p "command:triggered:php bin/magento setup:upgrade --keep-generated"
}

@test "test global environment variables" {
	export ENVIRONMENT="test"
	export PROJECT_ROOT="${TEST_WORKSPACE}/releases/build_dummy"
	export SHARED_DIR="${TEST_WORKSPACE}/shared"
	export SKIP_SYSTEMSTORAGE_IMPORT="true"
    run install.sh
    assert_success
    assert_output -p "ENVIRONMENT=test"
    assert_output -p "PROJECT_ROOT=${TEST_WORKSPACE}/releases/build_dummy"
    assert_output -p "SKIP_SYSTEMSTORAGE_IMPORT=true"
    assert_output -p "SHARED_DIR=${TEST_WORKSPACE}/shared"
	assert_output -p "command:triggered:php bin/magento setup:upgrade --keep-generated"
}

@test "test is staging environment" {
    run install.sh --project-root "${TEST_WORKSPACE}/releases/build_dummy" --environment staging
    assert_success
	assert_output -p "command:triggered:php bin/magento setup:upgrade --keep-generated"
	assert_output -p "Is staging environment"
}

@test "test is production environment" {
    run install.sh --project-root "${TEST_WORKSPACE}/releases/build_dummy" --environment production
    assert_success
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
