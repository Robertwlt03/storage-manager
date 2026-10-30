<p align="center">
  <img src="assets/banner-code-rules.svg" alt="Code rules of Speicher-Explorer. How we write code anyone can read." width="100%">
</p>

<p align="center"><a href="CODE_STYLE.md">Deutsch</a> · <a href="CODE_STYLE.en.md">English</a></p>

Code is read far more often than it is written. That is why the code of Speicher-Explorer should read almost like
prose, even for people who do not know every corner of Swift. These rules apply to every line, and the check script
at the end of this page checks most of them automatically.

## <img src="assets/icons/format.svg" height="33" align="absmiddle" alt="">Short lines and a uniform layout

No line is longer than 100 characters, and indentation is four spaces. The layout is not something everyone decides
for themselves; the tool `swift format` sets it, with the settings file `.swift-format`. It wraps long calls and puts
every step of a long chain on its own line. How many lines that produces does not matter, because a short line is
quicker to read than a long one.

```bash
make format
```

## <img src="assets/icons/names.svg" height="33" align="absmiddle" alt="">Names in everyday language

Names are in English and spelled out. We choose words people know from everyday life and no abbreviations, because
everyone understands `category`, whereas `cat` sounds like the animal. A name says what something is or does:

- **Values** are named after what they hold, for example `largeFiles` instead of `list` or `result`.
- **Functions** start with a verb, for example `scan()`, `openSettings()` or `refreshStatistics()`.
- **Booleans** read like a question, for example `isEmpty`, `hasFullDiskAccess` or `canSelect`.
- **Closure parameters** get a name too. We write `{ file in file.bytes }` and not `{ $0.bytes }`, so nobody has to
  guess what `$0` is.

There are no names of one or two letters. The only ones allowed are `id`, and `x` and `y` for coordinates, because
everyone knows these words.

## <img src="assets/icons/numbers.svg" height="33" align="absmiddle" alt="">No numbers without names

A number in the middle of the code does not tell you what it means. That is why every number gets a name, and the
code then reads like a sentence: `.padding(Space.card)` instead of `.padding(16)`. Only `0` and `1` may stand without
a name when they simply count, that is for “nothing” or “one more”. If they mean something specific, such as full
opacity or a finished scan, they get a name too.

Every name has a fixed home:

| What for | Where |
| --- | --- |
| Spacing, icon sizes, measurements and symbol names | `Sources/DesignSystem/Tokens.swift` |
| Colors | `Sources/DesignSystem/Theme.swift` |
| Duration and kind of animations | `Sources/DesignSystem/Motion.swift` |
| Limits of the scan, the cleanup and the search | `Sources/Core/Constants.swift` |
| Values that only a single type needs | as `private static let` directly in that type |

## <img src="assets/icons/palette.svg" height="33" align="absmiddle" alt="">Colors in one place

Every color of the app comes from `Theme.swift`. There it is defined once for the light and once for the dark
appearance, and reaches a contrast of at least 4.5 to 1 in both. All other files only use these names and never
create a color themselves, not even `.white` or `Color(red:green:blue:)`. If you need a new color, add it to
`Theme.swift` and to the list of contrast tests in `DesignTests.swift`.

## <img src="assets/icons/design.svg" height="33" align="absmiddle" alt="">A consistent design

So that the same things look the same everywhere, every design decision has exactly one home, and the pages only
use its names:

- **Fonts** come via `.textRole(...)` from `TextRole`, for example `.textRole(.hint)`, and never directly via
  `.font(...)`.
- **Symbols** are listed by name in `Symbols` in `Tokens.swift`, for example `Symbols.trash`, and never appear as a
  string on a page.
- **Liquid Glass** only comes via `.surface()` for cards and `.appButton(...)` for buttons. No page creates its own
  glass, materials or backgrounds under cards.
- **Animations** come from `Motion`, for example `Motion.standard`, so that “Reduce motion” takes effect everywhere.
- **Output** with `print` only exists in `Sources/Diagnostics`, because any other output could show private file or
  folder names.

## <img src="assets/icons/translations.svg" height="33" align="absmiddle" alt="">Texts only through translations

The code contains no text that you read in the app. Every visible text has an English key in `TextKey.swift`, for
example `TextKey.categories.translated`, and the texts themselves live in the 20 files under `Resources`. That is
why German words appear nowhere in the code. Output for developers, for example from the self test, is in English.

## <img src="assets/icons/steps.svg" height="33" align="absmiddle" alt="">Small, clearly separated steps

A function that drives a sequence reads like a list. Every step is a function of its own with a meaningful name, and
the driving function only decides which step may run when:

```swift
func run() async {
    await scanEveryArea()
    await visitEveryPage()
    guard hasFullDiskAccess else { return }
    await cleanUpWithoutDeleting()
}
```

We split long chains of many calls in a row into named intermediate steps. A function stays under 40 lines and under
ten branches; above that, SwiftLint speaks up. In SwiftUI we group modifiers that belong together into a property or
modifier of their own, so that a view does not turn into a long staircase.

