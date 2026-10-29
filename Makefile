# Short commands for everyday work, like npm scripts. `make` alone lists them all.
# Your own signing identity goes into local.mk (ignored by git), for example:
#   SIGN_IDENTITY = Speicher-Explorer Dev
-include local.mk

BUILD_DIR ?= build
export BUILD_DIR SIGN_IDENTITY

APP := $(BUILD_DIR)/Speicher-Explorer.app
PROCESS := SpeicherExplorer
STRESS_TEST_FOLDER := $(TMPDIR)speicher-test
SECONDS_BETWEEN_QUIT_CHECKS := 0.2

.DEFAULT_GOAL := help
.PHONY: help build run restart check test format selftest stress release identity clean

help: ## List every command
	@grep -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) | awk -F ':.*## ' '{ printf "  make %-9s %s\n", $$1, $$2 }'

build: ## Build the app (texts, contrast and icon are checked on the way)
	./build.sh

run: build restart ## Build the app, then quit the running one and open the new one

restart: ## Quit the app if it is open, then open the built one
	@if pkill -x $(PROCESS); then \
		while pgrep -x $(PROCESS) > /dev/null; do sleep $(SECONDS_BETWEEN_QUIT_CHECKS); done; \
	fi
	open "$(APP)"

check: ## Run the whole check pipeline, as on GitHub
	scripts/inspect.py

test: ## Run only the unit tests
	scripts/inspect.py tests

format: ## Bring every Swift file into the shared form
	swift format --in-place --recursive Sources Tests

selftest: ## Measure real folders and compare with du (prints only counts and sizes)
	swift build -c release
	.build/release/$(PROCESS) --selftest

stress: ## Open a second app that clicks through every page as fast as it can
	open -n "$(APP)" --args -uiTest "$(STRESS_TEST_FOLDER)"

release: ## Build the disk image to share in dist/
	scripts/release.sh

identity: ## Create your own signing certificate once
	scripts/create-signing-identity.sh

clean: ## Remove everything that building creates
	rm -rf .build "$(BUILD_DIR)" dist
