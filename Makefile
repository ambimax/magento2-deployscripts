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


shellcheck:
	@echo "shellcheck..."
	$(eval SHELLCHECK_FILES := $(shell find . -type f \( -iname \*.sh -o -iname \*.bash \)))
	@docker run --tty --rm --volume "${PWD}:/mnt" koalaman/shellcheck:stable $(SHELLCHECK_FILES)


test: shellcheck bats-test
