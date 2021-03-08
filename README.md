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
    - [Install](#install-1)
  - [Hooks](#hooks)
    - [Sample hook](#sample-hook)
  - [Functions available within hooks](#functions-available-within-hooks)
    - [error_exit](#error_exit)
    - [info](#info)
    - [symlinkSharedDirectory](#symlinkshareddirectory)
    - [waitFor](#waitfor)
  - [References](#references)
  - [License](#license)
  - [Author](#author)

## Deployment Workflow

**Before Deployment**

1. Package project to project.tar.gz with `package.sh`
2. Upload project.tar.gz to remote location like S3

**On Deployment**

1. `deploy.sh` is triggered on deploy server
2. Artefact is downloaded and extracted to releases/build_2020010202002
3. `vendor/bin/install.sh` in releases/build_2020010202002 is triggered
4. Hooks in releases/build_2020010202002/deploy/${ENVIRONMENT}/ are triggered
5. All good -> Symlink releases/current to extracted folder releases/build_2020010202002

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

_Hint: env variables and additional parameters will be passed to vendor/bin/install.sh_

```bash
# Pass parameters to vendor/bin/install.sh script

./scripts/deploy.sh \
  --package-url "artifacts/project.tar.gz" \
  --target-dir "/var/www" \
  --environment staging \
  --shared-dir "/var/shared" \
  --skip-systemstorage-import
```

### Install

```bash
./scripts/install.sh \
  --project-root "${PWD}/tests/workspace/releases/build_dummy" \
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
{ echo '#!/usr/bin/env bash'; echo "\n\necho 'hook:pre-install:triggered'"; } > deploy/{production,staging}/pre-install.sh;
```

When project is ready for deployment it must be packaged

### Package

| Argument                     | Description                                          |
| ---------------------------- | ---------------------------------------------------- |
| -f \| --filename             | Filename (i.e. projectA.tar.gz)                      |
| -s \| --source-dir           | Source folder /project_root                          |
| -t \| --target-dir           | Target folder (i.e. artifacts/)                      |
| -b \| --build                | Build number                                         |
| -g \|--git-revision          | GIT revision (i.e. 37ed7a1)                          |
|                              |                                                      |
| --skip-config-dump           | Skip config dump before packaging                    |
| --skip-di-compile            | Skip comiling dependency injections before packaging |
| --skip-static-content-deploy | Skip generating static content before packaging      |
| --skip-extra-package         | Skip generating extra package                        |
| --save-filelist              | Save filenames into text file                        |

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

| Argument                          | Description                                                                                   |
| --------------------------------- | --------------------------------------------------------------------------------------------- |
| -e \| --environment               | Environment (i.e. staging, production)                                                        |
| -p \| --package-url               | Package url (https, S3 or local file)                                                         |
| -t \| --target-dir                | Target dir (root of releases/ and current/)                                                   |
| --install-extra-package           | Also download and install .extra.tar.gz package                                               |
|                                   |                                                                                               |
| --aws-profile                     | AWS profile name                                                                              |
| --wget-args                       | Wget arguments like --wget-args "--user=USERNAME --password=PASSWORD"                         |
|                                   |                                                                                               |
| _Pass arguments to deployscript:_ |                                                                                               |
| -p \|--project-root               | Project dir - will be set by CURRENT_RELEASE_DIR (i.e. <targetDir>/releases/build_2020202020) |
| -s \|--shared-dir                 | Shared dir (root of pub/media/ and var/log/)                                                  |
| --skip-systemstorage-import       | Skip systemstorage import                                                                     |

**Pass arguments to deployscript**

_Environment variables and unused parameters will be send to vendor/bin/install.sh_

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

# With additional parameters for vendor/bin/install.sh
./scripts/deploy.sh \
  --package-url "/home/project/builds/$(BUILD_NUMBER)/project.tar.gz" \
  --target-dir /var/www/staging \
  --environment staging
	--shared-dir "/var/shared" \
	--skip-systemstorage-import
```

### Install

| Argument             | Description                                                          |
| -------------------- | -------------------------------------------------------------------- |
| -e \| --environment  | Environment (i.e. staging, production)                               |
| -r \| --project-root | Project root / extracted release folder /.../releases/build_20210201 |
| -s \|--shared-dir    | Shared folder /.../shared/                                           |

Install script is triggered during deployment and environment variables and unused arguments are passed.

## Hooks

The following hooks are triggered during install.sh

| #   | Hook                 | Location                                   |
| --- | -------------------- | ------------------------------------------ |
| 1   | pre                  | deploy/${ENVIRONMENT}/pre.sh               |
| 2   | defaultvalidation \* | deploy/${ENVIRONMENT}/defaultvalidation.sh |
| 2   | pre-install          | deploy/${ENVIRONMENT}/pre-install.sh       |
| 2   | install \*           | deploy/${ENVIRONMENT}/install.sh           |
| 2   | post-install         | deploy/${ENVIRONMENT}/post-install.sh      |
| 2   | cleanup              | deploy/${ENVIRONMENT}/cleanup.sh           |

\*) Replaces default behaviour

### Sample hook

```bash
#!/usr/bin/env bash
# file: deploy/production/pre-install.sh

echo "hook:pre-install:triggered"

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

### waitFor

Wait for a command or connection to succeed

| Parameter           | Description  |
| ------------------- | ------------ |
| --command <command> | Set command  |
| --host <host>       | Set hostname |
| --port <port>       | Set port     |
| --timeout <seconds> | Set port     |

```bash
# Test command
waitFor --command "/script.sh" --timeout 5

# Test tcp port
waitFor --host www.google.com --port 443 --timeout 1
```

## References

- [Magento 2.4 Technical Details](https://devdocs.magento.com/guides/v2.4/config-guide/deployment/pipeline/technical-details.html)

## License

MIT

## Author

- [Tobias Schifftner](https://www.twitter.com/tschifftner), [Ambimax GmbH](https://www.ambimax.de)
