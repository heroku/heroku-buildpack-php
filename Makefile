# The `run` target is useful for local testing/iteration.
# Locally run this using watchexec (or file watcher of choice), eg:
# ```
# brew install watchexec
# watchexec -qrc --stop-timeout 0 -- make run
# watchexec -qrc --stop-timeout 0 -- make run FIXTURE=test/fixtures/composer/basic_lock_v2
# ```

.PHONY: run

STACK ?= heroku-24
FIXTURE ?= test/fixtures/default
# Allow overriding the exit code in CI, so we can test bin/report works for failing builds.
COMPILE_FAILURE_EXIT_CODE ?= 1

# Converts a stack name of `heroku-NN` to its build Docker image tag of `heroku/heroku:NN-build`.
STACK_IMAGE_TAG := heroku/$(subst -,:,$(STACK))-build

run:
	@echo "Running buildpack using: STACK=$(STACK) FIXTURE=$(FIXTURE)"
	@docker run --rm -v $(PWD):/src:ro --tmpfs /app -e "HOME=/app" -e "STACK=$(STACK)" "$(STACK_IMAGE_TAG)" \
		bash -euo pipefail -O dotglob -c '\
			mkdir /tmp/buildpack /tmp/cache /tmp/env; \
			cp -r /src/{bin,conf,support,composer.json} /tmp/buildpack; \
			cp -r /src/$(FIXTURE) /tmp/build_1; \
			cd /tmp/buildpack; \
			unset $$(printenv | cut -d '=' -f 1 | grep -vE "^(HOME|LANG|PATH|STACK)$$"); \
			echo -en "\n~ Detect: " && ./bin/detect /tmp/build_1; \
			echo -e "\n~ Compile:" && { ./bin/compile /tmp/build_1 /tmp/cache /tmp/env || COMPILE_FAILED=1; }; \
			echo -e "\n~ Report:" && ./bin/report /tmp/build_1 /tmp/cache /tmp/env; \
			[[ "$${COMPILE_FAILED:-}" == "1" ]] && exit $(COMPILE_FAILURE_EXIT_CODE); \
			[[ -x /tmp/build_1/bin/compile ]] && { echo -e "\n~ Compile (Inline Buildpack):" && (source ./export && /tmp/build_1/bin/compile /tmp/build_1 /tmp/cache /tmp/env); }; \
			echo -e "\n~ Release:" && ./bin/release /tmp/build_1; \
			rm -rf /app/* /tmp/buildpack/export /tmp/build_1; \
			#cp -r /src/$(FIXTURE) /tmp/build_2; \
			#echo -e "\n~ Recompile:" && ./bin/compile /tmp/build_2 /tmp/cache /tmp/env; \
			#echo -e "\nBuild successful!"; \
		'
	@echo
