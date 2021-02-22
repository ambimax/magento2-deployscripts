# Magento2 deployment scripts

### Package

```
/scripts/package.sh --source-dir "${PWD}/tests/workspace/releases/build_dummy/" --build 99 --git-revision 37ed7a1 --filename project.tar.gz
```

### Deploy

```
/scripts/deploy.sh --package-url "tests/workspace/artifacts/project.tar.gz" --target-dir /workspace/tests/workspace/ --environment staging
```

Triggers composer install (vendor/bin/install.sh)

### Install

```
/scripts/install.sh -r "${PWD}/tests/workspace/releases/build_dummy" -e staging
```
