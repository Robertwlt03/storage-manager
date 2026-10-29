# Speicher-Explorer – working notes for Claude

Native macOS app (SwiftUI, Swift 6.4, SwiftPM, no Xcode project) that shows where disk space goes. Requires macOS 27 on
Apple silicon. MIT, public on GitHub. The human-facing guides are German: README.md, CONTRIBUTING.md (setup, commands,
editors), ARCHITECTURE.md (data path, code map, deliberate rules) and CODE_STYLE.md (code rules and how they are
checked). Read the last two before changing code; do not repeat their content here or in comments.

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
  (`make run` with `SIGN_IDENTITY` in the git-ignored `local.mk`). Your builds go to the scratchpad:
  `make build BUILD_DIR=<scratchpad>/build` (ad hoc signed); never overwrite `build/`.
- Your ad hoc builds never have Full Disk Access, so any scan in them makes macOS ask once per protected folder
  (hundreds of prompts). Start test windows with `-autoScan NO` and never trigger a scan there. Never run
  `.build/release/SpeicherExplorer --selftest` from the shell; the self test runs only as `make selftest` on the user's
  signed app, so ask the user to run it and send the output.
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
  rules, dead code, plutil, shell scripts). It must end with "No errors and no warnings." before every commit.
- `make test`, `make coverage`, `make format`, single steps with `scripts/inspect.py <step>`.
- `make build BUILD_DIR=<scratchpad>/build` for your own builds.

## Working on code

1. Read the files you touch and the rules in CODE_STYLE.md and ARCHITECTURE.md first.
2. Keep the rules: spelled-out English names, no numbers without a name, colours only from `Theme`, fonts via
   `textRole`, symbols from `Symbols`, animations from `Motion`, visible text only via `TextKey` with all 20
   translations, no dead code, functions as lists of named steps.
3. New logic gets a test in `Tests/SpeicherExplorerTests` (hand-built `Node` trees via `TestTree`, never the real disk).
4. Run `make check` until it is clean, then check the look in your own test window (see below) when views changed.
5. Commit on the current branch with the footer above; do not push.

Design wishes of the user: native Apple look (HIG, Liquid Glass), gentle and minimal animations as feedback only, no
start animation, energy-saving behaviour (nothing animates or polls at rest), text contrast at least 4.5:1 in light and
dark mode.

## Checking the look

Use the demo mode: made-up data on every page, no scan, nothing read or removed, no private names, so every page may
be photographed. Launch your scratchpad build and photograph only its window:

```bash
open -n <scratchpad>/build/Speicher-Explorer.app --args -ApplePersistenceIgnoreState YES -demo YES \
  -pane overview -"NSWindow Frame main" "100 100 1100 860 0 0 2560 1440"
```

Find the window number with a small CoreGraphics script (`CGWindowListCopyWindowInfo`, filter by the app's PID and a
width over 500) and capture it with `screencapture -x -o -l <window>`. Panes: `overview`, `explorer`, `largeFiles`,
`cleaner`, `apps`, `temp`, `copies`; add `-AppleInterfaceStyle Dark` for the dark look. For refactors, build the previous commit into a separate scratchpad folder and compare both captures
pixel by pixel; differences in free space and selection colour (window focus) are expected.

## Documentation

- Guides stay German; code, comments and commit messages are English.
- Every guide follows the README's layout: banner at the top (`assets/banner-*.svg`), an icon in front of every `##`
  heading (`<img src="assets/icons/<name>.svg" height="33" align="absmiddle" alt="">`), and the shared footer with the
  small banner, the navigation line to all guides and the licence line.
- Section icons: 60×56 canvas, 45 px rounded tile with a two-stop gradient, white 2 px stroke glyph in a 24 px grid.
  Within one guide every icon has its own colour and its own shape; check new icons rendered large and at 33 px in
  light and dark.
- When requirements, commands or rules change, update README, CONTRIBUTING, CODE_STYLE and ARCHITECTURE in the same
  commit.
