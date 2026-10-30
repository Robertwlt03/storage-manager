# Speicher-Explorer – working notes for Claude

Native macOS app (SwiftUI, Swift 6.4, SwiftPM, no Xcode project) that shows where disk space goes. Requires macOS 27 on
Apple silicon. MIT, public on GitHub. The human-facing guides are German (with English twins `*.en.md`):
README.md, CONTRIBUTING.md (setup, commands, editors), ARCHITECTURE.md (data path, code map, deliberate rules)
and CODE_STYLE.md (code rules and how they are checked). Read the last two before changing code; do not repeat their
content here or in comments.

## Talking to the user

- Always answer in German, in whole sentences that read well aloud (the answer is often read out): connections spelled
  out ("weil", "deshalb", "danach"), no telegram style, no English phrasing in the prose. Lists only for real steps or
  options, each item a full sentence.
- Every summary of a change, review or session also comes as a small graphic next to the full text.
- Say honestly what was checked and what was not (for example "ohne Messdaten geprüft").
- Commit footer: `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. PR footer:
  `🤖 Generated with [Claude Code](https://claude.com/claude-code)`.

## Privacy and safety (hard rules)

- Never print file or folder names from the user's disk in chat, logs or tests: only counts and sizes. Screenshots only
  of your own test window, and never of pages that list file names (explorer, large files, search, app copies).
- Never delete, clean or move anything on the user's disk, not even in tests. Never press "Aufräumen", "Löschen" or
  "In den Papierkorb" in the app.
- No keychain access and no signing with the user's certificate. The user builds signed builds themselves
  (`make run`, with the identity from `make identity` in the git-ignored `local.mk`). Your builds go to the
  scratchpad and must switch the identity off, because `local.mk` applies to every make call:
  `make build BUILD_FOLDER=<scratchpad>/build SIGN_IDENTITY=-`. Never overwrite `build/`.
- Your ad hoc builds never have Full Disk Access, so any scan in them makes macOS ask once per protected folder
  (hundreds of prompts). Start test windows with `-autoScan NO` and never trigger a scan there. Never run
  `.build/release/SpeicherExplorer --selftest` from the shell; the self test runs only as `make selftest` on the user's
  signed app, so ask the user to run it and send the output.
- `make snapshots` is the user's alone: it asks macOS for screen recording for their terminal. Do not run it; the
  pictures and references live in the git-ignored `snapshots/`.
- Never quit the user's running app; `make restart` and `make run` quit every running copy.
- Ask before pushing, opening a PR or installing anything (Homebrew, toolchains). Commands that need a password
  (`sudo …`) are the user's to run.

## Toolchain

- Xcode 27 is required as a toolchain only (SwiftUI's `@State` macro plugin ships only with Xcode); the IDE is never
  needed and any editor works. `xcode-select --print-path` must point to `/Applications/Xcode.app/Contents/Developer`;
  build.sh and the pipeline print a hint otherwise.
- Swift 6 language mode with the main actor as default isolation: only background work (scan, cleaner, folder profile,
  app copies) and what it touches is `nonisolated`.
- SwiftLint (Homebrew) runs as part of the pipeline; `swift format` comes with the toolchain.

## Everyday commands

`make` lists them all. The ones you need:

- `make check`: the whole pipeline (format, SwiftLint, compiler with warnings as errors, tests, house rules, design
  rules, flat methods (at most two blocks inside each other), dead code from the compiler index, American English
  names and comments without abbreviations, plutil,
  scripts, and the samples step that makes sure every check still finds its planted mistake). It must end with "No errors and no warnings." before
  every commit.
- `make test`, `make coverage`, `make format`, single steps with `scripts/check.py <step>`.
- `make build BUILD_FOLDER=<scratchpad>/build SIGN_IDENTITY=-` for your own builds (never with the user's identity).

## Working on code

1. Read the files you touch and the rules in CODE_STYLE.md and ARCHITECTURE.md first.
2. Keep the rules: spelled-out English names, no numbers without a name, colors only from `Theme`, fonts via
   `textRole`, symbols from `Symbols`, animations from `Motion`, visible text only via `TextKey` with all 20
   translations, no dead code, functions as lists of named steps. Scripts follow the same rules and one shared
   layout (CODE_STYLE.md, step 11): a head with `Start:` and `Needs:`, `MARK: Settings` with every number and pattern
   named and explained (patterns in re.VERBOSE with a comment per part), small named steps, `MARK: Run` at the
   bottom. Spelled-out names, no duplicated code (shared steps live in `scripts/require-xcode.sh` and
   `scripts/sign.sh`), and no copies of lists the app already has (ask the app, as `--list-pages` does).
3. New logic gets a test in `Tests/SpeicherExplorerTests` (hand-built `Node` trees via `TestTree`, never the real disk).
4. Run `make check` until it is clean, then check the look in your own test window (see below) when views changed.
5. A new or changed rule in `scripts/checks/` gets a planted mistake in `scripts/checks/samples` with an
   `expect:` note on its line. Keep rules general, never a list of today's code: derive what you can from the
   compiler's index, the platform or the project (as the known terms and screen texts do).
6. Commit on the current branch with the footer above; do not push.

Design wishes of the user: native Apple look (HIG, Liquid Glass), gentle and minimal animations as feedback only, no
start animation, energy-saving behavior (nothing animates or polls at rest), text contrast at least 4.5:1 in light and
dark mode.

## Checking the look

Use the demo mode: made-up data on every page, no scan, nothing read or removed, no private names, so every page may
be photographed. Launch your scratchpad build and photograph only its window:

```bash
open -n <scratchpad>/build/Speicher-Explorer.app --args -ApplePersistenceIgnoreState YES -demo YES \
  -pane overview -"NSWindow Frame main" "100 100 1100 860 0 0 2560 1440"
```

Find the window number with a small CoreGraphics script (`CGWindowListCopyWindowInfo`, filter by the app's PID and a
width over 500) and capture it with `screencapture -x -o -l <window>`. `SpeicherExplorer --list-pages` prints the
pane names; add `-appearance dark` (or `light`) for a fixed look. For refactors, build the
previous commit into a separate scratchpad folder and compare both captures pixel by pixel; differences in free space
and selection color (window focus) are expected.

## Testing app behavior without new permissions

Never send key presses or clicks through System Events or `osascript`: that needs Accessibility or Automation
permission and makes macOS ask the user. Test the real app like this instead (this is how Cmd+Q and "Quit & Reopen"
with the access sheet open were checked):

1. Build a test copy with its own bundle identifier, so it has its own permissions and settings and never touches the
   user's app: `make build BUILD_FOLDER=<scratchpad>/check SIGN_IDENTITY=- BUNDLE_ID=local.speicher-explorer.check`.
   It has no Full Disk Access, so launched with `-autoScan NO` (and without `-skipAccessSheet`) it shows the access
   sheet and never scans.
2. Quit requests from macOS (System Settings' "Quit & Reopen", the Dock's Quit) are Apple events. Send the same one
   with a tiny Swift script that needs no permission:
   `NSRunningApplication.runningApplications(withBundleIdentifier: "local.speicher-explorer.check").forEach { app in _ = app.terminate() }`.
3. Menu commands such as Cmd+Q: add a temporary line ending in `// DBG` to `AppDelegate.applicationDidFinishLaunching`
   that, when an environment variable is set, performs the menu item after a few seconds, for example the app menu's
   item whose `keyEquivalent` is `"q"` via `menu.performActionForItem(at:)`. Start it with
   `open -n --env DBG_QUIT=1 --stderr <scratchpad>/err.txt <app>` and print what you need to `FileHandle.standardError`.
4. Read the outcome without looking at the screen: `pgrep -f <scratchpad>/check/Speicher-Explorer.app` tells whether
   it is still running; a photo of the window (see above) shows dialogs.
5. Remove the debug lines with `sed -i '' '/\/\/ DBG$/d' <file>`; `make check` fails while one is left.

## Documentation

- Guides are German, each with an English twin (`README.en.md`, …) in American spelling; a change to one goes into
  both. Both carry the Deutsch · English line under the banner. Code, comments and commit messages are English.
- Every guide follows the README's layout: banner at the top (`assets/banner-*.svg`), an icon in front of every `##`
  heading (`<img src="assets/icons/<name>.svg" height="33" align="absmiddle" alt="">`), and the shared footer with the
  small banner, the navigation line to all guides and the license line.
- Draw new banners and icons with `scripts/doc-assets.py` (see its help) so they match the others.
- Section icons: 60×56 canvas, 45 px rounded tile with a two-stop gradient, white 2 px stroke glyph in a 24 px grid.
  Within one guide every icon has its own color and its own shape; check new icons rendered large and at 33 px in
  light and dark.
- When requirements, commands or rules change, update README, CONTRIBUTING, CODE_STYLE and ARCHITECTURE in the same
  commit.