## <img src="assets/icons/deadcode.svg" height="33" align="absmiddle" alt="">No dead code

Whatever is not used gets deleted, not commented out. Dead code makes the app bigger and is misleading, because
people take it for something important. If you need it again later, you will find it in the Git history. The same
goes for texts: a key the app shows nowhere disappears along with its translations.

## <img src="assets/icons/comments.svg" height="33" align="absmiddle" alt="">Comments only for what you cannot see

A good name replaces a comment. Comments are kept for rules you cannot see in the code, such as why a chart draws
without animation. The story of how a bug came about belongs in the commit message or in the
[architecture description](ARCHITECTURE.en.md).

## <img src="assets/icons/tests.svg" height="33" align="absmiddle" alt="">Tests

The tests live in `Tests/SpeicherExplorerTests` and use Apple’s test framework Swift Testing. Every test has a name
that says, as a full sentence, what should hold, for example “Only emptying the Trash needs a deliberate click in
the cleaner”. We test everything that has a fixed answer without a screen: the folder tree, the search, the page
list, the categories, the size classes, the legend, the summary, the design values, the contrast and the
translations.

Tests never touch the real disk and use no real file or folder names. That is why a test builds a folder tree by
hand, with made-up names such as `film.mov`. In tests, example values may stand as plain numbers, because there they
are the explanation themselves. If you change or add a rule in the code, write or update the matching test along
with it.

## <img src="assets/icons/checks.svg" height="33" align="absmiddle" alt="">How to check your code

Before every contribution you run the check chain. It must not report a single error or a single warning. Behind it
is the script `scripts/check.py`. You run individual steps by their names, for example
`scripts/check.py tests rules`.

```bash
make check
```

The output is laid out to be read at a glance. Every step gets one line with a green check mark ✔ or a red cross
✘, its number of findings and how long it took. Below a step with findings, they follow sorted by file, each with
its line number and what is wrong. At the end a frame sums up: green when every step passed, otherwise red with the
steps and their findings. Colors appear in the terminal and on GitHub, where every finding also stands right beside
its line in the pull request. `NO_COLOR=1` turns the colors off.

The script runs twenty-three checks one after another:

1. **Layout:** `swift format lint --strict` reports every deviation from the uniform layout.
2. **Length and nesting:** SwiftLint reports functions over 40 lines, closures over 30 lines, too many branches in one
   function and types nested too deeply. The limits are in `.swiftlint.yml`.
3. **Compiler:** The app is built with `-warnings-as-errors`, so even a single warning counts as an error.
4. **Tests:** `swift test` runs all tests from `Tests/SpeicherExplorerTests`, also without a single warning.
5. **Test coverage:** In every folder with logic, the tests must reach a minimum share of the lines. The values sit
   just below today's in `MINIMUM_COVERAGE` (`scripts/checks/tools.py`), so coverage can only grow; the folders with
   views are left out for a reason. A new folder without a rule is reported.
6. **House rules:** Numbers without names, colors outside `Theme.swift`, German text in the code, `$0`, names of one
   or two letters, lines over 100 characters and forgotten temporary debug lines. This also applies to the Swift
   scripts in the `scripts` folder.
7. **Design:** Fonts without a text role, symbol names outside `Symbols`, custom glass or custom backgrounds,
   animations outside `Motion`, hard-coded texts on screen and output outside the diagnostics. Hard-coded texts are
   found through the compiler's index: every SwiftUI call whose first argument is a text in quotes, including
   elements that do not exist yet.
8. **Accessibility:** Every image decides what VoiceOver does with it: it carries meaning and gets a name with
   `.accessibilityLabel`, or it decorates a text beside it and stays silent with `.accessibilityHidden(true)`
   (`scripts/checks/accessibility.py`).
9. **Flat methods:** At most two blocks may sit inside each other in a method, such as a loop and an `if` in it.
   A block is anything that spans lines: `if`, `else`, `switch`, loops, closures and inner functions. A deeper part
   belongs in a method of its own with a telling name, and there is no function inside a function inside a
   function. This applies to Swift, Python and shell (`scripts/checks/nesting.py`). The check tells a method by
   its place, not by a keyword: everything opened directly inside a type counts as a method, even a kind of
   declaration Swift adds later. In Python every statement with a block of its own counts.
10. **No code written twice:** When the same six lines of substance stand in two places, they belong in one shared
   method. Numbers and texts count as equal, so a copy with a changed value is caught too; blank lines, comments and
   lone brackets do not count (`scripts/checks/duplicates.py`).
11. **Architecture:** Every folder below `Sources` is a part of the app and may use only the parts the table in
   `scripts/checks/architecture.py` allows; the design system, for one, uses no pages and no app state. A new folder
   first needs a place there, otherwise the check reports it.
