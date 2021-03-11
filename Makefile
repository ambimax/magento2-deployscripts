BATS_DOCKER_IMAGE="ambimax/bats:1.2.3"
MAGENTO_VERSION="2.4.2"

bats-enter:
	@docker run -it --rm \
		--entrypoint bash \
		--workdir /workspace \
		--volume "${PWD}/scripts:/scripts" \
		--volume "${PWD}:/workspace" \
		$(BATS_DOCKER_IMAGE)


bats-test:
	@docker run --rm \
		--tty \
		--volume "${PWD}/scripts:/scripts" \
		--volume "${PWD}:/workspace" \
		$(BATS_DOCKER_IMAGE) -r tests

build-magento2-testimage:
ifeq (, $(shell docker images -q ambimax/magento2-testimage:$(MAGENTO_VERSION) 2> /dev/null))
	docker build \
		--build-arg VERSION=$(MAGENTO_VERSION) \
		--file tests/docker/Dockerfile \
		--tag ambimax/magento2-testimage:$(MAGENTO_VERSION) \
		tests/docker
endif

magento2-enter: build-magento2-testimage
	@docker run --rm --interactive --tty \
		--volume "${PWD}/scripts:/scripts" \
		--volume "${PWD}/tests/workspace/releases/build_dummy/app/etc/config.php:/var/www/app/etc/config.php" \
		ambimax/magento2-testimage:2.4.2 \
		bash

magento2-test: build-magento2-testimage
	@docker run --rm --tty \
		--volume "${PWD}/scripts:/scripts" \
		--volume "${PWD}/tests/workspace/releases/build_dummy/app/etc/config.php:/var/www/app/etc/config.php" \
		ambimax/magento2-testimage:2.4.2 \
		bash -c "/scripts/package.sh \
		  	--source-dir /var/www \
			--build 99 \
			--git-revision 37ed7a1 \
			--ignore-exclude-file \
			--filename project.tar.gz"

composer-test:
	@zip -r tests/composer/artifacts/ambimax-magento2-deployscripts-0.0.0.zip ./ -i ./composer.json ./scripts/**\*
	@docker run --rm --tty \
		--volume "${PWD}/tests/composer/artifacts:/artifacts" \
		--volume "${PWD}/tests/composer/project:/app" \
		composer install --no-plugins
	@[ -f "tests/composer/project/vendor/bin/install.sh" ] || { echo "vendor/bin/install.sh not found"; exit 1; }


shellcheck:
	@echo "shellcheck..."
	$(eval SHELLCHECK_FILES := $(shell find . -type f \( -iname \*.sh -o -iname \*.bash \)))
	@docker run --tty --rm --volume "${PWD}:/mnt" koalaman/shellcheck:stable $(SHELLCHECK_FILES)

basic-tests: shellcheck bats-test composer-test

tests: basic-tests magento2-test
