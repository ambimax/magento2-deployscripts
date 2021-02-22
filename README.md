# ambimax/magento2-deployscripts

Bash scripts for packaging Magento2 projects and deploying it as releases on any server.

- [ambimax/magento2-deployscripts](#ambimaxmagento2-deployscripts)
  - [Deployment Workflow](#deployment-workflow)
  - [Quick Usage](#quick-usage)
    - [Package](#package)
    - [Deploy](#deploy)
    - [Install](#install)
  - [Project setup](#project-setup)
    - [Setup installation](#setup-installation)
    - [Package](#package-1)
    - [Deploy](#deploy-1)
  - [Hooks](#hooks)
    - [Sample hook](#sample-hook)
  - [Functions available within hooks](#functions-available-within-hooks)
    - [error_exit](#error_exit)
    - [info](#info)
    - [symlinkSharedDirectory](#symlinkshareddirectory)

## Deployment Workflow

1. Package project to project.tar.gz with `package.sh`
2. Upload project.tar.gz to remote location like S3
3. Trigger `deploy.sh` on server
   1. File is downloaded and extracted release/build_2020010202002
   2. Execute vendor/bin/install.sh if file exists
   3. Symlink "current" is set to release/build_2020010202002

## Quick Usage

### Package

```bash
./scripts/package.sh \
  --source-dir "${PWD}/tests/workspace/releases/build_dummy/" \
  --build 99 \
  --git-revision 37ed7a1 \
  --filename project.tar.gz
```

### Deploy

```bash
./scripts/deploy.sh \
  --package-url "tests/workspace/artifacts/project.tar.gz" \
  --target-dir /workspace/tests/workspace/ \
  --environment staging
```

Triggers composer install (vendor/bin/install.sh)

### Install

```bash
./scripts/install.sh \
  --release-dir "${PWD}/tests/workspace/releases/build_dummy" \
  --environment staging
```

## Project setup

### Setup installation

Add magento2-deployscripts to Magento 2 project

```bash
composer require ambimax/magento2-deployscripts=^1.0.0
```

Add configure hooks to your project (see Hooks)

```bash
mkdir -p deploy/{production,staging}/;
{ echo '#!/usr/bin/env bash'; echo "\n\necho 'hook:configure:triggered'"; } > deploy/{production,staging}/configure.sh;
```

When project is ready for deployment it must be packaged

### Package

```bash
./scripts/package.sh \
  --source-dir "${PWD}/tests/workspace/releases/build_dummy/" \
  --build 99 \
  --git-revision 37ed7a1 \
  --filename project.tar.gz
```

Files are saved to `artifacts/` directory and can be uploaded either to the server or any other location

```bash
# Upload to s3 storage
aws s3 cp artifacts/project.tar.gz s3://bucket/builds/$(BUILD_NUMBER)/project.tar.gz
aws s3 cp artifacts/project.extra.tar.gz s3://bucket/builds/$(BUILD_NUMBER)/project.extra.tar.gz
aws s3 cp artifacts/MD5SUMS s3://bucket/builds/$(BUILD_NUMBER)/MD5SUMS

# or deployment server
scp artifacts/MD5SUMS \
		artifacts/project.tar.gz \
		artifacts/project.extra.tar.gz \
		user@example.com:/home/project/builds/$(BUILD_NUMBER)/
```

If packages are available it can be deployed

### Deploy

```bash
# From s3 storage
./scripts/deploy.sh \
  --package-url "s3://bucket/builds/$(BUILD_NUMBER)/project.tar.gz" \
  --target-dir /var/www/staging \
  --environment staging

# On same server
./scripts/deploy.sh \
  --package-url "/home/project/builds/$(BUILD_NUMBER)/project.tar.gz" \
  --target-dir /var/www/staging \
  --environment staging
```

## Hooks

The following hooks are triggered during install.sh

| Hook        | Location                             |
| ----------- | ------------------------------------ |
| validation  | deploy/${ENVIRONMENT}/validation.sh  |
| symlinks    | deploy/${ENVIRONMENT}/symlinks.sh    |
| permissions | deploy/${ENVIRONMENT}/permissions.sh |
| configure   | deploy/${ENVIRONMENT}/configure.sh   |
| cleanup     | deploy/${ENVIRONMENT}/cleanup.sh     |

### Sample hook

```bash
#!/usr/bin/env bash
# file: deploy/production/validation.sh

echo "hook:validation:triggered"

echo "Is production environment" || error_exit "Command not working"
```

## Functions available within hooks

### error_exit

Prints colored error message and exits with 1

```bash
cd bin/ || error_exit "Error Message"
```

### info

Prints colored headline

```bash
info "Verify checksums"

# verify checksums...
```

### symlinkSharedDirectory

Validates source and creates a symlink from source to destination. If destination exists, it will be removed.

```bash
# Create symlink from release/build_2020202020/pub/media to shared/pub/media
symlinkSharedDirectory "pub/media"

# Create symlink from release/build_2020202020/generated to shared/generated
symlinkSharedDirectory "generated"

# Create symlink from release/build_2020202020/var/log to shared/var/log
symlinkSharedDirectory "var/log"
```
