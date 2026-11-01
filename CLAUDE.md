<p align="center">
  <img src="assets/banner-claude.svg" alt="Working with Claude on Storage Manager. How Claude Code helps build and check the app." width="100%">
</p>

Native macOS app (SwiftUI, Swift 6.4, SwiftPM, no Xcode project) that shows where disk space goes. Requires macOS 27 on
Apple silicon. MIT, public on GitHub. These notes are for anyone who works on the project with Claude Code; personal
preferences of one contributor belong in their own `CLAUDE.local.md`, which Claude Code reads too. Git ignores it and
the folder `assets/local/` for its pictures, so a local file can have the same banner and icons as this one: draw them
with `scripts/doc-assets.py` (`--theme claude`), then move them into `assets/local/`, since `make check` reports any
picture in `assets/` that no guide shows.

The human-facing guides, all in English: README.md, CONTRIBUTING.md (setup, commands, editors), ARCHITECTURE.md (data
path, code map, deliberate rules) and CODE_STYLE.md (code rules and how they are checked). Read the last two before
changing code; do not repeat their content here or in comments.

## <img src="assets/icons/claude-conversation.svg" height="33" align="absmiddle" alt="">Working with the person at the keyboard

- Answer in the language they write in, unless their `CLAUDE.local.md` says otherwise.
- Say honestly what was checked and what was not (for example "checked without measurement data", "not run because it
  needs the keychain").
- Ask before pushing, opening a pull request, installing anything (Homebrew, toolchains, packages) or downloading a
  tool. Commands that need a password (`sudo …`, keychain, `tccutil`) are theirs to run.
- End commit messages and pull request descriptions with the attribution lines Claude Code itself provides.

## <img src="assets/icons/claude-privacy.svg" height="33" align="absmiddle" alt="">Privacy and safety (hard rules)

- Never print file or folder names from the person's disk in chat, logs or tests: only counts and sizes. Screenshots
  only of your own test window, and never of pages that list file names (explorer, large files, search, app copies);
  the demo mode is safe to photograph.
- Never delete, clean or move anything on the person's disk, not even in tests. Never press "Clean Up", "Delete" or
  "Move to Trash" in the app.
- No keychain access and no signing with their certificate; never run `make identity`. Their signed builds come from
  `make run` with the identity in the git-ignored `local.mk`. Your builds go to the scratchpad and switch the identity
  off, because `local.mk` applies to every make call: `make build BUILD_FOLDER=<scratchpad>/build SIGN_IDENTITY=-`.
  Never overwrite `build/`.
- Ad hoc builds have no Full Disk Access, so a scan in them makes macOS ask once per protected folder. Start test
  windows with `-autoScan NO` and never trigger a scan there. Never run the binary with `--selftest` from the shell:
  `make selftest` runs on the person's signed app, so ask them to run it and send the output.
- Not yours to run: `make snapshots` (asks for screen recording), `make restart` and `make run` (they quit every
  running copy of the app, also the person's), `make identity`, `make hooks` (changes their git settings).
- Never send key presses or clicks through System Events or `osascript`; see "Testing safely" for what to do instead.

## <img src="assets/icons/claude-languages.svg" height="33" align="absmiddle" alt="">Toolchain and languages

- Xcode 27 is required as a toolchain only (SwiftUI's `@State` macro plugin ships only with Xcode); any editor works.
  `xcode-select --print-path` must point to `/Applications/Xcode.app/Contents/Developer`.
- Two languages only. Swift for the app and the two tools that need macOS frameworks (`scripts/snapshots.swift`,
  `scripts/checks/unknown_words.swift`); Python 3.13 or newer for every other script in `scripts/`. No shell scripts
  (`make check` reports one): the `Makefile` is only a menu whose lines hand over to Python, Swift or one macOS tool.
- `make` picks the newest Python from 3.13 on and exports it as `PYTHON` (with `scripts/` on `PYTHONPATH`);
  `scripts/checks/__init__.py` stops an older Python with a clear message. Started by hand, a script needs a new enough
  Python, such as `python3.14 scripts/check.py tests`.
- Swift 6 language mode with the main actor as default isolation and approachable concurrency: an async function
  without an actor runs where its caller runs. Background work says so: `@concurrent` for an async function that must
  leave the main thread, `Task.detached(priority:)` where scanning, cleaning or reading needs a lower priority.
- SwiftLint (Homebrew) runs in the pipeline; `swift format` comes with the toolchain.

## <img src="assets/icons/claude-commands.svg" height="33" align="absmiddle" alt="">Commands

`make` lists them all. The ones you use:

- `make check`: the whole pipeline; CODE_STYLE.md explains the rules behind its steps, and `scripts/check.py`
  names them (`STEPS`). It must end with the green frame "All … steps
  passed: no errors, no warnings". A kind of symbol or declaration the checks do not know is reported, never
  skipped: decide it in `scripts/checks/` instead of silencing it.
- `make test`, `make coverage` (the table per folder), `make format`, single steps with `scripts/check.py <step>`.
- `make build BUILD_FOLDER=<scratchpad>/build SIGN_IDENTITY=-` for your own builds.
- `make banner` draws a guide banner (asks everything, offers existing ones to replace).

## <img src="assets/icons/claude-commit.svg" height="33" align="absmiddle" alt="">Before every commit

1. `make check` is green.
2. Code Inspect: review exactly what the commit will contain (the staged diff, or the working tree when nothing is
   staged yet) for bugs, reuse, simplification and the rules here. Use the `/code-review` skill if this session has it
   (see "Skills and helpers"); otherwise review the diff yourself along the same lines. Fix what it finds or say why a
   finding is wrong, then run `make check` again. Repeat the review (and `/ponytail-review`, if installed) until a
   round finds nothing real; what you leave on purpose goes, with its reason, into the pull request.
3. Commit on the task's own branch, never on `main` (see "GitHub"). Name every file (`git add <files>`, never
   `git add -u` or `-A`), so nothing the person is trying out slips in. Messages follow Conventional Commits in
   English. Do not push.
4. Run `make check` once more after committing: it checks a commit message only once the commit exists, so a word it
   does not accept is fixed with `git commit --amend` before anyone pushes.

## <img src="assets/icons/claude-app.svg" height="33" align="absmiddle" alt="">Working on the app

1. Read the files you touch and the rules in CODE_STYLE.md and ARCHITECTURE.md first.
2. Keep the rules: spelled-out English names, no numbers without a name, colors only from `Theme`, fonts via
   `textRole`, symbols from `Symbols`, animations from `Motion`, visible text only via `TextKey` with all 28
   translations, no dead code, functions as lists of named steps. Never rename a `TextKey` case (it is the key in the
   translation files), a settings key, a launch argument or a page key. The app was called Speicher-Explorer before it
   became Storage Manager; its bundle identifier `local.speicher-explorer`, the signing keychain and the identity
   "Speicher-Explorer Dev" keep that name on purpose, because macOS ties Full Disk Access and the settings to them.
3. A new folder below `Sources` first gets its row in the layer table of `scripts/checks/architecture.py` and a line in
   ARCHITECTURE.md. Never call network interfaces. Deleting or trashing files stays in `CleanerService`,
   `CopyService` and `AppUsageService`, behind the person's confirmation; the cleaner makes its list again right
   before deleting.
4. New logic gets a test in `Tests/StorageManagerTests` (hand-built `Node` trees via `TestTree`, never the real
   disk). Each logic folder has a coverage minimum that may only rise.
5. The scanned tree (`Node`) belongs to the main actor: read it there and hand background work finished values,
   because a new scan can empty the tree at any moment. `AppModel.swift` stays under SwiftLint's 400 lines: parts
   that only read or only navigate go into extensions such as `AppModel+Figures.swift`. A type the app stores in its
   settings (as JSON) must still read what an earlier version saved, or say in the pull request what is lost once.
6. When views changed, check the look in your own test window (see "Testing safely").

Design goals: native Apple look (HIG; Liquid Glass only above the content, in the toolbar and sidebar, while cards and
buttons in the content use the bordered macOS styles), gentle and minimal animations as feedback only, no start
animation, energy-saving behavior (nothing animates or polls at rest), text contrast at least 4.5:1 in light and dark
mode.

## <img src="assets/icons/claude-scripts.svg" height="33" align="absmiddle" alt="">Working on scripts and checks

- Every script follows the shared layout (CODE_STYLE.md, step 22): a head with `Start:` and `Needs:`,
  `MARK: Settings` with every number and pattern named and explained (patterns in re.VERBOSE with a comment per part),
  small named steps, `MARK: Run` at the bottom. Shared code lives in `scripts/checks/project.py` and
  `scripts/build.py`; ask the app for its lists (as `--list-pages` does) instead of copying them.
- Everything a command prints goes through the shared console (`scripts/checks/console.py`, from make as
  `$(CONSOLE) <piece>`; `Sources/Diagnostics/Console.swift` in the app). CODE_STYLE.md, step 23, describes the one look:
  one heading per command, a frame at the end, questions with `?`, `y/n`, a turning wheel for long work, never two
  blank lines in a row.
- A new or changed rule in `scripts/checks/` gets a planted mistake in `scripts/checks/samples` with an `expect:` note
  on its line, and a counter-test that the project itself stays clean. Keep rules general, never a list of today's
  code: derive what you can from the compiler's index, the platform or the project.
- `make check` does not run the tool scripts themselves (build, release, hook, banner). After changing one, run it as
  described under "Testing safely".

## <img src="assets/icons/claude-testing.svg" height="33" align="absmiddle" alt="">Testing safely

- **The look:** use the demo mode (made-up data, no scan, nothing read or removed). Launch your scratchpad build and
  photograph only its window:

  ```bash
  open -n "<scratchpad>/build/Storage Manager.app" --args -ApplePersistenceIgnoreState YES -demo YES \
    -pane overview -"NSWindow Frame main" "100 100 1100 860 0 0 2560 1440"
  ```

  Find the window number with a small CoreGraphics script (`CGWindowListCopyWindowInfo`, filtered by the app's PID
  and a width over 500 points, so it is the main window) and capture it with `screencapture -x -o -l <window>`.
  `StorageManager --list-pages` prints the page names; `-appearance dark` or `light` fixes the look. For
  refactors, build the previous commit into another scratchpad folder and compare both captures. A locked screen
  allows no captures; wait until it is unlocked.
- **App behavior without new permissions:** build a test copy with its own bundle identifier, so it never touches
  the person's app or its permissions:
  `make build BUILD_FOLDER=<scratchpad>/check SIGN_IDENTITY=- BUNDLE_ID=local.speicher-explorer.check`. Launch it
  with `-autoScan NO`. Send a quit request as macOS does with a tiny Swift script
  (`NSRunningApplication.runningApplications(withBundleIdentifier:)` and `terminate()`). For a menu command, add a
  temporary line ending in `// DBG` that performs it when an environment variable is set, start the copy with
  `open -n --env DBG_QUIT=1 --stderr <scratchpad>/err.txt <app>`, read the result with `pgrep`, then remove the line
  (`make check` fails while one is left). Quit only your copy, by its scratchpad path.
- **States behind a click:** open sheets, popovers, empty pages and menus with such a `// DBG` line instead of a click
  or keystroke; a menu opens inside your window with `NSMenu.popUp(positioning:at:in:)` and can then be captured.
  The menu bar item and its menu are drawn by macOS outside the app and refuse every capture: ask the person to look
  at them in light and dark appearance and say so in the pull request.
- **Traces of test copies:** a launched copy registers its widget with macOS; unregister it afterwards with
  `pluginkit -r "<scratchpad>/…/Storage Manager.app/Contents/PlugIns/StorageWidget.appex"`, so the person's widget
  gallery shows only their app. A copy also keeps its settings between launches; a value one test stored (for
  example a switch set by a launch argument) is reset with `defaults delete <its bundle identifier> <key>`.
- **Tool scripts:** copy the project into the scratchpad (`rsync -a --exclude .build --exclude /build --exclude /dist
  --exclude local.mk <project>/ <scratchpad>/copy/`) and run `make release SIGN_IDENTITY=-` or the pre-push hook there,
  never in the project. Hand the hook git's input on stdin, and start it with the oldest `python3` it must survive
  (Xcode's 3.9).
- **Questions in the console:** drive them in a pseudo terminal (Python's `pty` module) that types the answers and
  arrow keys, against a scratchpad copy, so nothing in the project is drawn or replaced.

## <img src="assets/icons/claude-skills.svg" height="33" align="absmiddle" alt="">Skills and helpers

- Use only the skills this session lists as available; never assume one that another contributor may have installed.
  `/code-review` (and `/ponytail-review` for over-engineering, if installed) serve Code Inspect; without them, review
  the same way by hand.
- Helpers working in parallel each get their own files and never the same ones. They do not run `make check`,
  `swift test` or builds in the project at the same time (builds collide in `.build/`); a helper that must compile
  uses its own build folder (`swift build --build-path <scratchpad>/…`). The session that started them merges the
  results, applies renames that cross areas, and runs everything once at the end.
- Helpers that each build a whole branch work in a git worktree of their own
  (`git worktree add ../storage-manager-wt/<branch> -b <branch> origin/main`) with their own scratchpad folder and
  test-copy bundle identifier, so builds and windows never collide. Each one reports the files it touched that other
  branches touch too; the starting session plans the merge order from that and rebases the later branches.

## <img src="assets/icons/claude-github.svg" height="33" align="absmiddle" alt="">GitHub

- The workflow runs on GitHub's own Mac image for macOS 27 and Xcode 27 (`runs-on: xcode-27`): a fresh Mac per run,
  thrown away afterwards, so pull requests from forks are checked too, once the owner approves the run. GitHub names
  its Mac images after the Xcode version (`xcode-27`), not only after macOS (`macos-15`).
- The workflow runs each group of `scripts/check.py` (`GROUPS`) as a job of its own with a telling name, side by side,
  and builds the app beside them; the job `checks` sums them up, so the ruleset requires only that one name. A new
  step goes into a group, or `check.py` stops at its start; a new group also gets a job and a place in the `needs` of
  `checks`. The jobs share their setup (Python, SwiftLint) through `.github/actions/setup/action.yml`.
- `main` is protected by a ruleset without exceptions: every change, the maintainer's too, comes in through a pull
  request whose `checks` are green, merged with a merge commit (no squash). Start each task on a new branch from an
  up-to-date `main`; after the merge, delete the branch on GitHub and locally (`git branch -d`, `git fetch --prune`)
  and pull `main`. CONTRIBUTING.md shows the steps.
- Branch names follow CONTRIBUTING.md (`1239-scan-cancel`, or `readme-typo` without an issue). When a task has no
  issue, suggest opening one that describes the problem or wish.
- One topic per branch. Before working on a request that reaches beyond the current branch's topic, such as a
  console fix on a branch for languages or a change to this file, say so and ask whether to start a new branch from
  `main`, or, when both really are one task, to rename the current branch to name it; never mix it in silently.
- Once the person is content with every open branch, list them in the order to merge, each with its reason: what
  builds on what, which ones touch the same files (merge the smaller first, then bring the other up to date), and
  what is safest to have on `main` early.
- Keep each branch a straight line on top of `main`, so `main` gets exactly one merge commit per pull request: start
  every branch from `main`, never from another feature branch, never merge one feature branch into another, and
  bring a branch up to date with `git fetch && git rebase origin/main` instead of merging `main` into it, solving
  conflicts there when its turn comes; a branch that was already pushed then goes up with
  `git push --force-with-lease` (the ruleset guards only `main`). On GitHub that is "Update with rebase" or
  `gh pr update-branch --rebase`; the plain "Update branch" merges `main` in. Merging `main` into branches, or
  branches into each other, leaves a tangle of merge commits.
- Pull request descriptions follow `.github/PULL_REQUEST_TEMPLATE.md`: its banner, every section with its
  icon filled in (none left with only its hint, the screenshots removed when nothing is visible), the footer, and the
  attribution line last. `gh pr create` does not fill the template by itself, so start from a copy and pass it with
  `--body-file`. Its pictures use full addresses on `main`, because a description cannot load files by path. Tick
  a checkbox only when its task is really done; what could not be checked (a tooltip, a real key press) is said
  plainly in the text instead.
- Give every `gh` command the repository (`gh pr edit 20 -R Robertwlt03/storage-manager …`): a shell that starts in
  another checkout would otherwise change a pull request of that other repository.
- Every action is pinned to a commit with its version in a comment; pick a release that has been out for a while.
- `make hooks` (the person's choice) runs `make check` before every push. The hook starts with any `python3`, then
  hands over to the Python 3.13 or newer that make finds.

## <img src="assets/icons/claude-documentation.svg" height="33" align="absmiddle" alt="">Documentation

- Everything in the repository is English in American spelling: guides, the installation guide in `docs/guide`,
  templates, code, comments, scripts and commit messages. Other languages appear only in the app's translations
  (`Resources/*.lproj`); `make check` reports German anywhere else.
- Every guide follows the README's layout: banner at the top (`assets/banner-*.svg`), an icon in front of every `##`
  heading (`<img src="assets/icons/<name>.svg" height="33" align="absmiddle" alt="">`), and the shared footer with the
  small banner, the navigation line to all guides and the license line.
- Draw banners with `make banner` and icons with `scripts/doc-assets.py icon` (see its help) so they match the
  others; an existing file is only replaced with `--overwrite` or by picking it in `make banner`. Section icons: 60×56
  canvas, 45 px rounded tile with a two-stop gradient, white 2 px stroke glyph in a 24 px grid; within one guide every
  icon has its own color and shape.
- This file has the same form in Claude's colors (ivory, clay and slate from claude.com): `assets/banner-claude.svg`
  (`--theme claude`; a banner drawn again keeps its theme), `assets/banner-claude-footer.svg`, which is drawn again
  with it, and the `claude-*` icons in the Claude tones of `scripts/doc-assets.py`. The clay tile carries Claude's mark,
  the path of the logo on claude.com (`CLAUDE_MARK`). Claude and its mark belong to Anthropic; they appear here only to
  name the tool, and the project's MIT license does not cover them.
- When requirements, commands or rules change, update README, CONTRIBUTING, CODE_STYLE, ARCHITECTURE and this file in
  the same commit.

<p align="center">
  <img src="assets/banner-claude-footer.svg" alt="" width="480">
</p>

<p align="center">
  <b>Storage Manager · See at a glance where your storage goes.</b><br>
  <sub><a href="README.md">Overview</a> · <a href="CONTRIBUTING.md">Contributing</a> · <a href="ARCHITECTURE.md">Architecture</a> · <a href="CODE_STYLE.md">Code rules</a> · <a href="CODE_OF_CONDUCT.md">Code of conduct</a> · <a href="CLAUDE.md">Working with Claude</a></sub><br>
  <sub>© 2026 Robertwlt03 · Released under the <a href="LICENSE">MIT license</a> · For macOS 27 on Macs with Apple silicon</sub>
</p>