12. **Promises of the app:** Network interfaces do not appear in the code, because the app stays on the Mac. Only the
   three services that ask first delete files or move them to the Trash (`scripts/checks/promises.py`).
13. **The disk off the main thread:** Every access to the disk stands in code marked `nonisolated` or running in a
   `Task.detached`, because the main thread draws the window. Only the diagnostic tools are left out
   (`scripts/checks/disk_access.py`).
14. **Dead code:** every function, type, value and text that the app's own code uses nowhere, and every property that
   is only written but never read. The check reads the index the compiler writes while building
   (`scripts/checks/index_store.py`). That way it never mixes up properties of the same name, and what only the
   tests use counts as dead as well. For every kind of symbol it is settled whether it is judged or why not. When a
   kind shows up that nobody has decided on yet, the check reports it instead of skipping it.
15. **No unused files:** Every image and every other media file must be named in another file, otherwise it is dead
   weight (`scripts/checks/unused_files.py`).
16. **Language:** Every name we declare is split into its words (`fileCount`: file, count). Each word must be
   American English or a known technical term and never an abbreviation, so `temporary` instead of `temp` and
   `maximum` instead of `max`. Comments are read the same way. The macOS spell checker checks the words
   (`scripts/checks/language.py`). Technical terms such as `plist` or `codesign` are in no list: known is what appears
   in the names of the Apple and Python interfaces the code uses, what is installed as a command on the Mac, the
   project's file endings and the app's name. Only the forbidden abbreviations remain a list, because no source
   reliably tells whether a word is an abbreviation.
17. **Translation files:** `plutil -lint` checks that all 20 translations and the `Info.plist` can be read.
18. **Complete translations:** A text that reads exactly like the English one in some language is reported when the
   macOS spell checker does not know one of its words in that language. Terms that read the same in most languages,
   such as "iCloud Drive", are left out (`scripts/checks/translations.py`).
19. **Guides:** Every German guide and its English twin have the same layout: the same sections with the same icons,
   images, code blocks and table rows. Every link leads to a file that exists, and the English texts use American
   spelling (`scripts/checks/guides.py`).
20. **Secrets:** No file git knows holds a private key, an access token or a password written out. Every settings
   file the `Makefile` reads, such as `local.mk`, must be ignored by git (`scripts/checks/secrets.py`).
21. **Scripts:** The scripts and the `Makefile` also stay under 100 characters per line, and each one opens with the
   shared head. `bash -n`, `python3 -m py_compile`, `swiftc -typecheck` and `make -n` check them for typos.
22. **Commit messages:** Every commit has a subject like `fix(scan): what changed`: a kind from Conventional Commits,
   maybe a part in brackets, then the change. A blank line, lines up to 100 characters and American English follow.
   The rule holds from the commit that brought it in; the commits not yet on GitHub's `main` are checked
   (`scripts/checks/commits.py`).
23. **Samples:** The folder `scripts/checks/samples` holds a small package of its own with bad examples, which
   never belongs to the app. Every bad line carries a note `expect:` with the finding the check must report there.
   When a check no longer finds its mistake, or reports something nobody planted, this step fails. Whoever adds a
   rule plants its mistake there, with a note.

Every script is built the same way, so once you understand one, you understand them all. At the top, a head says in
one sentence what the script does, with the lines `Start:` (how to start it) and `Needs:` (what it needs). The
settings follow under `MARK: Settings`: every number and every pattern has a name and an explanation there. Then come
the steps as small, named functions, and at the very bottom, under `MARK: Run`, the run as a list of these steps.
Search patterns are written over several lines with a comment per part, and names are spelled out, so `BUILD_FOLDER`
instead of `BUILD_DIR`. The check pipeline itself is split up in `scripts/checks/`, one module per topic.

Whether every text exists in all 20 languages and whether every color reaches the contrast is checked by the tests
in the fourth step. How much of the code the tests reach is shown per folder by `make coverage`.

On GitHub the same check runs by itself on every pull request, as described in
`.github/workflows/checks.yml`. If it reports even a single finding, the pull request turns red, and the
contribution has to be improved before it is merged. Whether names are understandable and whether a step is cut
well, no script can judge, and only the eye can see what the glass looks like: for that, open the changed pages with
`make demo`. We pay attention to these things when we read a contribution.

<p align="center">
  <img src="assets/banner-footer-en.svg" alt="" width="480">
</p>

<p align="center">
  <b>Speicher-Explorer · See at a glance where your storage goes.</b><br>
  <sub><a href="README.en.md">Overview</a> · <a href="CONTRIBUTING.en.md">Contributing</a> · <a href="ARCHITECTURE.en.md">Architecture</a> · <a href="CODE_STYLE.en.md">Code rules</a> · <a href="CODE_OF_CONDUCT.en.md">Code of conduct</a></sub><br>
  <sub>© 2026 Robertwlt03 · Released under the <a href="LICENSE">MIT license</a> · For macOS 27 on Macs with Apple silicon</sub>
</p>
