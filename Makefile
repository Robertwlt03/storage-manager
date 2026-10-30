# Short commands for everyday work, like npm scripts.
#
# Start:  make (lists every command), make <command>
# Needs:  Xcode 27; your own signing identity lives in local.mk (ignored by git), which
#         make identity writes.
-include local.mk

# MARK: Settings

BUILD_FOLDER ?= build
export BUILD_FOLDER SIGN_IDENTITY BUNDLE_ID SIGNING_KEYCHAIN SIGNING_KEYCHAIN_PASSWORD

APP := $(BUILD_FOLDER)/Speicher-Explorer.app
DEMO_BUILD_FOLDER := $(BUILD_FOLDER)/demo
DEMO_APP := $(DEMO_BUILD_FOLDER)/Speicher-Explorer.app
# The demo reads nothing, so it needs no Full Disk Access and no signing identity ("-": ad hoc).
# Its own folder and bundle identifier keep the signed app and its access untouched.
DEMO_BUILD := BUILD_FOLDER="$(DEMO_BUILD_FOLDER)" SIGN_IDENTITY=- \
	BUNDLE_ID=local.speicher-explorer.demo
PROCESS := SpeicherExplorer
STRESS_TEST_FOLDER := $(TMPDIR)speicher-test
SELFTEST_REPORT := $(TMPDIR)speicher-selftest.txt
SECONDS_BETWEEN_QUIT_CHECKS := 0.2
CONSOLE := scripts/console.sh  # prints in the shared look of every command
# make snapshots RECORD=1 hands --record to the script; without RECORD it hands nothing.
SNAPSHOT_MODE := $(if $(RECORD),--record)

.DEFAULT_GOAL := help
.SILENT:  # make prints no commands; each command says itself what it did, through $(CONSOLE)
.PHONY: help build run restart demo snapshots check hooks banner test coverage format selftest \
	stress release identity clean

# MARK: Commands
# The text after ## is what make help shows for each command.

help: ## List every command
	$(CONSOLE) heading "Speicher-Explorer · commands" "make <command>"
	@# Each command and its text, split at the ## into the two columns of the table.
	grep --no-filename -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) \
		| awk -F ':.*## ' '{ print "make " $$1 "\t" $$2 }' | $(CONSOLE) table
	$(CONSOLE) note "Details for each command: CONTRIBUTING.md"

build: ## Build the app and render its icon
	./build.sh

run: build restart ## Build the app, then quit the running one and open the new one

restart: ## Quit the app if it is open, then open the built one
	if pkill -x $(PROCESS); then \
		while pgrep -x $(PROCESS) > /dev/null; do sleep $(SECONDS_BETWEEN_QUIT_CHECKS); done; \
	fi
	open "$(APP)"
	$(CONSOLE) passed "Opened" "$(APP)"

demo: ## Build without your certificate, then open the app with made-up data (no scan)
	$(MAKE) build $(DEMO_BUILD)
	open -n "$(DEMO_APP)" --args -demo YES
	$(CONSOLE) passed "Demo opened" "made-up data, nothing scanned"

snapshots: ## Optional: photograph every demo page, light and dark, and compare (RECORD=1 records)
	@# Only you run it: macOS asks once whether your terminal may record the screen.
	$(MAKE) build $(DEMO_BUILD)
	swift scripts/snapshots.swift "$(DEMO_APP)" $(SNAPSHOT_MODE)

check: ## Run the whole check pipeline, as on GitHub
	scripts/check.py

hooks: ## Optional: run make check before every git push (git push --no-verify skips it once)
	git config core.hooksPath scripts/hooks
	$(CONSOLE) passed "Hooks on" "git runs make check before every push"
	$(CONSOLE) note "git push --no-verify pushes once without it."

banner: ## Draw a banner for a guide: asks whether to replace one, then for its texts
	scripts/doc-assets.py banner

test: ## Run only the unit tests
	scripts/check.py tests

coverage: ## Show how much of each source folder the tests reach
	scripts/check.py coverage-report

format: ## Bring every Swift file into the shared form
	swift format --in-place --recursive Sources Tests scripts
	$(CONSOLE) passed "Formatted" "every Swift file in Sources, Tests and scripts"

selftest: ## Measure real folders and compare with du (prints only counts and sizes)
	@# Started as the app, so macOS uses the app's Full Disk Access instead of asking per folder.
	rm -f "$(SELFTEST_REPORT)"
	@# The app writes into a file, not into this terminal, so it is told when colors fit.
	color=""; \
	if [ -t 1 ] && [ -z "$${NO_COLOR+set}" ]; then color="--env FORCE_COLOR=1"; fi; \
	open -n -W --stdout "$(SELFTEST_REPORT)" $$color "$(APP)" --args --selftest
	cat "$(SELFTEST_REPORT)"

stress: ## Open a second app that clicks through every page as fast as it can
	open -n "$(APP)" --args -uiTest "$(STRESS_TEST_FOLDER)"
	$(CONSOLE) passed "Stress test started" "in a second app; quit it when you have seen enough"

release: ## Build the disk image to share in dist/
	scripts/release.sh

identity: ## Create your own signing certificate once
	scripts/create-signing-identity.sh

clean: ## Remove everything that building creates
	rm -rf .build "$(BUILD_FOLDER)" dist
	$(CONSOLE) passed "Removed" ".build, $(BUILD_FOLDER) and dist"
