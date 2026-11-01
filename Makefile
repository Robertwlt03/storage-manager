# Short commands for everyday work. Each line hands over to Python (scripts/),
# Swift or one macOS tool; the logic itself lives in the scripts.
#
# Start:  make (lists every command), make <command>
# Needs:  Xcode 27 and Python 3.13 or newer; your own signing identity lives in local.mk (ignored
#         by git), which make identity writes.
-include local.mk

# MARK: Settings

BUILD_FOLDER ?= build
export BUILD_FOLDER SIGN_IDENTITY BUNDLE_ID SIGNING_KEYCHAIN SIGNING_KEYCHAIN_PASSWORD

APP := $(BUILD_FOLDER)/Storage Manager.app
DEMO_BUILD_FOLDER := $(BUILD_FOLDER)/demo
DEMO_APP := $(DEMO_BUILD_FOLDER)/Storage Manager.app
# The demo reads nothing, so it needs no Full Disk Access and no signing identity ("-": ad hoc).
# Its own folder and bundle identifier keep the signed app and its access untouched.
DEMO_BUILD := BUILD_FOLDER="$(DEMO_BUILD_FOLDER)" SIGN_IDENTITY=- \
	BUNDLE_ID=local.speicher-explorer.demo
STRESS_TEST_FOLDER := $(TMPDIR)storage-manager-test
# The newest Python from 3.13 on, as python3 alone may be an older one (Xcode brings 3.9); the
# scripts say clearly when none fits. The Swift scripts find it through PYTHON as well.
PYTHON := $(or $(firstword $(foreach version,3.15 3.14 3.13,\
	$(shell command -v python$(version) 2> /dev/null))),python3)
export PYTHON
# So python -m checks.console finds the shared code. No comment behind a value: make keeps the
# spaces in front of it as part of the value.
export PYTHONPATH := $(CURDIR)/scripts
# Prints in the shared look of every command.
CONSOLE := $(PYTHON) -m checks.console
# Every command opens with one heading: a script that draws its own gets none here. HEADED goes in
# front of what a command starts after its heading, so that leaves its own heading out.
HEADING := $(CONSOLE) heading
HEADED := CONSOLE_HEADED=1
# A step of a longer command reports in one line; the command itself draws the frame at the end.
STEP := CONSOLE_STEP=1
SNAPSHOT_MODE := $(if $(RECORD),--record)

.DEFAULT_GOAL := help
.SILENT:  # make prints no commands; each command says itself what it did, through $(CONSOLE)
.PHONY: help build run restart demo snapshots check hooks banner readme test coverage format \
	selftest stress release identity clean python-path

# MARK: Commands
# The text after ## is what make help shows for each command.

help: ## List every command
	$(HEADING) "Storage Manager · commands" "make <command> · details in CONTRIBUTING.md"
	@# Each command and its text, split at the ## into the two columns of the table.
	grep --no-filename -E '^[a-z]+:.*## ' $(MAKEFILE_LIST) \
		| awk -F ':.*## ' '{ print "make " $$1 "\t" $$2 }' | $(CONSOLE) table

build: ## Build the app and render its icon (INSTALL_APP=1 also copies it to ~/Applications)
	$(PYTHON) scripts/build.py

run: ## Build the app, then quit the running one and open the new one
	$(HEADING) "Storage Manager · run" "build, then open $(APP)"
	$(HEADED) $(STEP) $(MAKE) build
	$(HEADED) $(MAKE) restart

restart: ## Quit the app if it is open, then open the built one
	$(PYTHON) scripts/app.py restart "$(APP)"

demo: ## Build without your certificate, then open the app with made-up data (no scan)
	$(HEADING) "Storage Manager · demo" "made-up data, nothing scanned"
	$(HEADED) $(STEP) $(MAKE) build $(DEMO_BUILD)
	open -n "$(DEMO_APP)" --args -demo YES
	$(CONSOLE) frame success "Demo opened" "$(DEMO_APP)"

snapshots: ## Optional: photograph every demo page, light and dark, and compare (RECORD=1 records)
	@# Only you run it: macOS asks once whether your terminal may record the screen.
	$(HEADING) "Storage Manager · snapshots" "every demo page, light and dark"
	$(HEADED) $(STEP) $(MAKE) build $(DEMO_BUILD)
	$(HEADED) swift scripts/snapshots.swift "$(DEMO_APP)" $(SNAPSHOT_MODE)

check: ## Run the whole check pipeline, as on GitHub
	$(PYTHON) scripts/check.py

hooks: ## Optional: run make check before every git push (git push --no-verify skips it once)
	$(HEADING) "Storage Manager · hooks" "make check before every push"
	git config core.hooksPath scripts/hooks
	$(CONSOLE) frame success "Hooks on" "git runs make check before every push" \
		"git push --no-verify pushes once without it"

banner: ## Draw a banner for a guide: asks whether to replace one, then for its texts
	$(PYTHON) scripts/doc-assets.py banner

readme: ## Draw the README's pictures again; the tour comes from the pictures of make snapshots
	$(PYTHON) scripts/readme-assets.py

test: ## Run only the unit tests
	$(PYTHON) scripts/check.py tests

coverage: ## Show how much of each source folder the tests reach
	$(PYTHON) scripts/check.py coverage-report

format: ## Bring every Swift file into the shared form
	$(HEADING) "Storage Manager · format" "Sources, Tests and scripts"
	$(CONSOLE) wait "Formatting" swift format --in-place --recursive Sources Widget Tests scripts
	$(CONSOLE) frame success "Formatted" "every Swift file in Sources, Tests and scripts"

selftest: ## Measure real folders and compare with du (prints only counts and sizes)
	$(PYTHON) scripts/app.py selftest "$(APP)"

stress: ## Open a second app that clicks through every page as fast as it can
	$(HEADING) "Storage Manager · stress test" "$(APP)"
	open -n "$(APP)" --args -uiTest "$(STRESS_TEST_FOLDER)"
	$(CONSOLE) frame success "Stress test started" "in a second app; quit it when you have seen enough"

release: ## Build the disk image to share in dist/
	$(PYTHON) scripts/release.py

identity: ## Create your own signing certificate once
	$(PYTHON) scripts/create-signing-identity.py

clean: ## Remove everything that building creates
	$(HEADING) "Storage Manager · clean" ".build, $(BUILD_FOLDER) and dist"
	rm -rf .build "$(BUILD_FOLDER)" dist
	$(CONSOLE) frame success "Removed" ".build, $(BUILD_FOLDER) and dist"

# Not listed in make help: the pre-push hook asks which Python to start scripts/push-check.py with.
python-path:
	$(info $(PYTHON))
