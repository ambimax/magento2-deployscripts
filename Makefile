BATS_DOCKER_IMAGE="ambimax/bats:1.2.3"

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


test: shellcheck bats-test composer-test
